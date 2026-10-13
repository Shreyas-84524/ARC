import 'package:flutter/foundation.dart';
import 'package:arc/features/secret_notes/models/secret_notes_security_state.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_local_repository.dart';
import 'package:arc/features/secret_notes/services/secret_notes_crypto.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// - NO Firestore collections for notes
// - NO sync queues
// - NO realtime listeners
// - NO Firebase repositories
// - NO uploading PINs or metadata
// - NO attachment to ARC cloud sync
// All storage and security verifiers remain strictly local on the device.

class SecretNotesSecurityService {
  final SecretNotesLocalRepository _repository;

  static const int requiredPinLength = 6;
  static const int maxFailedAttemptsBeforeLockout = 5;

  SecretNotesSecurityService({SecretNotesLocalRepository? repository})
      : _repository = repository ?? SecretNotesLocalRepository();

  /// Validates a raw PIN for format and length requirements without storing or logging it.
  static String? validatePin(String? pin) {
    if (pin == null || pin.isEmpty) {
      return 'PIN cannot be empty';
    }
    if (pin.length != requiredPinLength) {
      return 'PIN must be exactly $requiredPinLength digits';
    }
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      return 'PIN must contain only numbers';
    }
    return null;
  }

  /// Validates that both PIN and confirm PIN match and meet requirements.
  static String? validatePinConfirmation(String? pin, String? confirmPin) {
    final pinError = validatePin(pin);
    if (pinError != null) return pinError;

    if (confirmPin == null || confirmPin.isEmpty) {
      return 'Please confirm your PIN';
    }
    if (pin != confirmPin) {
      return 'PINs do not match';
    }
    return null;
  }

  /// Synchronous check if Secret Notes is configured (from open memory/storage).
  bool isConfiguredSync() => _repository.isConfiguredSync();

  /// Checks if Secret Notes has been configured on this device.
  Future<bool> isSecretNotesConfigured() async {
    await _repository.init();
    final state = await _repository.loadSecurityState();
    return state.isConfigured && state.salt != null && state.pinHash != null;
  }

  /// Returns remaining seconds if the device is currently locked out from entering PIN.
  Future<int> getLockoutRemainingSeconds() async {
    await _repository.init();
    final state = await _repository.loadSecurityState();
    return state.lockoutRemainingSeconds;
  }

  /// Sets up a new 6-digit Secret PIN. Derives a salted PBKDF2 verifier and saves it locally.
  /// Never stores or logs the raw PIN.
  Future<bool> setupPin(String pin) async {
    final validationError = validatePin(pin);
    if (validationError != null) {
      debugPrint('Secret Notes: PIN setup rejected due to validation failure.');
      return false;
    }

    await _repository.init();

    // Generate random 32-byte cryptographic salt
    final saltBytes = SecretNotesCrypto.generateSalt(SecretNotesCrypto.saltByteLength);
    final saltHex = SecretNotesCrypto.bytesToHex(saltBytes);

    // Derive PBKDF2 HMAC-SHA256 verifier with 10,000 iterations
    final derivedKey = SecretNotesCrypto.pbkdf2HmacSha256(
      pin: pin,
      salt: saltBytes,
      iterations: SecretNotesCrypto.defaultIterations,
      keyLength: SecretNotesCrypto.derivedKeyLength,
    );
    final hashHex = SecretNotesCrypto.bytesToHex(derivedKey);

    final newState = SecretNotesSecurityState(
      isConfigured: true,
      hasSeenIntro: false,
      failedAttempts: 0,
      lockedUntil: null,
      salt: saltHex,
      pinHash: hashHex,
      iterations: SecretNotesCrypto.defaultIterations,
    );

    await _repository.saveSecurityState(newState);
    debugPrint('Secret Notes: PIN setup completed successfully.');
    return true;
  }

  /// Verifies a candidate PIN against the stored verifier.
  /// Handles lockout and failed attempt escalation.
  Future<bool> verifyPin(String pin) async {
    await _repository.init();
    final state = await _repository.loadSecurityState();

    if (!state.isConfigured || state.salt == null || state.pinHash == null) {
      debugPrint('Secret Notes: unlock attempt on unconfigured instance.');
      return false;
    }

    // Check if lockout is active
    if (state.isLockedOut) {
      debugPrint('Secret Notes: unlock rejected - lockout currently active.');
      return false;
    }

    try {
      final saltBytes = SecretNotesCrypto.hexToBytes(state.salt!);
      final storedHashBytes = SecretNotesCrypto.hexToBytes(state.pinHash!);

      final candidateHashBytes = SecretNotesCrypto.pbkdf2HmacSha256(
        pin: pin,
        salt: saltBytes,
        iterations: state.iterations,
        keyLength: SecretNotesCrypto.derivedKeyLength,
      );

      final isMatch = SecretNotesCrypto.constantTimeEquals(candidateHashBytes, storedHashBytes);

      if (isMatch) {
        // Successful verification: reset failed attempts and lockout
        // Automatic backward-compatible migration:
        // If the stored verifier was derived with legacy iterations (< defaultIterations),
        // transparently upgrade it with a fresh cryptographic salt and defaultIterations (100,000+).
        if (state.iterations < SecretNotesCrypto.defaultIterations) {
          final newSaltBytes = SecretNotesCrypto.generateSalt(SecretNotesCrypto.saltByteLength);
          final newSaltHex = SecretNotesCrypto.bytesToHex(newSaltBytes);
          final upgradedDerivedKey = SecretNotesCrypto.pbkdf2HmacSha256(
            pin: pin,
            salt: newSaltBytes,
            iterations: SecretNotesCrypto.defaultIterations,
            keyLength: SecretNotesCrypto.derivedKeyLength,
          );
          final upgradedHashHex = SecretNotesCrypto.bytesToHex(upgradedDerivedKey);

          final upgradedState = state.copyWith(
            salt: newSaltHex,
            pinHash: upgradedHashHex,
            iterations: SecretNotesCrypto.defaultIterations,
            failedAttempts: 0,
            clearLockedUntil: true,
          );
          await _repository.saveSecurityState(upgradedState);
          debugPrint('Secret Notes: transparently migrated legacy PIN verifier to 100,000 iterations.');
        } else {
          final updatedState = state.copyWith(
            failedAttempts: 0,
            clearLockedUntil: true,
          );
          await _repository.saveSecurityState(updatedState);
        }
        debugPrint('Secret Notes: unlock successful.');
        return true;
      } else {
        // Failed attempt: record and check for lockout
        final newFailedAttempts = state.failedAttempts + 1;
        DateTime? newLockedUntil;

        if (newFailedAttempts >= maxFailedAttemptsBeforeLockout) {
          final lockoutSeconds = _calculateLockoutDuration(newFailedAttempts);
          newLockedUntil = DateTime.now().add(Duration(seconds: lockoutSeconds));
          debugPrint('Secret Notes: threshold reached, entry locked for $lockoutSeconds seconds.');
        } else {
          debugPrint('Secret Notes: unlock failed. Attempt $newFailedAttempts of $maxFailedAttemptsBeforeLockout.');
        }

        final updatedState = state.copyWith(
          failedAttempts: newFailedAttempts,
          lockedUntil: newLockedUntil,
        );
        await _repository.saveSecurityState(updatedState);
        return false;
      }
    } catch (e) {
      debugPrint('Secret Notes: error during verification: $e');
      return false;
    }
  }

  int _calculateLockoutDuration(int failedAttempts) {
    if (failedAttempts <= 5) return 30;
    if (failedAttempts == 6) return 60;
    return 120;
  }

  /// Changes the Secret PIN after verifying the current PIN.
  /// Rejects identical PINs, validates 6-digit numeric format,
  /// generates fresh salt and PBKDF2 verifier, and resets failed attempts/lockout.
  Future<String?> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    // 1. Validate format of new PIN
    final validationError = validatePin(newPin);
    if (validationError != null) {
      return validationError;
    }

    // 2. Reject identical PIN
    if (currentPin == newPin) {
      return 'Your new PIN must be different from your current PIN.';
    }

    await _repository.init();
    final state = await _repository.loadSecurityState();

    if (!state.isConfigured || state.salt == null || state.pinHash == null) {
      return 'Secret Notes is not configured.';
    }

    if (state.isLockedOut) {
      return 'Too many failed attempts. Please wait for lockout to expire.';
    }

    // 3. Verify current PIN
    final saltBytes = SecretNotesCrypto.hexToBytes(state.salt!);
    final storedHashBytes = SecretNotesCrypto.hexToBytes(state.pinHash!);

    final candidateHashBytes = SecretNotesCrypto.pbkdf2HmacSha256(
      pin: currentPin,
      salt: saltBytes,
      iterations: state.iterations,
      keyLength: SecretNotesCrypto.derivedKeyLength,
    );

    final isMatch = SecretNotesCrypto.constantTimeEquals(candidateHashBytes, storedHashBytes);
    if (!isMatch) {
      // Record failed attempt
      final newFailedAttempts = state.failedAttempts + 1;
      DateTime? newLockedUntil;
      if (newFailedAttempts >= maxFailedAttemptsBeforeLockout) {
        final lockoutSeconds = _calculateLockoutDuration(newFailedAttempts);
        newLockedUntil = DateTime.now().add(Duration(seconds: lockoutSeconds));
      }
      await _repository.saveSecurityState(state.copyWith(
        failedAttempts: newFailedAttempts,
        lockedUntil: newLockedUntil,
      ));
      return 'Current PIN is incorrect.';
    }

    // 4. Generate new salt and compute fresh PBKDF2 HMAC-SHA256 verifier
    final newSaltBytes = SecretNotesCrypto.generateSalt(SecretNotesCrypto.saltByteLength);
    final newSaltHex = SecretNotesCrypto.bytesToHex(newSaltBytes);

    final newDerivedKey = SecretNotesCrypto.pbkdf2HmacSha256(
      pin: newPin,
      salt: newSaltBytes,
      iterations: SecretNotesCrypto.defaultIterations,
      keyLength: SecretNotesCrypto.derivedKeyLength,
    );
    final newHashHex = SecretNotesCrypto.bytesToHex(newDerivedKey);

    final updatedState = state.copyWith(
      salt: newSaltHex,
      pinHash: newHashHex,
      iterations: SecretNotesCrypto.defaultIterations,
      failedAttempts: 0,
      clearLockedUntil: true,
    );

    await _repository.saveSecurityState(updatedState);
    debugPrint('Secret Notes: PIN successfully changed with fresh salt.');
    return null; // Success (no error)
  }

  /// Checks if biometric unlock is enabled in local preferences.
  Future<bool> isBiometricEnabled() async {
    await _repository.init();
    return _repository.isBiometricEnabled();
  }

  /// Updates the biometric unlock preference locally.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _repository.init();
    await _repository.setBiometricEnabled(enabled);
    debugPrint('Secret Notes: biometric enabled set to $enabled.');
  }

  /// Checks if the first-use information popup has already been seen.
  Future<bool> hasSeenIntro() async {
    await _repository.init();
    return _repository.hasSeenIntro();
  }

  /// Marks the first-use information popup as acknowledged.
  Future<void> markIntroSeen() async {
    await _repository.init();
    await _repository.setIntroSeen(true);
    debugPrint('Secret Notes: intro popup acknowledged and persisted.');
  }

  /// Helper for testing or administrative reset.
  Future<void> resetAll() async {
    await _repository.init();
    await _repository.clearAll();
  }
}
