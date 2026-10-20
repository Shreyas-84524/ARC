import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// Biometrics operate solely through device OS secure enclaves.
// No biometric templates, signatures, or biometric identifiers are stored in ARC.

class SecretNotesBiometricService {
  final LocalAuthentication _auth;
  bool _isAuthenticating = false;

  SecretNotesBiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  /// Whether a biometric authentication prompt is currently in progress.
  bool get isAuthenticating => _isAuthenticating;

  /// Checks that biometric hardware is supported and at least one biometric
  /// is enrolled and available to this app.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) {
        return false;
      }

      final availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint(
        'Secret Notes: biometric availability check failed gracefully: $e',
      );
      return false;
    }
  }

  /// Prompts the user for biometric authentication with an explicit prompt reason.
  /// Falls back gracefully returning false if cancelled or unsupported.
  /// Guarded against concurrent or duplicate simultaneous prompts.
  Future<bool> authenticate({
    String reason = 'Authenticate to access Secret Notes',
  }) async {
    if (_isAuthenticating) {
      debugPrint(
        'Secret Notes: biometric authentication already in progress, ignoring duplicate request.',
      );
      return false;
    }

    _isAuthenticating = true;
    try {
      final available = await isBiometricAvailable();
      if (!available) {
        debugPrint(
          'Secret Notes: biometric authentication requested but unavailable.',
        );
        return false;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      return authenticated;
    } catch (e) {
      debugPrint(
        'Secret Notes: biometric prompt encountered error or user cancelled: $e',
      );
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }
}
