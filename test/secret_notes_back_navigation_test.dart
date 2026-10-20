import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_local_repository.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_data_repository.dart';
import 'package:arc/features/secret_notes/services/secret_notes_security_service.dart';
import 'package:arc/features/secret_notes/services/secret_notes_biometric_service.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_setup_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_unlock_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_dashboard_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_settings_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_note_editor_screen.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/task_manager/screens/tasks_screen.dart';
import 'package:arc/providers/global_providers.dart';

class InMemoryTaskRepo implements TaskRepository {
  final List<Task> _tasks = [];

  @override
  String? get userId => 'test_user';

  @override
  List<Task> getTasks() => List.unmodifiable(_tasks);

  @override
  Future<void> saveTask(Task task) async {
    _tasks.add(task);
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }

  @override
  Future<bool> syncPending() async => true;

  @override
  Future<int> performEndOfDayCleanup({String? overrideDateStr}) async => 0;
}

class FakeBioService extends SecretNotesBiometricService {
  @override
  Future<bool> isBiometricAvailable() async => false;
}

GoRouter createTestRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/tasks',
        builder: (context, state) => const TasksScreen(),
      ),
      GoRoute(
        path: '/secret-notes/setup',
        builder: (context, state) => const SecretNotesSetupScreen(),
      ),
      GoRoute(
        path: '/secret-notes/unlock',
        builder: (context, state) => const SecretNotesUnlockScreen(),
      ),
      GoRoute(
        path: '/secret-notes',
        builder: (context, state) => const SecretNotesDashboardScreen(),
      ),
      GoRoute(
        path: '/secret-notes/settings',
        builder: (context, state) => const SecretNotesSettingsScreen(),
      ),
      GoRoute(
        path: '/secret-notes/new',
        builder: (context, state) => const SecretNoteEditorScreen(),
      ),
      GoRoute(
        path: '/secret-notes/:id',
        builder: (context, state) {
          final noteId = state.pathParameters['id'] ?? '';
          return SecretNoteEditorScreen(noteId: noteId);
        },
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late SecretNotesLocalRepository localRepo;
  late SecretNotesDataRepository dataRepo;
  late SecretNotesSecurityService securityService;
  late InMemoryTaskRepo taskRepo;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('arc_back_nav_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  setUp(() async {
    localRepo = SecretNotesLocalRepository(inMemoryOnly: true);
    dataRepo = SecretNotesDataRepository(inMemoryOnly: true);
    securityService = SecretNotesSecurityService(repository: localRepo);
    taskRepo = InMemoryTaskRepo();
  });

  Widget createHarness({
    required GoRouter router,
    required ProviderContainer container,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    );
  }

  group('Secret Notes Back Navigation - Tasks to Secret Notes and Back', () {
    testWidgets('Tasks -> swipe -> Secret Notes (unlocked) -> Back Button -> Tasks (and session locked)', (tester) async {
      await securityService.setupPin('123456');
      await securityService.markIntroSeen();

      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepo),
          secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
          secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          secretNotesBiometricServiceProvider.overrideWithValue(FakeBioService()),
        ],
      );

      // Pre-unlock session
      container.read(secretNotesSessionProvider.notifier).unlock();
      expect(container.read(secretNotesSessionProvider), isTrue);

      final router = createTestRouter(initialLocation: '/tasks');

      await tester.pumpWidget(createHarness(router: router, container: container));
      await tester.pumpAndSettle();

      expect(find.byType(TasksScreen), findsOneWidget);

      // 1. Swipe right to open Secret Notes
      await tester.drag(find.byType(TasksScreen), const Offset(150, 0));
      await tester.pumpAndSettle();

      expect(find.byType(SecretNotesDashboardScreen), findsOneWidget);

      // 2. Tap AppBar Back button on Secret Notes Dashboard
      final backBtn = find.widgetWithIcon(IconButton, LucideIcons.arrowLeft);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // 3. Confirm returned to TasksScreen and session is locked
      expect(find.byType(TasksScreen), findsOneWidget);
      expect(container.read(secretNotesSessionProvider), isFalse);
    });

    testWidgets('Tasks -> swipe -> Secret Notes (unlocked) -> Android System Back -> Tasks (and app does not exit)', (tester) async {
      await securityService.setupPin('123456');
      await securityService.markIntroSeen();

      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepo),
          secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
          secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          secretNotesBiometricServiceProvider.overrideWithValue(FakeBioService()),
        ],
      );

      container.read(secretNotesSessionProvider.notifier).unlock();
      final router = createTestRouter(initialLocation: '/tasks');

      await tester.pumpWidget(createHarness(router: router, container: container));
      await tester.pumpAndSettle();

      // Swipe to open
      await tester.drag(find.byType(TasksScreen), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(find.byType(SecretNotesDashboardScreen), findsOneWidget);

      // Simulate Android system back gesture / button
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue); // Pop was handled, app did not exit!
      await tester.pumpAndSettle();

      expect(find.byType(TasksScreen), findsOneWidget);
      expect(container.read(secretNotesSessionProvider), isFalse);
    });
  });

  group('Secret Notes Back Navigation - Editor to Dashboard to Tasks', () {
    testWidgets('Secret Notes Editor -> Back -> Secret Notes Dashboard -> Back -> Tasks', (tester) async {
      await securityService.setupPin('123456');
      await securityService.markIntroSeen();

      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepo),
          secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
          secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          secretNotesBiometricServiceProvider.overrideWithValue(FakeBioService()),
        ],
      );

      container.read(secretNotesSessionProvider.notifier).unlock();
      final router = createTestRouter(initialLocation: '/secret-notes');

      await tester.pumpWidget(createHarness(router: router, container: container));
      await tester.pumpAndSettle();

      expect(find.byType(SecretNotesDashboardScreen), findsOneWidget);

      // 1. Open New Note Editor
      final addBtn = find.text('Add Note');
      expect(addBtn, findsWidgets);
      await tester.tap(addBtn.first);
      await tester.pumpAndSettle();

      expect(find.byType(SecretNoteEditorScreen), findsOneWidget);

      // 2. Tap Back from Editor -> should return to Secret Notes Dashboard
      final editorBackBtn = find.widgetWithIcon(IconButton, LucideIcons.arrowLeft);
      expect(editorBackBtn, findsOneWidget);
      await tester.tap(editorBackBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SecretNotesDashboardScreen), findsOneWidget);

      // 3. Tap Back from Dashboard -> should return to Tasks
      final dashboardBackBtn = find.widgetWithIcon(IconButton, LucideIcons.arrowLeft);
      expect(dashboardBackBtn, findsOneWidget);
      await tester.tap(dashboardBackBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TasksScreen), findsOneWidget);
      expect(container.read(secretNotesSessionProvider), isFalse);
    });

    testWidgets('Secret Notes Editor -> Android System Back -> Secret Notes Dashboard -> Android System Back -> Tasks', (tester) async {
      await securityService.setupPin('123456');
      await securityService.markIntroSeen();

      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepo),
          secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
          secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          secretNotesBiometricServiceProvider.overrideWithValue(FakeBioService()),
        ],
      );

      container.read(secretNotesSessionProvider.notifier).unlock();
      final router = createTestRouter(initialLocation: '/secret-notes');

      await tester.pumpWidget(createHarness(router: router, container: container));
      await tester.pumpAndSettle();

      // Open note editor
      await tester.tap(find.text('Add Note').first);
      await tester.pumpAndSettle();
      expect(find.byType(SecretNoteEditorScreen), findsOneWidget);

      // Android back from editor
      final handled1 = await tester.binding.handlePopRoute();
      expect(handled1, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(SecretNotesDashboardScreen), findsOneWidget);

      // Android back from dashboard
      final handled2 = await tester.binding.handlePopRoute();
      expect(handled2, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(TasksScreen), findsOneWidget);
      expect(container.read(secretNotesSessionProvider), isFalse);
    });
  });

  group('Secret Notes Back Navigation - Settings to Dashboard to Tasks', () {
    testWidgets('Secret Notes Settings -> Back -> Secret Notes Dashboard -> Back -> Tasks', (tester) async {
      await securityService.setupPin('123456');
      await securityService.markIntroSeen();

      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepo),
          secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
          secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          secretNotesBiometricServiceProvider.overrideWithValue(FakeBioService()),
        ],
      );

      container.read(secretNotesSessionProvider.notifier).unlock();
      final router = createTestRouter(initialLocation: '/secret-notes');

      await tester.pumpWidget(createHarness(router: router, container: container));
      await tester.pumpAndSettle();

      expect(find.byType(SecretNotesDashboardScreen), findsOneWidget);

      // 1. Open Settings
      final settingsIcon = find.byTooltip('Secret Notes Settings');
      expect(settingsIcon, findsOneWidget);
      await tester.tap(settingsIcon);
      await tester.pumpAndSettle();

      expect(find.byType(SecretNotesSettingsScreen), findsOneWidget);

      // 2. Tap Back from Settings -> should return to Secret Notes Dashboard
      final settingsBackBtn = find.widgetWithIcon(IconButton, LucideIcons.arrowLeft);
      expect(settingsBackBtn, findsOneWidget);
      await tester.tap(settingsBackBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SecretNotesDashboardScreen), findsOneWidget);

      // 3. Tap Back from Dashboard -> should return to Tasks
      final dashboardBackBtn = find.widgetWithIcon(IconButton, LucideIcons.arrowLeft);
      expect(dashboardBackBtn, findsOneWidget);
      await tester.tap(dashboardBackBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TasksScreen), findsOneWidget);
      expect(container.read(secretNotesSessionProvider), isFalse);
    });

    testWidgets('Secret Notes Settings -> Android System Back -> Secret Notes Dashboard -> Android System Back -> Tasks', (tester) async {
      await securityService.setupPin('123456');
      await securityService.markIntroSeen();

      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepo),
          secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
          secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          secretNotesBiometricServiceProvider.overrideWithValue(FakeBioService()),
        ],
      );

      container.read(secretNotesSessionProvider.notifier).unlock();
      final router = createTestRouter(initialLocation: '/secret-notes');

      await tester.pumpWidget(createHarness(router: router, container: container));
      await tester.pumpAndSettle();

      // Open Settings
      await tester.tap(find.byTooltip('Secret Notes Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SecretNotesSettingsScreen), findsOneWidget);

      // Android back from Settings
      final handled1 = await tester.binding.handlePopRoute();
      expect(handled1, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(SecretNotesDashboardScreen), findsOneWidget);

      // Android back from Dashboard
      final handled2 = await tester.binding.handlePopRoute();
      expect(handled2, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(TasksScreen), findsOneWidget);
      expect(container.read(secretNotesSessionProvider), isFalse);
    });
  });

  group('Secret Notes Back Navigation - Unlock & Setup Cancel Flow', () {
    testWidgets('Secret Notes Unlock Screen -> Back / PopRoute -> Tasks', (tester) async {
      await securityService.setupPin('123456');

      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepo),
          secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
          secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          secretNotesBiometricServiceProvider.overrideWithValue(FakeBioService()),
        ],
      );

      final router = createTestRouter(initialLocation: '/secret-notes/unlock');

      await tester.pumpWidget(createHarness(router: router, container: container));
      await tester.pumpAndSettle();

      expect(find.byType(SecretNotesUnlockScreen), findsOneWidget);

      // Tap back button
      final backBtn = find.widgetWithIcon(IconButton, LucideIcons.arrowLeft);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TasksScreen), findsOneWidget);
    });

    testWidgets('Secret Notes Setup Screen -> Back / PopRoute -> Tasks', (tester) async {
      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepo),
          secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
          secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          secretNotesBiometricServiceProvider.overrideWithValue(FakeBioService()),
        ],
      );

      final router = createTestRouter(initialLocation: '/secret-notes/setup');

      await tester.pumpWidget(createHarness(router: router, container: container));
      await tester.pumpAndSettle();

      expect(find.byType(SecretNotesSetupScreen), findsOneWidget);

      // Android back
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(TasksScreen), findsOneWidget);
    });
  });
}
