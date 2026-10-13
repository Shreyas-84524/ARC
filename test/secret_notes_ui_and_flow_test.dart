import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_local_repository.dart';
import 'package:arc/features/secret_notes/services/secret_notes_security_service.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_setup_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_unlock_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_dashboard_screen.dart';
import 'package:arc/features/secret_notes/widgets/secret_notes_intro_dialog.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/task_manager/screens/tasks_screen.dart';
import 'package:arc/providers/global_providers.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/routes/app_router.dart';

Widget createTestApp({
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
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('arc_secret_notes_ui_test_');
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

  group('Secret Notes - Setup Screen Widget Tests', () {
    late SecretNotesLocalRepository repo;
    late SecretNotesSecurityService securityService;

    setUp(() {
      repo = SecretNotesLocalRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: repo);
    });

    testWidgets('Renders setup fields and Continue button', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const SecretNotesSetupScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Secret PIN'), findsWidgets);
      expect(find.text('Confirm Secret PIN'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Shows error when PIN is empty or invalid length', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        createTestApp(
          child: const SecretNotesSetupScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap Continue with empty fields
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('PIN cannot be empty'), findsOneWidget);

      // Enter short PIN (3 digits)
      final pinFields = find.byType(TextField);
      await tester.enterText(pinFields.first, '123');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('PIN must be exactly 6 digits'), findsOneWidget);
    });

    testWidgets('Shows error when PINs do not match', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        createTestApp(
          child: const SecretNotesSetupScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final pinFields = find.byType(TextField);
      await tester.enterText(pinFields.first, '123456');
      await tester.enterText(pinFields.last, '654321');

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('PINs do not match'), findsOneWidget);
    });
  });

  group('Secret Notes - Unlock Screen Widget Tests', () {
    late SecretNotesLocalRepository repo;
    late SecretNotesSecurityService securityService;

    setUp(() async {
      repo = SecretNotesLocalRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: repo);
      await securityService.setupPin('123456');
    });

    testWidgets('Renders Enter Secret PIN and Unlock button', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        createTestApp(
          child: const SecretNotesUnlockScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter Secret PIN'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
    });

    testWidgets('Shows error on incorrect PIN', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        createTestApp(
          child: const SecretNotesUnlockScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final pinField = find.byType(TextField);
      await tester.enterText(pinField, '999999');
      await tester.pumpAndSettle();

      expect(find.text('Incorrect Secret PIN'), findsOneWidget);
    });

    testWidgets('Triggers lockout UI after repeated incorrect attempts', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      // Simulate 5 failed attempts
      for (int i = 0; i < 5; i++) {
        await securityService.verifyPin('000000');
      }

      await tester.pumpWidget(
        createTestApp(
          child: const SecretNotesUnlockScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Too many failed attempts'), findsOneWidget);
      expect(find.textContaining('Locked'), findsOneWidget);
    });
  });

  group('Secret Notes - Intro Dialog Widget Tests', () {
    late SecretNotesLocalRepository repo;
    late SecretNotesSecurityService securityService;

    setUp(() {
      repo = SecretNotesLocalRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: repo);
    });

    testWidgets('Displays all 5 points and I Understand button', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const SecretNotesIntroDialog(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Secret Notes'), findsOneWidget);
      expect(find.text('1. Local only'), findsOneWidget);
      expect(find.text('2. Separate PIN'), findsOneWidget);
      expect(find.text('3. Independent settings'), findsOneWidget);
      expect(find.text('4. Possible permanent loss'), findsOneWidget);
      expect(find.text('5. Keep your PIN safe'), findsOneWidget);
      expect(find.text('I Understand'), findsOneWidget);

      // Tap I Understand
      await tester.tap(find.text('I Understand'));
      await tester.pumpAndSettle();

      expect(await securityService.hasSeenIntro(), isTrue);
    });
  });

  group('Secret Notes - Dashboard Screen Widget Tests', () {
    late SecretNotesLocalRepository repo;
    late SecretNotesSecurityService securityService;

    setUp(() {
      repo = SecretNotesLocalRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: repo);
    });

    testWidgets('Renders Secret Notes placeholder and lock button', (tester) async {
      // Set intro as already seen so popup does not block
      await securityService.markIntroSeen();

      await tester.pumpWidget(
        createTestApp(
          child: const SecretNotesDashboardScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Secret Notes'), findsWidgets);
      expect(find.text('No secret notes yet'), findsOneWidget);
      expect(find.byTooltip('Lock Secret Notes'), findsOneWidget);
    });

    testWidgets('Automatically presents intro dialog on first visit', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const SecretNotesDashboardScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Should show the intro dialog
      expect(find.byType(SecretNotesIntroDialog), findsOneWidget);
      expect(find.text('I Understand'), findsOneWidget);

      // Acknowledge
      await tester.tap(find.text('I Understand'));
      await tester.pumpAndSettle();

      expect(find.byType(SecretNotesIntroDialog), findsNothing);
      expect(find.text('No secret notes yet'), findsOneWidget);
    });
  });

  group('Secret Notes - Swipe Entry Gesture on Tasks Screen', () {
    late SecretNotesLocalRepository repo;
    late SecretNotesSecurityService securityService;

    setUp(() {
      repo = SecretNotesLocalRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: repo);
    });

    testWidgets('Deliberate left-to-right swipe opens Secret Notes access flow', (tester) async {
      bool opened = false;
      final router = GoRouter(
        initialLocation: '/tasks',
        routes: [
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: '/secret-notes/setup',
            builder: (context, state) {
              opened = true;
              return const Scaffold(body: Text('Setup Screen Target'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe from left to right with distance 150px (exceeds 80px threshold)
      await tester.drag(find.byType(TasksScreen), const Offset(150, 0));
      await tester.pumpAndSettle();

      expect(opened, isTrue);
      expect(find.text('Setup Screen Target'), findsOneWidget);
    });

    testWidgets('Accidental small horizontal swipe does NOT trigger Secret Notes', (tester) async {
      bool opened = false;
      final router = GoRouter(
        initialLocation: '/tasks',
        routes: [
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: '/secret-notes/setup',
            builder: (context, state) {
              opened = true;
              return const Scaffold(body: Text('Setup Screen Target'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Small drag 30px (below 80px threshold)
      await tester.drag(find.byType(TasksScreen), const Offset(30, 0));
      await tester.pumpAndSettle();

      expect(opened, isFalse);
      expect(find.text('Setup Screen Target'), findsNothing);
      expect(find.byType(TasksScreen), findsOneWidget);
    });

    testWidgets('Normal vertical task scrolling continues to function', (tester) async {
      final taskRepo = InMemoryTaskRepository();
      // Add multiple sample tasks so list has items
      for (int i = 0; i < 10; i++) {
        taskRepo.saveTask(Task(
          id: 'task_$i',
          title: 'Sample Task $i',
          description: '',
          priority: 'High',
          category: 'Work',
          labels: const [],
          dueDate: DateTime.now().add(Duration(days: i)),
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      final router = GoRouter(
        initialLocation: '/tasks',
        routes: [
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(taskRepo),
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Vertical drag (downward/upward scroll)
      await tester.drag(find.byType(TasksScreen), const Offset(0, -200));
      await tester.pumpAndSettle();

      // TasksScreen should still be present and no routing occurred
      expect(find.byType(TasksScreen), findsOneWidget);
    });
  });

  group('Secret Notes - Router Navigation Isolation Tests', () {
    test('Unauthenticated user is redirected away from /secret-notes to /login', () {
      final container = ProviderContainer(
        overrides: [
          userContextProvider.overrideWith((ref) => UserContextNotifierTestHelper(UserContext.legacy)),
        ],
      );

      final routerNotifier = container.read(routerNotifierProvider);
      final fakeState = FakeGoRouterState('/secret-notes');

      final redirectResult = routerNotifier.redirect(FakeBuildContext(), fakeState);
      expect(redirectResult, equals('/login'));
    });

    test('Unconfigured user on /secret-notes is redirected to /secret-notes/setup', () {
      final repo = SecretNotesLocalRepository(inMemoryOnly: true);
      final securityService = SecretNotesSecurityService(repository: repo);

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
      final fakeState = FakeGoRouterState('/secret-notes');

      final redirectResult = routerNotifier.redirect(FakeBuildContext(), fakeState);
      expect(redirectResult, equals('/secret-notes/setup'));
    });

    test('Configured but locked user on /secret-notes is redirected to /secret-notes/unlock', () async {
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
      final fakeState = FakeGoRouterState('/secret-notes');

      final redirectResult = routerNotifier.redirect(FakeBuildContext(), fakeState);
      expect(redirectResult, equals('/secret-notes/unlock'));
    });

    test('Unlocked user can access /secret-notes without redirection', () async {
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
      final fakeState = FakeGoRouterState('/secret-notes');

      final redirectResult = routerNotifier.redirect(FakeBuildContext(), fakeState);
      expect(redirectResult, isNull);
    });
  });
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

class InMemoryTaskRepository implements TaskRepository {
  final List<Task> _tasks = [];

  @override
  String? get userId => 'test_user';

  @override
  List<Task> getTasks() => List.unmodifiable(_tasks);

  @override
  Future<void> saveTask(Task task) async {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      _tasks[idx] = task;
    } else {
      _tasks.add(task);
    }
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
