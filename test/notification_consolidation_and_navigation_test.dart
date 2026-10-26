import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arc/core/notifications/notification_controller.dart';
import 'package:arc/core/notifications/notification_models.dart';
import 'package:arc/core/notifications/notification_orchestrator.dart';
import 'package:arc/core/notifications/notification_policy.dart';
import 'package:arc/core/notifications/notification_service.dart';
import 'package:arc/features/dashboard/screens/shell_screen.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/settings/models/settings_model.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/features/feedback/providers/feedback_providers.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/settings/repository/settings_repository.dart';
import 'package:arc/providers/global_providers.dart';
import 'package:arc/routes/app_router.dart';

/// Test gateway simulating FlutterLocalNotificationsPlugin
class TestNotificationGateway implements LocalNotificationGateway {
  final Map<int, ArcPendingNotification> pending = {};
  final StreamController<ArcNotificationPayload> _tapController =
      StreamController<ArcNotificationPayload>.broadcast(sync: true);

  ArcNotificationPermissionState permission = ArcNotificationPermissionState.granted;
  bool initialized = false;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  ArcNotificationPayload? launchPayload;

  @override
  bool get isInitialized => initialized;

  @override
  String get timezoneName => 'Asia/Kolkata';

  @override
  Stream<ArcNotificationPayload> get notificationTaps => _tapController.stream;

  @override
  Future<void> initialize() async {
    initialized = true;
    if (launchPayload != null) {
      _tapController.add(launchPayload!);
    }
  }

  @override
  Future<ArcNotificationPermissionState> permissionState() async => permission;

  @override
  Future<ArcNotificationPermissionState> requestPermission() async => permission;

  @override
  Future<List<ArcPendingNotification>> pendingNotifications() async =>
      pending.values.toList(growable: false);

  @override
  Future<void> schedule(ArcNotificationSpec spec) async {
    scheduleCalls++;
    pending[spec.id] = ArcPendingNotification(id: spec.id, payload: spec.payload);
  }

  @override
  Future<void> show(ArcNotificationSpec spec) async {
    scheduleCalls++;
    pending[spec.id] = ArcPendingNotification(id: spec.id, payload: spec.payload);
  }

  @override
  Future<void> cancel(int id) async {
    cancelCalls++;
    pending.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelCalls += pending.length;
    pending.clear();
  }

  @override
  Future<void> dispose() async {
    await _tapController.close();
  }

  void simulateTap(ArcNotificationPayload payload) {
    _tapController.add(payload);
  }
}

/// Controllable UserContext notifier for testing
class TestUserNotifier extends UserContextNotifier {
  TestUserNotifier([UserContext? initial]) {
    if (initial != null) {
      state = initial;
    }
  }

  void setUser(String userId, String username) {
    state = UserContext(
      userId: userId,
      profile: UserProfile(
        id: userId,
        username: username,
        displayName: username,
        email: '$username@test.com',
        createdAt: DateTime.now(),
      ),
      isInitializing: false,
    );
  }

  void setInitializing() {
    state = UserContext.initializing;
  }

  void setLoggedOut() {
    state = UserContext.legacy;
  }
}

/// In-memory mock Hive box for testing migration flags
class FakeHiveBox {
  final Map<String, dynamic> _data = {};

  dynamic get(String key, {dynamic defaultValue}) =>
      _data.containsKey(key) ? _data[key] : defaultValue;

  Future<void> put(String key, dynamic value) async {
    _data[key] = value;
  }

  bool containsKey(String key) => _data.containsKey(key);
}

NotificationSnapshot createSnapshot({
  SettingsModel? settings,
  List<Habit> habits = const [],
  List<HabitEntry> habitEntries = const [],
  List<Task> tasks = const [],
  List<Transaction> transactions = const [],
  DateTime? now,
  String? userId = 'user_1',
}) {
  return NotificationSnapshot(
    userId: userId,
    settings: settings ?? SettingsModel.defaultSettings().copyWith(moneyRemindersEnabled: false),
    habits: habits,
    habitEntries: habitEntries,
    tasks: tasks,
    transactions: transactions,
    now: now ?? DateTime(2026, 10, 26, 10, 0),
  );
}

