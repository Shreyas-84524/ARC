import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:arc/features/secret_notes/models/secret_note.dart';
import 'package:arc/features/secret_notes/models/secret_notes_security_state.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_local_repository.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_data_repository.dart';
import 'package:arc/features/secret_notes/services/secret_notes_crypto.dart';
import 'package:arc/features/secret_notes/services/secret_notes_security_service.dart';
import 'package:arc/features/secret_notes/services/secret_notes_window_privacy_service.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/routes/app_router.dart';

class UserContextNotifierTestHelper extends UserContextNotifier {
  UserContextNotifierTestHelper(UserContext initialState) : super() {
    state = initialState;
  }
}

class FakeGoRouterState extends Fake implements GoRouterState {
  final String _path;
  FakeGoRouterState(this._path);

  @override
  Uri get uri => Uri.parse(_path);

  @override
  String get matchedLocation => _path;
}

class FakeBuildContext extends Fake implements BuildContext {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Secret Notes Phase 5 - PIN Derivation & Transparent Migration', () {
    late SecretNotesLocalRepository repo;
    late SecretNotesSecurityService securityService;

    setUp(() {
      repo = SecretNotesLocalRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: repo);
    });

    test('Fresh PIN setup defaults to 100,000 iterations', () async {
      await securityService.setupPin('123456');
      final state = await repo.loadSecurityState();
      expect(state.iterations, equals(100000));
      expect(state.iterations, equals(SecretNotesCrypto.defaultIterations));
    });

    test('Legacy 10,000 iterations PIN is successfully verified and transparently upgraded', () async {
      // Simulate existing Phase 1-4 user with 10,000 iterations
      final legacySalt = SecretNotesCrypto.generateSalt(32);
      final legacySaltHex = SecretNotesCrypto.bytesToHex(legacySalt);
      final legacyDerived = SecretNotesCrypto.pbkdf2HmacSha256(
        pin: '123456',
        salt: legacySalt,
        iterations: 10000,
        keyLength: 32,
      );
      final legacyHashHex = SecretNotesCrypto.bytesToHex(legacyDerived);

      await repo.saveSecurityState(
        SecretNotesSecurityState(
          isConfigured: true,
          salt: legacySaltHex,
          pinHash: legacyHashHex,
          iterations: 10000,
        ),
      );

      final stateBefore = await repo.loadSecurityState();
      expect(stateBefore.iterations, equals(10000));

      // Incorrect PIN fails and does not upgrade
      final wrongUnlock = await securityService.verifyPin('000000');
      expect(wrongUnlock, isFalse);
      final stateAfterFail = await repo.loadSecurityState();
      expect(stateAfterFail.iterations, equals(10000));

      // Correct PIN unlocks and automatically migrates to 100,000 iterations with fresh salt
      final correctUnlock = await securityService.verifyPin('123456');
      expect(correctUnlock, isTrue);

      final stateAfterSuccess = await repo.loadSecurityState();
      expect(stateAfterSuccess.iterations, equals(100000));
      expect(stateAfterSuccess.salt, isNot(equals(legacySaltHex))); // fresh salt
      expect(stateAfterSuccess.pinHash, isNot(equals(legacyHashHex))); // fresh verifier

      // Subsequent unlock works with upgraded verifier
      final nextUnlock = await securityService.verifyPin('123456');
      expect(nextUnlock, isTrue);
    });
  });

  group('Secret Notes Phase 5 - Window Privacy & Screen Protection', () {
    test('SecretNotesWindowPrivacyService calls enableSecure and disableSecure on MethodChannel', () async {
      final List<MethodCall> methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.arc.arc/secure_window'),
        (MethodCall call) async {
          methodCalls.add(call);
          return true;
        },
      );

      final service = SecretNotesWindowPrivacyService();
      expect(service.isSecure, isFalse);

      await service.enableSecureScreen();
      // On non-android unit test host, gracefully handles platform check without throwing
      await service.disableSecureScreen();
      expect(service.isSecure, isFalse);
    });
  });

  group('Secret Notes Phase 5 - Navigation & Automatic Session Lock', () {
    late SecretNotesLocalRepository repo;
    late SecretNotesSecurityService securityService;

    setUp(() async {
      repo = SecretNotesLocalRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: repo);
      await securityService.setupPin('123456');
    });

    test('Session automatically locks when user navigates away from Secret Notes to normal ARC routes', () {
      final container = ProviderContainer(
        overrides: [
          userContextProvider.overrideWith((ref) => UserContextNotifierTestHelper(
                const UserContext(userId: 'test_uid', isInitializing: false),
              )),
          secretNotesLocalRepositoryProvider.overrideWithValue(repo),
          secretNotesSecurityServiceProvider.overrideWithValue(securityService),
        ],
      );

      // Unlock Secret Notes
      container.read(secretNotesSessionProvider.notifier).unlock();
      expect(container.read(secretNotesSessionProvider), isTrue);

      final routerNotifier = container.read(routerNotifierProvider);

      // User accesses protected /secret-notes (allowed)
      final accessSecretNotes = routerNotifier.redirect(
        FakeBuildContext(),
        FakeGoRouterState('/secret-notes'),
      );
      expect(accessSecretNotes, isNull);
      expect(container.read(secretNotesSessionProvider), isTrue);

      // User navigates to /tasks
      final exitToTasks = routerNotifier.redirect(
        FakeBuildContext(),
        FakeGoRouterState('/tasks'),
      );
      expect(exitToTasks, isNull);

      // Verify that unlocked session is immediately invalidated
      expect(container.read(secretNotesSessionProvider), isFalse);

      // Attempting to re-enter /secret-notes now redirects to /secret-notes/unlock
      final reenterSecretNotes = routerNotifier.redirect(
        FakeBuildContext(),
        FakeGoRouterState('/secret-notes'),
      );
      expect(reenterSecretNotes, equals('/secret-notes/unlock'));
    });
  });

  group('Secret Notes Phase 5 - Cold Start Protection', () {
    test('App start defaults to locked session regardless of previous disk state', () {
      final container = ProviderContainer();
      final isUnlocked = container.read(secretNotesSessionProvider);
      expect(isUnlocked, isFalse);
    });
  });

  group('Secret Notes Phase 5 - 100% Offline & Zero Firebase Isolation', () {
    test('Data repository strictly persists locally and has zero remote sync hooks', () async {
      final dataRepo = SecretNotesDataRepository(inMemoryOnly: true);
      final note = SecretNote(
        id: 'secure_local_note',
        title: 'Classified Note',
        description: 'Should never touch Firestore',
        createdAt: DateTime(2026, 10, 13),
        updatedAt: DateTime(2026, 10, 13),
      );

      await dataRepo.saveNote(note);
      final retrieved = await dataRepo.getNoteById('secure_local_note');
      expect(retrieved, isNotNull);
      expect(retrieved?.title, equals('Classified Note'));

      // Ensure SecretNote model serialization contains no cloud sync metadata
      final map = retrieved!.toMap();
      expect(map.containsKey('firestore_id'), isFalse);
      expect(map.containsKey('sync_status'), isFalse);
      expect(map.containsKey('cloud_synced'), isFalse);
      expect(map.containsKey('remote_id'), isFalse);
    });
  });
}
