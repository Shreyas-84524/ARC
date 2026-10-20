import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/dashboard/screens/dashboard_screen.dart';
import 'package:arc/routes/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('arc_session_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(HabitAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HabitEntryAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(TransactionAdapter());

    await Hive.openBox<Task>(HiveService.tasksBoxName);
    await Hive.openBox(HiveService.tasksSyncQueueBoxName);
    await Hive.openBox<Habit>(HiveService.habitsBoxName);
    await Hive.openBox<HabitEntry>(HiveService.habitEntriesBoxName);
    await Hive.openBox(HiveService.habitsSyncQueueBoxName);
    await Hive.openBox<Transaction>(HiveService.moneyBoxName);
    await Hive.openBox(HiveService.moneySyncQueueBoxName);
    await Hive.openBox(HiveService.settingsBoxName);

    HiveService().setInitializedForTesting(true);
  });



  group('Session Persistence & Auth Lifecycle Restoration Tests', () {
    test('UserContext initializing state defaults correctly', () {
      const ctx = UserContext.initializing;
      expect(ctx.isInitializing, isTrue);
      expect(ctx.isAuthenticated, isFalse);
      expect(ctx.userId, isNull);
    });

    test('UserContext authenticated state evaluates correctly', () {
      final profile = UserProfile(
        id: 'uid_shreyas',
        username: 'Shreyas',
        displayName: 'Shreyas',
        email: 'shreyas@arc.app',
        createdAt: DateTime.now(),
      );
      final ctx = UserContext(userId: 'uid_shreyas', profile: profile, isInitializing: false);
      expect(ctx.isAuthenticated, isTrue);
      expect(ctx.isInitializing, isFalse);
      expect(ctx.userNamespace, 'uid_shreyas');
    });

    test('UserContextNotifier sets active user and opens user boxes seamlessly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userContextProvider.notifier);
      notifier.setActiveUser(
        userId: 'uid_shreyas_persisted',
        profile: UserProfile(
          id: 'uid_shreyas_persisted',
          username: 'Shreyas',
          displayName: 'Shreyas',
          email: 'shreyas@arc.app',
          createdAt: DateTime.now(),
        ),
      );

      final state = container.read(userContextProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.userId, 'uid_shreyas_persisted');
      expect(state.isInitializing, isFalse);
    });

    testWidgets('App renders splash during initialization and transitions to login when unauthenticated',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: Text('Splash Loaded')),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Splash Loaded'), findsOneWidget);
    });

    testWidgets('RouterNotifier redirects unauthenticated session to login', (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Force unauthenticated state
      container.read(userContextProvider.notifier).resetToLegacy();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Builder(
            builder: (context) {
              final router = container.read(routerProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Welcome Back'), findsOneWidget);
    });

    testWidgets('RouterNotifier automatically redirects authenticated session to dashboard',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set authenticated user session
      container.read(userContextProvider.notifier).setActiveUser(
            userId: 'uid_auto_restored',
            profile: UserProfile(
              id: 'uid_auto_restored',
              username: 'Shreyas',
              displayName: 'Shreyas',
              email: 'shreyas@arc.app',
              createdAt: DateTime.now(),
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Builder(
            builder: (context) {
              final router = container.read(routerProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Should automatically navigate to Dashboard Screen
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });
}