class MockTaskRepo implements TaskRepository {
  @override
  String? get userId => null;
  @override
  List<Task> getTasks() => [];
  @override
  Future<void> saveTask(Task task) async {}
  @override
  Future<void> deleteTask(String id) async {}
  @override
  Future<bool> syncPending() async => true;
  @override
  Future<int> performEndOfDayCleanup({String? overrideDateStr}) async => 0;
}

class MockHabitRepo implements HabitRepository {
  @override
  String? get userId => null;
  @override
  List<Habit> getHabits() => [];
  @override
  List<HabitEntry> getEntries() => [];
  @override
  Future<void> saveHabit(Habit habit) async {}
  @override
  Future<void> deleteHabit(String id) async {}
  @override
  Future<void> toggleEntry(String habitId, String dateStr, bool completed) async {}
  @override
  Future<bool> syncPending() async => true;
}

class MockMoneyRepo implements MoneyRepository {
  @override
  String? get userId => null;
  @override
  List<Transaction> getTransactions() => [];
  @override
  double getMonthlyBudget(String yearMonth) => 0.0;
  @override
  Future<void> saveMonthlyBudget(String yearMonth, double amount) async {}
  @override
  Future<void> saveTransaction(Transaction tx) async {}
  @override
  Future<void> deleteTransaction(String id) async {}
  @override
  Future<void> saveMonthlySummary(summary) async {}
  @override
  Future<bool> syncPending() async => true;
}

class MockSettingsRepo implements SettingsRepository {
  @override
  String? get userId => null;
  @override
  SettingsModel getSettings() => SettingsModel.defaultSettings();
  @override
  Future<void> saveSettings(SettingsModel settings) async {}
  @override
  Future<bool> syncPending() async => true;
}

class TestDashboardScreen extends StatelessWidget {
  const TestDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Dashboard Screen'));
}

class TestHabitsScreen extends StatelessWidget {
  const TestHabitsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Habits Screen'));
}

class TestMoneyScreen extends StatelessWidget {
  const TestMoneyScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Money Screen'));
}

class TestTasksScreen extends StatelessWidget {
  final String? initialTaskId;
  const TestTasksScreen({super.key, this.initialTaskId});
  @override
  Widget build(BuildContext context) => Scaffold(body: Text('Tasks Screen: $initialTaskId'));
}

class TestMyFeedbackScreen extends StatelessWidget {
  const TestMyFeedbackScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('My Feedback Screen'));
}

class MockFeedbackAckService implements IFeedbackAcknowledgementService {
  @override
  Future<void> processFeedbackList({
    required String userId,
    required List<FeedbackModel> feedbackList,
  }) async {}

