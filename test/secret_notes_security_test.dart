import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/secret_notes/models/secret_notes_security_state.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_local_repository.dart';
import 'package:arc/features/secret_notes/services/secret_notes_crypto.dart';
import 'package:arc/features/secret_notes/services/secret_notes_security_service.dart';

void main() {
  group('Secret Notes - Cryptography and Hashing', () {
    test('generateSalt produces non-empty random bytes of requested length', () {
      final salt1 = SecretNotesCrypto.generateSalt(32);
      final salt2 = SecretNotesCrypto.generateSalt(32);

      expect(salt1.length, equals(32));
      expect(salt2.length, equals(32));
      expect(salt1, isNot(equals(salt2))); // Random salts should differ
    });

    test('pbkdf2HmacSha256 produces deterministic 32-byte key for same PIN and salt', () {
      final salt = SecretNotesCrypto.generateSalt(32);
      final key1 = SecretNotesCrypto.pbkdf2HmacSha256(
        pin: '123456',
        salt: salt,
        iterations: 1000,
        keyLength: 32,
      );
      final key2 = SecretNotesCrypto.pbkdf2HmacSha256(
        pin: '123456',
        salt: salt,
        iterations: 1000,
        keyLength: 32,
      );

      expect(key1.length, equals(32));
      expect(key1, equals(key2));
    });

    test('pbkdf2HmacSha256 produces different keys for different PINs', () {
      final salt = SecretNotesCrypto.generateSalt(32);
      final key1 = SecretNotesCrypto.pbkdf2HmacSha256(
        pin: '123456',
        salt: salt,
        iterations: 1000,
      );
      final key2 = SecretNotesCrypto.pbkdf2HmacSha256(
        pin: '654321',
        salt: salt,
        iterations: 1000,
      );

      expect(key1, isNot(equals(key2)));
    });

    test('constantTimeEquals accurately detects equality and prevents length mismatches', () {
      final a = Uint8List.fromList([1, 2, 3, 4]);
      final b = Uint8List.fromList([1, 2, 3, 4]);
      final c = Uint8List.fromList([1, 2, 3, 5]);
      final d = Uint8List.fromList([1, 2, 3]);

      expect(SecretNotesCrypto.constantTimeEquals(a, b), isTrue);
      expect(SecretNotesCrypto.constantTimeEquals(a, c), isFalse);
      expect(SecretNotesCrypto.constantTimeEquals(a, d), isFalse);
    });

    test('bytesToHex and hexToBytes correctly roundtrip', () {
      final bytes = Uint8List.fromList([0, 15, 16, 255]);
      final hex = SecretNotesCrypto.bytesToHex(bytes);
      expect(hex, equals('000f10ff'));
      final decoded = SecretNotesCrypto.hexToBytes(hex);
      expect(decoded, equals(bytes));
    });
  });

  group('Secret Notes - Security Service & Validation', () {
    late SecretNotesLocalRepository repo;
    late SecretNotesSecurityService service;

    setUp(() async {
      repo = SecretNotesLocalRepository(inMemoryOnly: true);
      await repo.init();
      await repo.clearAll();
      service = SecretNotesSecurityService(repository: repo);
    });

    test('validatePin enforces 6 digits numeric format', () {
      expect(SecretNotesSecurityService.validatePin(null), equals('PIN cannot be empty'));
      expect(SecretNotesSecurityService.validatePin(''), equals('PIN cannot be empty'));
      expect(SecretNotesSecurityService.validatePin('123'), equals('PIN must be exactly 6 digits'));
      expect(SecretNotesSecurityService.validatePin('1234567'), equals('PIN must be exactly 6 digits'));
      expect(SecretNotesSecurityService.validatePin('abcdef'), equals('PIN must contain only numbers'));
      expect(SecretNotesSecurityService.validatePin('123a56'), equals('PIN must contain only numbers'));
      expect(SecretNotesSecurityService.validatePin('123456'), isNull);
    });

    test('validatePinConfirmation enforces match and valid PIN', () {
      expect(
        SecretNotesSecurityService.validatePinConfirmation('123456', ''),
        equals('Please confirm your PIN'),
      );
      expect(
        SecretNotesSecurityService.validatePinConfirmation('123456', '654321'),
        equals('PINs do not match'),
      );
      expect(
        SecretNotesSecurityService.validatePinConfirmation('123456', '123456'),
        isNull,
      );
    });

    test('first-time state detected correctly as not configured', () async {
      final isConfigured = await service.isSecretNotesConfigured();
      expect(isConfigured, isFalse);
      expect(service.isConfiguredSync(), isFalse);
    });

    test('setupPin succeeds and derives hashed verifier without storing raw PIN', () async {
      const rawPin = '987654';
      final setupSuccess = await service.setupPin(rawPin);
      expect(setupSuccess, isTrue);

      final isConfigured = await service.isSecretNotesConfigured();
      expect(isConfigured, isTrue);
      expect(service.isConfiguredSync(), isTrue);

      // Verify that raw PIN is NOT stored anywhere in the security repository
      final state = await repo.loadSecurityState();
      final map = state.toMap();

      expect(map.values, isNot(contains(rawPin)));
      expect(state.salt, isNotNull);
      expect(state.pinHash, isNotNull);
      expect(state.pinHash, isNot(contains(rawPin)));
      expect(state.salt, isNot(contains(rawPin)));
      expect(state.isConfigured, isTrue);
    });

    test('mismatched or invalid length PIN rejected by setup', () async {
      expect(await service.setupPin('12345'), isFalse);
      expect(await service.setupPin(''), isFalse);
      expect(await service.setupPin('abcdef'), isFalse);
    });

    test('correct PIN unlocks successfully', () async {
      await service.setupPin('456789');
      final unlockSuccess = await service.verifyPin('456789');
      expect(unlockSuccess, isTrue);
    });

    test('incorrect PIN is rejected', () async {
      await service.setupPin('456789');
      final unlockSuccess = await service.verifyPin('111111');
      expect(unlockSuccess, isFalse);
    });

    test('brute-force protection: locks after 5 failed attempts for 30s', () async {
      await service.setupPin('123456');

      // 4 failed attempts: not yet locked
      for (int i = 0; i < 4; i++) {
        final res = await service.verifyPin('000000');
        expect(res, isFalse);
        expect(await service.getLockoutRemainingSeconds(), equals(0));
      }

      // 5th failed attempt: triggers lockout
      final fifthFail = await service.verifyPin('000000');
      expect(fifthFail, isFalse);

      final remaining = await service.getLockoutRemainingSeconds();
      expect(remaining, greaterThan(0));
      expect(remaining, lessThanOrEqualTo(30));

      // Attempt during lockout is immediately rejected even if PIN is correct
      final blocked = await service.verifyPin('123456');
      expect(blocked, isFalse);
    });

    test('reloading security state preserves lockout information', () async {
      await service.setupPin('123456');

      for (int i = 0; i < 5; i++) {
        await service.verifyPin('000000');
      }

      // Create new service instance with same repository simulating app restart
      final newService = SecretNotesSecurityService(repository: repo);
      final remaining = await newService.getLockoutRemainingSeconds();
      expect(remaining, greaterThan(0));
      expect(remaining, lessThanOrEqualTo(30));
    });

    test('intro seen flag persists and does not reset on unlock', () async {
      await service.setupPin('123456');

      expect(await service.hasSeenIntro(), isFalse);
      await service.markIntroSeen();
      expect(await service.hasSeenIntro(), isTrue);

      // Verify again on reloaded repository
      final newService = SecretNotesSecurityService(repository: repo);
      expect(await newService.hasSeenIntro(), isTrue);
    });
  });

  group('Secret Notes - Privacy & Local-Only Guarantees', () {
    test('Secret Notes state contains NO Firestore or sync queue references', () {
      final state = SecretNotesSecurityState(
        isConfigured: true,
        salt: 'abcdef',
        pinHash: '1234567890abcdef',
        hasSeenIntro: true,
      );

      final map = state.toMap();

      // Ensure no sync, cloud, or remote fields
      expect(map.containsKey('sync_status'), isFalse);
      expect(map.containsKey('firestore_id'), isFalse);
      expect(map.containsKey('cloud_synced'), isFalse);
      expect(map.containsKey('uid'), isFalse);
      expect(map.containsKey('userId'), isFalse);
    });
  });
}
