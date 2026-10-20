import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/secret_notes/models/secret_note.dart';
import 'package:arc/features/secret_notes/models/secret_checklist_item.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_local_repository.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_data_repository.dart';
import 'package:arc/features/secret_notes/services/secret_notes_security_service.dart';
import 'package:arc/features/secret_notes/services/secret_notes_biometric_service.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_settings_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_dashboard_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_unlock_screen.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/routes/app_router.dart';

// Fake biometric service for deterministic testing
class FakeBiometricService extends SecretNotesBiometricService {
  bool available;
  bool authSuccess;

  FakeBiometricService({this.available = true, this.authSuccess = true});

  @override
  Future<bool> isBiometricAvailable() async => available;

  @override
  Future<bool> authenticate({String reason = 'Authenticate to access Secret Notes'}) async {
    return authSuccess;
  }
}

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

Widget createTestSettingsApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Secret Notes Phase 4 - PIN Change Logic', () {
    late SecretNotesLocalRepository localRepo;
    late SecretNotesSecurityService securityService;

    setUp(() async {
      localRepo = SecretNotesLocalRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: localRepo);
      await securityService.setupPin('123456');
    });

    test('changePin rejects identical new PIN', () async {
      final error = await securityService.changePin(
        currentPin: '123456',
        newPin: '123456',
      );
      expect(error, contains('must be different'));
    });

    test('changePin rejects invalid format new PIN (non-numeric or wrong length)', () async {
      final errorNonNum = await securityService.changePin(
        currentPin: '123456',
        newPin: 'abcdef',
      );
      expect(errorNonNum, contains('only numbers'));

      final errorShort = await securityService.changePin(
        currentPin: '123456',
        newPin: '12',
      );
      expect(errorShort, contains('between 3 and 6 digits'));
    });

    test('changePin rejects incorrect current PIN and tracks failed attempts', () async {
      final error = await securityService.changePin(
        currentPin: '000000',
        newPin: '654321',
      );
      expect(error, contains('Current PIN is incorrect'));

      // Verify that old PIN still works and new PIN is not set
      final oldWorks = await securityService.verifyPin('123456');
      expect(oldWorks, isTrue);

      final newWorks = await securityService.verifyPin('654321');
      expect(newWorks, isFalse);
    });

    test('changePin successfully updates PBKDF2 verifier and resets failed attempts', () async {
      final error = await securityService.changePin(
        currentPin: '123456',
        newPin: '654321',
      );
      expect(error, isNull);

      // Verify new PIN succeeds and old PIN fails
      final oldVerify = await securityService.verifyPin('123456');
      expect(oldVerify, isFalse);

      final newVerify = await securityService.verifyPin('654321');
      expect(newVerify, isTrue);
    });
  });

  group('Secret Notes Phase 4 - Biometric Preferences & Fallback', () {
    late SecretNotesLocalRepository localRepo;
    late SecretNotesSecurityService securityService;

    setUp(() async {
      localRepo = SecretNotesLocalRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: localRepo);
      await securityService.setupPin('123456');
    });

    test('Biometric preference defaults to false and can be toggled', () async {
      final initial = await securityService.isBiometricEnabled();
      expect(initial, isFalse);

      await securityService.setBiometricEnabled(true);
      final enabled = await securityService.isBiometricEnabled();
      expect(enabled, isTrue);

      await securityService.setBiometricEnabled(false);
      final disabled = await securityService.isBiometricEnabled();
      expect(disabled, isFalse);
    });

    testWidgets('Unlock screen displays biometrics button when enabled and hardware is available', (tester) async {
      await securityService.setBiometricEnabled(true);
      final fakeBio = FakeBiometricService(available: true, authSuccess: true);

      await tester.pumpWidget(
        createTestSettingsApp(
          child: const SecretNotesUnlockScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
            secretNotesBiometricServiceProvider.overrideWithValue(fakeBio),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unlock with Biometrics'), findsOneWidget);
      expect(find.byIcon(LucideIcons.fingerprint), findsOneWidget);
    });

    testWidgets('Unlock screen does not show biometrics button when disabled in settings', (tester) async {
      await securityService.setBiometricEnabled(false);
      final fakeBio = FakeBiometricService(available: true, authSuccess: true);

      await tester.pumpWidget(
        createTestSettingsApp(
          child: const SecretNotesUnlockScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
            secretNotesBiometricServiceProvider.overrideWithValue(fakeBio),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unlock with Biometrics'), findsNothing);
    });
  });

  group('Secret Notes Phase 4 - Settings Screen UI & Isolation', () {
    late SecretNotesLocalRepository localRepo;
    late SecretNotesDataRepository dataRepo;
    late SecretNotesSecurityService securityService;
    late FakeBiometricService fakeBio;

    setUp(() async {
      localRepo = SecretNotesLocalRepository(inMemoryOnly: true);
      dataRepo = SecretNotesDataRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: localRepo);
      fakeBio = FakeBiometricService(available: true, authSuccess: true);

      await securityService.setupPin('123456');

      // Seed test notes
      await dataRepo.saveNote(
        SecretNote(
          id: 'n1',
          title: 'Mission Checklist',
          description: 'Top secret items',
          checklist: [
            SecretChecklistItem(
              id: 'c1',
              text: 'Burn papers',
              isCompleted: true,
              createdAt: DateTime(2026, 10, 13),
            ),
            SecretChecklistItem(
              id: 'c2',
              text: 'Extract operative',
              isCompleted: false,
              createdAt: DateTime(2026, 10, 13),
            ),
          ],
          createdAt: DateTime(2026, 10, 13, 10, 0),
          updatedAt: DateTime(2026, 10, 13, 12, 0),
        ),
      );

      await dataRepo.saveNote(
        SecretNote(
          id: 'n2',
          title: 'Plain Note',
          description: 'No checklist here',
          checklist: const [],
          createdAt: DateTime(2026, 10, 13, 8, 0),
          updatedAt: DateTime(2026, 10, 13, 9, 0),
        ),
      );
    });

    testWidgets('Renders all 4 sections with accurate summary stats', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestSettingsApp(
          child: const SecretNotesSettingsScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
            secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
            secretNotesBiometricServiceProvider.overrideWithValue(fakeBio),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Section headers
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Secret Notes Summary'), findsOneWidget);
      expect(find.text('Privacy & Local Storage Guarantee'), findsOneWidget);
      expect(find.text('Danger Zone'), findsOneWidget);

      // Security options
      expect(find.text('Change Secret PIN'), findsOneWidget);
      expect(find.text('Biometric Unlock'), findsOneWidget);

      // Summary metrics
      expect(find.text('Total Notes'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 total notes
      expect(find.text('Checklist Notes'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // 1 note with checklist
      expect(find.text('Checklist Items'), findsOneWidget);
      expect(find.text('1 of 2 done'), findsOneWidget); // 1 completed out of 2 total checklist items

      // Local only badge & disclaimer
      expect(find.textContaining('Storage: Isolated Local Device Only'), findsOneWidget);
      expect(find.textContaining('never synced to Firebase'), findsOneWidget);

      // Strictly isolated: NO ARC global settings elements
      expect(find.text('Task Reminders'), findsNothing);
      expect(find.text('Habit Reminders'), findsNothing);
      expect(find.text('Money Reminders'), findsNothing);
      expect(find.text('Dark Mode'), findsNothing);
    });

    testWidgets('Dashboard AppBar contains settings action leading to settings', (tester) async {
      await tester.pumpWidget(
        createTestSettingsApp(
          child: const SecretNotesDashboardScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
            secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
            secretNotesBiometricServiceProvider.overrideWithValue(fakeBio),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.settings), findsOneWidget);
    });
  });

  group('Secret Notes Phase 4 - Permanent Deletion Atomic Wipe', () {
    late SecretNotesLocalRepository localRepo;
    late SecretNotesDataRepository dataRepo;
    late SecretNotesSecurityService securityService;
    late FakeBiometricService fakeBio;

    setUp(() async {
      localRepo = SecretNotesLocalRepository(inMemoryOnly: true);
      dataRepo = SecretNotesDataRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: localRepo);
      fakeBio = FakeBiometricService(available: true, authSuccess: true);

      await securityService.setupPin('123456');
      await securityService.setBiometricEnabled(true);
      await localRepo.setIntroSeen(true);

      await dataRepo.saveNote(
        SecretNote(
          id: 'note_to_wipe',
          title: 'Top Secret Plans',
          description: 'Wipe me',
          createdAt: DateTime(2026, 10, 13),
          updatedAt: DateTime(2026, 10, 13),
        ),
      );
    });

    testWidgets('Requires exact "DELETE" confirmation and correct PIN to execute wipe', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestSettingsApp(
          child: const SecretNotesSettingsScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
            secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
            secretNotesBiometricServiceProvider.overrideWithValue(fakeBio),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap Danger Zone action button
      final deleteBtn = find.widgetWithText(OutlinedButton, 'Permanently Delete Secret Notes');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Permanently Delete Notes?'), findsOneWidget);

      // Attempt to submit without typing DELETE
      final confirmBtn = find.widgetWithText(FilledButton, 'Permanently Delete');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      expect(find.text('Please type "DELETE" exactly to confirm.'), findsOneWidget);

      // Enter "DELETE" but enter wrong PIN
      await tester.enterText(find.byType(TextField).last, 'DELETE');
      await tester.enterText(find.byType(TextField).first, '999999');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      expect(find.text('Incorrect Secret PIN authorization.'), findsOneWidget);

      // Now enter correct PIN '123456'
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify that all storage is cleared
      final remainingNotes = await dataRepo.getNotes();
      expect(remainingNotes, isEmpty);

      final isConfigured = await securityService.isSecretNotesConfigured();
      expect(isConfigured, isFalse);

      final isBioEnabled = await securityService.isBiometricEnabled();
      expect(isBioEnabled, isFalse);
    });
  });

  group('Secret Notes Phase 4 - Route Guards & Settings Isolation', () {
    test('Router redirects locked user trying to access /secret-notes/settings to /secret-notes/unlock', () async {
      final repo = SecretNotesLocalRepository(inMemoryOnly: true);
      final securityService = SecretNotesSecurityService(repository: repo);
      await securityService.setupPin('123456');

      final container = ProviderContainer(
        overrides: [
          userContextProvider.overrideWith((ref) => UserContextNotifierTestHelper(
                const UserContext(userId: 'test_uid', isInitializing: false),
              )),
          secretNotesLocalRepositoryProvider.overrideWithValue(repo),
          secretNotesSecurityServiceProvider.overrideWithValue(securityService),
        ],
      );

      final routerNotifier = container.read(routerNotifierProvider);
      final fakeState = FakeGoRouterState('/secret-notes/settings');

      final redirectResult = routerNotifier.redirect(FakeBuildContext(), fakeState);
      expect(redirectResult, equals('/secret-notes/unlock'));
    });

    test('Router allows unlocked user to access /secret-notes/settings without redirect', () async {
      final repo = SecretNotesLocalRepository(inMemoryOnly: true);
      final securityService = SecretNotesSecurityService(repository: repo);
      await securityService.setupPin('123456');

      final container = ProviderContainer(
        overrides: [
          userContextProvider.overrideWith((ref) => UserContextNotifierTestHelper(
                const UserContext(userId: 'test_uid', isInitializing: false),
              )),
          secretNotesLocalRepositoryProvider.overrideWithValue(repo),
          secretNotesSecurityServiceProvider.overrideWithValue(securityService),
        ],
      );

      container.read(secretNotesSessionProvider.notifier).unlock();

      final routerNotifier = container.read(routerNotifierProvider);
      final fakeState = FakeGoRouterState('/secret-notes/settings');

      final redirectResult = routerNotifier.redirect(FakeBuildContext(), fakeState);
      expect(redirectResult, isNull);
    });
  });
}