  @override
  bool isAcknowledgedLocally(String userId, String feedbackId) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationPolicy policy;
  late TestNotificationGateway gateway;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    policy = NotificationPolicy();
    gateway = TestNotificationGateway();
  });

  tearDown(() {
    gateway.dispose();
  });

  group('PROJECT ARC — NOTIFICATION CONSOLIDATION TESTS (Requirements 1 - 9)', () {
    // 1. Three pending habits result in one general daily check-in notification
    test('Requirement 1: Three pending habits produce exactly ONE consolidated Habit check-in notification', () {
      final habits = [
        Habit(id: 'h1', name: 'Read 20 mins', category: 'Personal', colorValue: 0xFFFFFFFF, createdAt: DateTime(2026, 10, 1), updatedAt: DateTime(2026, 10, 1)),
        Habit(id: 'h2', name: 'Meditate', category: 'Wellness', colorValue: 0xFFFFFFFF, createdAt: DateTime(2026, 10, 1), updatedAt: DateTime(2026, 10, 1)),
        Habit(id: 'h3', name: 'Exercise', category: 'Fitness', colorValue: 0xFFFFFFFF, createdAt: DateTime(2026, 10, 1), updatedAt: DateTime(2026, 10, 1)),
      ];

      final snapshot = createSnapshot(
        habits: habits,
        settings: SettingsModel.defaultSettings().copyWith(
          remTime: '21:00',
          habitRemindersEnabled: true,
        ),
      );

      final specs = policy.build(snapshot);

      // Verify ONLY 1 daily check-in habit reminder is created
      final habitSpecs = specs.where((s) => s.channel == ArcNotificationChannel.habits).toList();
      expect(habitSpecs.length, equals(1));

      final checkIn = habitSpecs.first;
      expect(checkIn.id, equals(NotificationPolicy.dailyHabitCheckInId));
      expect(checkIn.id, equals(999999));
      expect(checkIn.title, equals('Habit check-in'));
      expect(checkIn.body, equals("Don't forget to review today's habits."));
      expect(checkIn.scheduledAt.hour, equals(21));
      expect(checkIn.scheduledAt.minute, equals(0));
      expect(checkIn.recurrence, equals(ArcNotificationRecurrence.daily));

      // Assert NO per-habit pending reminders exist
      expect(specs.any((s) => s.type == ArcNotificationType.habitPending), isFalse);
    });

    // 2. Habit reminder scheduling is idempotent
    test('Requirement 2: Habit reminder scheduling is idempotent across repeated reconciliations', () async {
      final controller = NotificationController(gateway: gateway, policy: policy);
      await controller.initialize();

      final habits = [
        Habit(id: 'h1', name: 'Read', category: 'Personal', colorValue: 0xFFFFFFFF, createdAt: DateTime(2026, 10, 1), updatedAt: DateTime(2026, 10, 1)),
      ];
      final snapshot = createSnapshot(habits: habits);

      // First run: schedules notification
      await controller.reconcile(snapshot, reason: 'first_run');
      expect(controller.state.scheduledCount, equals(1));
      expect(controller.state.unchangedCount, equals(0));
      expect(gateway.pending.containsKey(NotificationPolicy.dailyHabitCheckInId), isTrue);

      // Second run: identical snapshot -> unchanged
      await controller.reconcile(snapshot, reason: 'second_run');
      expect(controller.state.scheduledCount, equals(0));
      expect(controller.state.unchangedCount, equals(1));
      expect(gateway.pending.length, equals(1));

      controller.dispose();
    });

    // 3. Restarting Arc does not duplicate notifications
    test('Requirement 3: Restarting Arc does not duplicate notifications', () async {
      final habits = [
        Habit(id: 'h1', name: 'Read', category: 'Personal', colorValue: 0xFFFFFFFF, createdAt: DateTime(2026, 10, 1), updatedAt: DateTime(2026, 10, 1)),
      ];
      final snapshot = createSnapshot(habits: habits);

      // Session 1: initial schedule
      final controller1 = NotificationController(gateway: gateway, policy: policy);
      await controller1.initialize();
      await controller1.reconcile(snapshot, reason: 'session_1');
      expect(gateway.scheduleCalls, equals(1));
      expect(gateway.pending.length, equals(1));
      controller1.dispose();

      // Session 2: simulates app restart with existing gateway pending state
      final controller2 = NotificationController(gateway: gateway, policy: policy);
      await controller2.initialize();
      await controller2.reconcile(snapshot, reason: 'startup');

      // Schedule calls should not have increased; notification recognized as unchanged
      expect(controller2.state.unchangedCount, equals(1));
      expect(controller2.state.scheduledCount, equals(0));
      expect(gateway.scheduleCalls, equals(1)); // Unchanged
      expect(gateway.pending.length, equals(1));
      controller2.dispose();
    });

    // 4. Changing the reminder time replaces the previous schedule
    test('Requirement 4: Changing the reminder time replaces previous schedule with new time', () async {
      final controller = NotificationController(gateway: gateway, policy: policy);
      await controller.initialize();

      final habits = [
        Habit(id: 'h1', name: 'Read', category: 'Personal', colorValue: 0xFFFFFFFF, createdAt: DateTime(2026, 10, 1), updatedAt: DateTime(2026, 10, 1)),
      ];

      // Schedule at 20:00
      final snapshot20 = createSnapshot(
        habits: habits,
        settings: SettingsModel.defaultSettings().copyWith(
          remTime: '20:00',
          moneyRemindersEnabled: false,
        ),
      );
      await controller.reconcile(snapshot20, reason: 'initial_2000');
      expect(controller.state.scheduledCount, equals(1));

      // Update to 21:30
      final snapshot2130 = createSnapshot(
        habits: habits,
        settings: SettingsModel.defaultSettings().copyWith(
          remTime: '21:30',
          moneyRemindersEnabled: false,
        ),
      );
      await controller.reconcile(snapshot2130, reason: 'updated_2130');

      // Old schedule cancelled, new scheduled; total pending remains exactly 1
      expect(controller.state.cancelledCount, equals(1));
      expect(controller.state.scheduledCount, equals(1));
      expect(gateway.pending.length, equals(1));
      expect(gateway.pending.containsKey(NotificationPolicy.dailyHabitCheckInId), isTrue);

      controller.dispose();
    });

    // 5. Disabling reminders cancels the correct notification
    test('Requirement 5: Disabling habit reminders cancels the habit notification while preserving others', () async {
      final controller = NotificationController(gateway: gateway, policy: policy);
      await controller.initialize();

      final habits = [
        Habit(id: 'h1', name: 'Read', category: 'Personal', colorValue: 0xFFFFFFFF, createdAt: DateTime(2026, 10, 1), updatedAt: DateTime(2026, 10, 1)),
      ];
      final snapshotEnabled = createSnapshot(
        habits: habits,
        settings: SettingsModel.defaultSettings().copyWith(
          habitRemindersEnabled: true,
          moneyRemindersEnabled: true,
        ),
      );
      await controller.reconcile(snapshotEnabled, reason: 'enabled');
      expect(gateway.pending.containsKey(NotificationPolicy.dailyHabitCheckInId), isTrue);
      expect(gateway.pending.containsKey(NotificationPolicy.moneyReminderId), isTrue);

      // Disable ONLY habit reminders
      final snapshotDisabled = createSnapshot(
        habits: habits,
        settings: SettingsModel.defaultSettings().copyWith(
          habitRemindersEnabled: false,
          moneyRemindersEnabled: true,
        ),
      );
      await controller.reconcile(snapshotDisabled, reason: 'habits_disabled');

      // Habit reminder cancelled; money reminder preserved
      expect(gateway.pending.containsKey(NotificationPolicy.dailyHabitCheckInId), isFalse);
      expect(gateway.pending.containsKey(NotificationPolicy.moneyReminderId), isTrue);

      controller.dispose();
    });

    // 6. Existing obsolete reminders are removed safely
    test('Requirement 6: Obsolete per-habit reminders are cancelled while unrelated notifications are preserved', () async {
      final controller = NotificationController(gateway: gateway, policy: policy);
      final fakeBox = FakeHiveBox();

      // Pre-seed gateway with obsolete habitPending notifications + valid task and money reminders
      final obsoleteHabit1 = ArcNotificationSpec(
        id: NotificationPolicy.habitRemTimeMin + 10,
        type: ArcNotificationType.habitPending,
        channel: ArcNotificationChannel.habits,
        entityId: 'h1',
        title: 'Habit still pending',
        body: 'Do h1',
        scheduledAt: DateTime(2026, 10, 26, 21),
        recurrence: ArcNotificationRecurrence.daily,
        fingerprint: 'obsolete_h1',
      );
      final obsoleteHabit2 = ArcNotificationSpec(
        id: NotificationPolicy.habitRemTimeMin + 20,
        type: ArcNotificationType.habitPending,
        channel: ArcNotificationChannel.habits,
        entityId: 'h2',
        title: 'Habit still pending',
        body: 'Do h2',
        scheduledAt: DateTime(2026, 10, 26, 21),
        recurrence: ArcNotificationRecurrence.daily,
        fingerprint: 'obsolete_h2',
      );
      final validTask = ArcNotificationSpec(
        id: NotificationPolicy.taskDeadlineMin + 50,
        type: ArcNotificationType.taskDeadline,
        channel: ArcNotificationChannel.tasks,
        entityId: 'task_important',
        title: 'Task deadline',
        body: 'Submit tax files',
        scheduledAt: DateTime(2026, 10, 26, 17),
        recurrence: ArcNotificationRecurrence.none,
        fingerprint: 'task_important_deadline',
      );
      final validMoney = ArcNotificationSpec(
        id: NotificationPolicy.moneyReminderId,
        type: ArcNotificationType.moneyDaily,
        channel: ArcNotificationChannel.money,
        entityId: 'daily_money',
        title: "Update today's spending",
        body: "Don't forget to add today's expenses to Arc.",
        scheduledAt: DateTime(2026, 10, 26, 21),
        recurrence: ArcNotificationRecurrence.daily,
        fingerprint: 'money_daily',
      );

      await gateway.schedule(obsoleteHabit1);
      await gateway.schedule(obsoleteHabit2);
      await gateway.schedule(validTask);
      await gateway.schedule(validMoney);
      expect(gateway.pending.length, equals(4));

      // Run migration
      final cancelledCount = await controller.migrateObsoleteSchedules(boxOverride: fakeBox);
      expect(cancelledCount, equals(2));

      // Obsolete notifications removed
      expect(gateway.pending.containsKey(obsoleteHabit1.id), isFalse);
      expect(gateway.pending.containsKey(obsoleteHabit2.id), isFalse);

      // Unrelated notifications preserved
      expect(gateway.pending.containsKey(validTask.id), isTrue);
      expect(gateway.pending.containsKey(validMoney.id), isTrue);
      expect(gateway.pending.length, equals(2));

      // Migration flag recorded to prevent repeated execution
      expect(fakeBox.get('migrated_consolidated_habit_notifications_v1'), isTrue);

      controller.dispose();
    });

    // 7. Money reminder scheduling remains functional
    test('Requirement 7: Money reminder schedules daily and advances if transaction recorded today', () {
      final now = DateTime(2026, 10, 26, 10, 0);

      // No transactions today
      final snapshotNoTx = createSnapshot(
        now: now,
        settings: SettingsModel.defaultSettings().copyWith(remTime: '21:00'),
        transactions: [],
      );
      final specs1 = policy.build(snapshotNoTx);
      final moneySpec = specs1.firstWhere((s) => s.channel == ArcNotificationChannel.money);
      expect(moneySpec.id, equals(NotificationPolicy.moneyReminderId));
      expect(moneySpec.title, equals("Update today's spending"));
      expect(moneySpec.body, equals("Don't forget to add today's expenses to Arc."));
      expect(moneySpec.scheduledAt.day, equals(26)); // Scheduled today at 21:00

      // Transaction recorded today -> advances to tomorrow
      final txToday = Transaction(
        id: 'tx1',
        amount: 25.0,
        type: 'expense',
        category: 'Food',
        date: DateTime(2026, 10, 26),
        time: '11:00',
        notes: 'Groceries',
        createdAt: DateTime(2026, 10, 26, 11, 0),
      );
      final snapshotWithTx = createSnapshot(
        now: now,
        settings: SettingsModel.defaultSettings().copyWith(remTime: '21:00'),
        transactions: [txToday],
      );
      final specs2 = policy.build(snapshotWithTx);
      final moneySpecTomorrow = specs2.firstWhere((s) => s.channel == ArcNotificationChannel.money);
      expect(moneySpecTomorrow.scheduledAt.day, equals(27)); // Advanced to tomorrow
    });

    // 8. Multiple legitimate task deadlines are preserved
    test('Requirement 8: Multiple legitimate tasks receive independent non-colliding deadline alerts', () {
      final now = DateTime(2026, 10, 26, 10, 0);
      final List<Task> tasks = [
        Task(
          id: 'task_alpha',
          title: 'Morning Sync',
          description: 'Sync notes',
          category: 'Work',
          priority: 'High',
          labels: const [],
          dueDate: DateTime(2026, 10, 26),
          dueTime: '11:00',
          completed: false,
          createdAt: now,
          updatedAt: now,
        ),
        Task(
          id: 'task_beta',
          title: 'Code Review',
          description: 'Review PR',
          category: 'Work',
          priority: 'Medium',
          labels: const [],
          dueDate: DateTime(2026, 10, 26),
          dueTime: '15:00',
          completed: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final snapshot = createSnapshot(now: now, tasks: tasks);
      final specs = policy.build(snapshot);

      final taskSpecs = specs.where((s) => s.channel == ArcNotificationChannel.tasks).toList();
      // Each task gets pre-deadline (5m before) + deadline = 4 specs total
      expect(taskSpecs.length, equals(4));

      final alphaDeadline = taskSpecs.firstWhere(
        (s) => s.entityId == 'task_alpha' && s.type == ArcNotificationType.taskDeadline,
      );
      final betaDeadline = taskSpecs.firstWhere(
        (s) => s.entityId == 'task_beta' && s.type == ArcNotificationType.taskDeadline,
      );

      // Verify distinct IDs
      expect(alphaDeadline.id, isNot(equals(betaDeadline.id)));
      expect(alphaDeadline.scheduledAt, equals(DateTime(2026, 10, 26, 11, 0)));
      expect(betaDeadline.scheduledAt, equals(DateTime(2026, 10, 26, 15, 0)));
    });

    // 9. Duplicate task alerts are prevented
    test('Requirement 9: Duplicate alerts for the same task and deadline are prevented', () async {
      final controller = NotificationController(gateway: gateway, policy: policy);
      await controller.initialize();

      final now = DateTime(2026, 10, 26, 10, 0);
      final task = Task(
        id: 'task_single',
        title: 'Submit Expense Report',
        description: 'Submit monthly report',
        category: 'Work',
        priority: 'High',
        labels: const [],
        dueDate: DateTime(2026, 10, 26),
        dueTime: '16:00',
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      final snapshot = createSnapshot(now: now, tasks: [task]);

      await controller.reconcile(snapshot, reason: 'run_1');
      final firstScheduled = controller.state.scheduledCount;
      expect(firstScheduled, greaterThan(0));

      await controller.reconcile(snapshot, reason: 'run_2');
      // No duplicate schedule
      expect(controller.state.scheduledCount, equals(0));
      expect(controller.state.unchangedCount, equals(firstScheduled));

      controller.dispose();
    });
  });

  group('PROJECT ARC — NOTIFICATION DEEP-LINK & NAVIGATION TESTS (Requirements 10 - 18)', () {
    late TestUserNotifier testUserNotifier;
    late GoRouter testRouter;

    Widget createTestApp({
      required GoRouter router,
      required TestNotificationGateway gateway,
      required TestUserNotifier userNotifier,
    }) {
      return ProviderScope(
        overrides: [
          userContextProvider.overrideWith((ref) => userNotifier),
          notificationControllerProvider.overrideWith(
            (ref) => NotificationController(gateway: gateway, policy: policy),
          ),
          routerProvider.overrideWithValue(router),
          taskRepositoryProvider.overrideWithValue(MockTaskRepo()),
          habitRepositoryProvider.overrideWithValue(MockHabitRepo()),
          moneyRepositoryProvider.overrideWithValue(MockMoneyRepo()),
          settingsRepositoryProvider.overrideWithValue(MockSettingsRepo()),
          appSettingsProvider.overrideWith((ref) => SettingsNotifier(MockSettingsRepo())),
          currentUserFeedbackStreamProvider.overrideWith((ref) => Stream.value(const [])),
          feedbackAcknowledgementServiceProvider.overrideWithValue(MockFeedbackAckService()),
        ],
        child: NotificationOrchestrator(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
    }

    setUp(() {
      testUserNotifier = TestUserNotifier();
      testUserNotifier.setUser('user_alice', 'Alice');

      testRouter = GoRouter(
        initialLocation: '/',
        routes: [
          ShellRoute(
            builder: (context, state, child) => ShellScreen(location: state.uri.path, child: child),
            routes: [
              GoRoute(path: '/', builder: (_, _) => const TestDashboardScreen()),
              GoRoute(
                path: '/tasks',
                builder: (context, state) => TestTasksScreen(initialTaskId: state.uri.queryParameters['taskId']),
              ),
              GoRoute(path: '/habits', builder: (_, _) => const TestHabitsScreen()),
              GoRoute(path: '/money', builder: (_, _) => const TestMoneyScreen()),
            ],
          ),
          GoRoute(path: '/settings', builder: (_, _) => const Scaffold(body: Text('Settings Screen'))),
          GoRoute(path: '/feedback/my-feedback', builder: (_, _) => const TestMyFeedbackScreen()),
          GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('Login Screen'))),
        ],
      );
    });

    // 10. Habit notification opens Habit Tracker
    testWidgets('Requirement 10: Tapping habit notification navigates directly to Habit Tracker (/habits)', (tester) async {
      await tester.pumpWidget(createTestApp(
        router: testRouter,
        gateway: gateway,
        userNotifier: testUserNotifier,
      ));
      await tester.pumpAndSettle();

      // Initially at Dashboard
      expect(find.byType(TestDashboardScreen), findsOneWidget);

      // Simulate tapping Habit check-in notification
      gateway.simulateTap(const ArcNotificationPayload(
        type: ArcNotificationType.habitEveningCheckIn,
        entityId: 'daily_habit_checkin',
        fingerprint: 'habits_daily',
      ));
      await tester.pumpAndSettle();

      // Navigated to HabitsScreen
      expect(find.byType(TestHabitsScreen), findsOneWidget);
    });

    // 11. Money notification opens Money Manager
    testWidgets('Requirement 11: Tapping money notification navigates directly to Money Manager (/money)', (tester) async {
      await tester.pumpWidget(createTestApp(
        router: testRouter,
        gateway: gateway,
        userNotifier: testUserNotifier,
      ));
      await tester.pumpAndSettle();

      gateway.simulateTap(const ArcNotificationPayload(
        type: ArcNotificationType.moneyDaily,
        entityId: 'daily_money',
        fingerprint: 'money_daily',
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TestMoneyScreen), findsOneWidget);
    });

    // 12. Task notification opens Tasks screen with relevant task details
    testWidgets('Requirement 12: Tapping task notification navigates to Tasks screen (/tasks)', (tester) async {
      await tester.pumpWidget(createTestApp(
        router: testRouter,
        gateway: gateway,
        userNotifier: testUserNotifier,
      ));
      await tester.pumpAndSettle();

      gateway.simulateTap(const ArcNotificationPayload(
        type: ArcNotificationType.taskDeadline,
        entityId: 'task_abc',
        fingerprint: 'task_abc_deadline',
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TestTasksScreen), findsOneWidget);
      expect(find.text('Tasks Screen: task_abc'), findsOneWidget);
    });

    // 13. Feedback notification opens My Feedback
    testWidgets('Requirement 13: Tapping feedback notification navigates to My Feedback (/feedback/my-feedback)', (tester) async {
      await tester.pumpWidget(createTestApp(
        router: testRouter,
        gateway: gateway,
        userNotifier: testUserNotifier,
      ));
      await tester.pumpAndSettle();

      gateway.simulateTap(const ArcNotificationPayload(
        type: ArcNotificationType.feedbackAcknowledged,
        entityId: 'fb_ticket_99',
        fingerprint: 'feedback_ack',
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TestMyFeedbackScreen), findsOneWidget);
    });

    // 14. Notification navigation works from foreground and background
    testWidgets('Requirement 14: Notification navigation functions correctly in foreground and app resume', (tester) async {
      await tester.pumpWidget(createTestApp(
        router: testRouter,
        gateway: gateway,
        userNotifier: testUserNotifier,
      ));
      await tester.pumpAndSettle();

      // 1. Foreground navigation
      gateway.simulateTap(const ArcNotificationPayload(
        type: ArcNotificationType.habitEveningCheckIn,
        entityId: 'daily_habit_checkin',
        fingerprint: 'habits_daily',
      ));
      await tester.pumpAndSettle();
      expect(find.byType(TestHabitsScreen), findsOneWidget);

      // Return to home
      testRouter.go('/');
      await tester.pumpAndSettle();

      // 2. Background / resume simulation
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      gateway.simulateTap(const ArcNotificationPayload(
        type: ArcNotificationType.moneyDaily,
        entityId: 'daily_money',
        fingerprint: 'money_daily',
      ));
      await tester.pumpAndSettle();
      expect(find.byType(TestMoneyScreen), findsOneWidget);
    });

    // 15. Cold-start navigation works correctly
    testWidgets('Requirement 15: Cold-start launch defers navigation until auth session resolves, then navigates', (tester) async {
      // Setup launch payload before initialize
      gateway.launchPayload = const ArcNotificationPayload(
        type: ArcNotificationType.habitEveningCheckIn,
        entityId: 'daily_habit_checkin',
        fingerprint: 'habits_daily',
      );

      // App starts in initializing state
      testUserNotifier.setInitializing();

      await tester.pumpWidget(createTestApp(
        router: testRouter,
        gateway: gateway,
        userNotifier: testUserNotifier,
      ));
      await tester.pump(); // Frame while initializing

      // Navigation has not completed yet while initializing
      expect(find.byType(TestHabitsScreen), findsNothing);

      // Auth resolves
      testUserNotifier.setUser('user_alice', 'Alice');
      await tester.pumpAndSettle();

      // Now successfully navigated to HabitsScreen
      expect(find.byType(TestHabitsScreen), findsOneWidget);
    });

    // 16. Logged-out users are routed through authentication
    testWidgets('Requirement 16: Logged-out user preserves pending intent and navigates after login', (tester) async {
      testUserNotifier.setLoggedOut();

      await tester.pumpWidget(createTestApp(
        router: testRouter,
        gateway: gateway,
        userNotifier: testUserNotifier,
      ));
      await tester.pumpAndSettle();

      // Router redirects to login screen
      testRouter.go('/login');
      await tester.pumpAndSettle();
      expect(find.text('Login Screen'), findsOneWidget);

      // User taps notification while logged out
      gateway.simulateTap(const ArcNotificationPayload(
        type: ArcNotificationType.moneyDaily,
        entityId: 'daily_money',
        fingerprint: 'money_daily',
      ));
      await tester.pump();

      // Now user logs in successfully
      testUserNotifier.setUser('user_alice', 'Alice');
      await tester.pumpAndSettle();

      // Pending intent is fulfilled: routed to MoneyScreen
      expect(find.byType(TestMoneyScreen), findsOneWidget);
    });

    // 17. Account switching does not expose another user's information
    testWidgets('Requirement 17: Switching accounts clears pending navigation intent to prevent cross-account exposure', (tester) async {
      testUserNotifier.setUser('user_alice', 'Alice');

      await tester.pumpWidget(createTestApp(
        router: testRouter,
        gateway: gateway,
        userNotifier: testUserNotifier,
      ));
      await tester.pumpAndSettle();

      // Alice receives notification intent
      gateway.simulateTap(const ArcNotificationPayload(
        type: ArcNotificationType.feedbackAcknowledged,
        entityId: 'alice_secret_fb',
        fingerprint: 'feedback_alice',
      ));

      // Before navigating, account is switched to Bob
      testUserNotifier.setUser('user_bob', 'Bob');
      await tester.pumpAndSettle();

      // Intent cleared: Bob remains on Dashboard, Alice's feedback is not shown
      expect(find.byType(TestMyFeedbackScreen), findsNothing);
      expect(find.byType(TestDashboardScreen), findsOneWidget);
    });

    // 18. Back navigation works correctly
    testWidgets('Requirement 18: System back on tab screen opened via notification falls back to Dashboard rather than exiting', (tester) async {
      await tester.pumpWidget(createTestApp(
        router: testRouter,
        gateway: gateway,
        userNotifier: testUserNotifier,
      ));
      await tester.pumpAndSettle();

      // Notification opens Habits tab directly
      gateway.simulateTap(const ArcNotificationPayload(
        type: ArcNotificationType.habitEveningCheckIn,
        entityId: 'daily_habit_checkin',
        fingerprint: 'habits_daily',
      ));
      await tester.pumpAndSettle();
      expect(find.byType(TestHabitsScreen), findsOneWidget);

      // Press Android system back button
      final didPop = await tester.binding.handlePopRoute();
      expect(didPop, isTrue);
      await tester.pumpAndSettle();

      // Gracefully returns to Dashboard without closing app!
      expect(find.byType(TestDashboardScreen), findsOneWidget);
      expect(find.byType(TestHabitsScreen), findsNothing);
    });
  });
}
