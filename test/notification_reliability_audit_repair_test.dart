import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:arc/core/notifications/notification_service.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Track simulated platform method channel calls
  final List<MethodCall> channelCalls = [];

  int? extractCancelId(MethodCall call) {
    if (call.arguments is int) return call.arguments as int;
    if (call.arguments is Map) {
      final map = call.arguments as Map;
      if (map['id'] is int) return map['id'] as int;
    }
    return null;
  }

  setUpAll(() {
    tz.initializeTimeZones();
    const MethodChannel channel =
        MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      channelCalls.add(call);
      if (call.method == 'initialize') return true;
      if (call.method == 'requestNotificationsPermission') return true;
      if (call.method == 'requestExactAlarmsPermission') return true;
      if (call.method == 'canScheduleExactNotifications') return true;
      if (call.method == 'areNotificationsEnabled') return true;
      return null;
    });
  });

  setUp(() {
    channelCalls.clear();
  });

  group('Step 7 — Deterministic Notification IDs & Collision Immunity', () {
    final service = NotificationService();

    test('Fixed system IDs are strictly in fixed range < 1,000,000', () {
      expect(NotificationService.eveningHabitReminderId, lessThan(1000000));
      expect(NotificationService.moneyReminderEarlyId, lessThan(1000000));
      expect(NotificationService.moneyReminderLateId, lessThan(1000000));
    });

    test('Task and Habit notification IDs are strictly disjoint and mathematically separated', () {
      const sampleIds = ['uuid_1', 'abc', '123', 'same_id_for_both', 'task_1', 'habit_1'];

      for (final id in sampleIds) {
        final task5m = service.getTaskNotificationId5m(id);
        final taskDeadline = service.getTaskNotificationIdDeadline(id);
        final habitId = service.getHabitNotificationId(id);

        // Task IDs reside in [10,000,000, 810,000,000]
        expect(task5m, greaterThanOrEqualTo(10000000));
        expect(task5m, lessThan(900000000));
        expect(taskDeadline, greaterThanOrEqualTo(10000000));
        expect(taskDeadline, lessThan(900000000));

        // Habit IDs reside in [1,000,000,000, 1,400,000,000]
        expect(habitId, greaterThanOrEqualTo(1000000000));
        expect(habitId, lessThan(1500000000));

        // Zero collision between task notifications and habit notifications
        expect(task5m, isNot(equals(habitId)));
        expect(taskDeadline, isNot(equals(habitId)));
        expect(task5m, isNot(equals(taskDeadline)));

        // Zero collision with fixed system reminder IDs
        expect(task5m, isNot(equals(NotificationService.eveningHabitReminderId)));
        expect(habitId, isNot(equals(NotificationService.eveningHabitReminderId)));
      }
    });

    test('Notification IDs are stable and deterministic across multiple calls', () {
      const key = 'test_item_unique_key';
      expect(service.getTaskNotificationId5m(key), equals(service.getTaskNotificationId5m(key)));
      expect(service.getTaskNotificationIdDeadline(key), equals(service.getTaskNotificationIdDeadline(key)));
      expect(service.getHabitNotificationId(key), equals(service.getHabitNotificationId(key)));
    });
  });

  group('Step 6 — Dynamic Timezone Resolution', () {
    test('Configures a valid Olson timezone location and sets local location', () async {
      final service = NotificationService();
      await service.init();

      expect(tz.local, isNotNull);
      expect(tz.local.name.isNotEmpty, isTrue);
      expect(tz.local.name, isNot(equals('UTC_INVALID')));
    });
  });

  group('Step 8 — Task Reminder Scheduling, Editing & Cancellation', () {
    final service = NotificationService();

    test('Active future task schedules 5m and deadline alerts', () async {
      final futureDate = DateTime.now().add(const Duration(days: 2));
      final task = Task(
        id: 'task_lifecycle_1',
        title: 'Submit Quarterly Report',
        description: 'Complete finance audit and submit to board',
        priority: 'High',
        category: 'Work',
        labels: ['Finance'],
        dueDate: futureDate,
        dueTime: '15:30',
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await service.scheduleTaskReminders(task);

      final scheduledCalls = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduledCalls.length, equals(2));

      // Verify payload correctly specifies task type and id
      final callPayload = scheduledCalls.first.arguments['payload'] as String;
      final decoded = jsonDecode(callPayload) as Map<String, dynamic>;
      expect(decoded['type'], equals('task'));
      expect(decoded['id'], equals('task_lifecycle_1'));
    });

    test('Completed task cancels reminders and does not schedule new ones', () async {
      channelCalls.clear();
      final task = Task(
        id: 'task_lifecycle_2',
        title: 'Completed Task',
        description: '',
        priority: 'Low',
        category: 'Personal',
        labels: [],
        dueDate: DateTime.now().add(const Duration(days: 1)),
        dueTime: '12:00',
        completed: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await service.scheduleTaskReminders(task);

      final scheduledCalls = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduledCalls.isEmpty, isTrue);

      final cancelCalls = channelCalls.where((c) => c.method == 'cancel').toList();
      expect(cancelCalls.isNotEmpty, isTrue);
    });

    test('Deleting a task explicitly cancels all task reminders', () async {
      channelCalls.clear();
      await service.cancelTaskReminders('task_deleted_99');

      final cancelCalls = channelCalls.where((c) => c.method == 'cancel').toList();
      expect(cancelCalls.length, greaterThanOrEqualTo(2));
      final canceledIds = cancelCalls.map(extractCancelId).whereType<int>().toSet();
      expect(canceledIds.contains(service.getTaskNotificationId5m('task_deleted_99')), isTrue);
      expect(canceledIds.contains(service.getTaskNotificationIdDeadline('task_deleted_99')), isTrue);
    });

    test('Editing task cancels previous reminders to prevent duplicates', () async {
      final taskInitial = Task(
        id: 'task_edit_dup',
        title: 'Original Task',
        description: '',
        priority: 'Must',
        category: 'Work',
        labels: [],
        dueDate: DateTime.now().add(const Duration(days: 1)),
        dueTime: '10:00',
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Schedule first time
      channelCalls.clear();
      await service.scheduleTaskReminders(taskInitial);

      // Edit reminder time
      final taskEdited = taskInitial.copyWith(dueTime: '11:00');
      channelCalls.clear();
      await service.scheduleTaskReminders(taskEdited);

      // Must cancel existing before scheduling updated
      final firstCall = channelCalls.first;
      expect(firstCall.method, equals('cancel'));
    });
  });

  group('Step 9 — Habit Reminder Scheduling, Editing & Cancellation', () {
    final service = NotificationService();

    test('Habit with reminderTime schedules daily recurring reminder', () async {
      channelCalls.clear();
      final habit = Habit(
        id: 'habit_run_01',
        name: 'Morning Jog',
        category: 'Health',
        colorValue: 0xFF4CAF50,
        reminderTime: '07:30',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await service.scheduleHabitReminder(habit);

      final scheduled = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduled.length, equals(1));
      expect(scheduled.first.arguments['id'], equals(service.getHabitNotificationId('habit_run_01')));

      final payload = jsonDecode(scheduled.first.arguments['payload'] as String);
      expect(payload['type'], equals('habit'));
      expect(payload['id'], equals('habit_run_01'));
      expect(scheduled.first.arguments['matchDateTimeComponents'], equals(DateTimeComponents.time.index));
    });

    test('Habit without reminderTime cancels scheduled habit reminder', () async {
      channelCalls.clear();
      final habitNoReminder = Habit(
        id: 'habit_no_rem',
        name: 'Drink Water',
        category: 'Health',
        colorValue: 0xFF2196F3,
        reminderTime: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await service.scheduleHabitReminder(habitNoReminder);

      final scheduled = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduled.isEmpty, isTrue);

      final cancelCalls = channelCalls.where((c) => c.method == 'cancel').toList();
      final canceledIds = cancelCalls.map(extractCancelId).whereType<int>().toSet();
      expect(canceledIds.contains(service.getHabitNotificationId('habit_no_rem')), isTrue);
    });

    test('Deleting habit explicitly cancels its reminder', () async {
      channelCalls.clear();
      await service.cancelHabitReminder('habit_delete_01');

      final cancelCalls = channelCalls.where((c) => c.method == 'cancel').toList();
      final canceledIds = cancelCalls.map(extractCancelId).whereType<int>().toSet();
      expect(canceledIds.contains(service.getHabitNotificationId('habit_delete_01')), isTrue);
    });
  });

  group('Step 13 — Notification Reconciliation', () {
    final service = NotificationService();

    test('Reconciles mixed task and habit lists: cancels completed/past, schedules active future', () async {
      final now = DateTime.now();

      final activeTask = Task(
        id: 'reconcile_active_task',
        title: 'Active Future Task',
        description: '',
        priority: 'High',
        category: 'Work',
        labels: [],
        dueDate: now.add(const Duration(days: 3)),
        dueTime: '14:00',
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      final completedTask = Task(
        id: 'reconcile_completed_task',
        title: 'Done Task',
        description: '',
        priority: 'Low',
        category: 'Personal',
        labels: [],
        dueDate: now.add(const Duration(days: 1)),
        dueTime: '12:00',
        completed: true,
        createdAt: now,
        updatedAt: now,
      );

      final activeHabit = Habit(
        id: 'reconcile_habit_active',
        name: 'Meditation',
        category: 'Mindfulness',
        colorValue: 0xFF9C27B0,
        reminderTime: '21:00',
        createdAt: now,
        updatedAt: now,
      );

      final inactiveHabit = Habit(
        id: 'reconcile_habit_inactive',
        name: 'Reading',
        category: 'Personal',
        colorValue: 0xFFFF9800,
        reminderTime: null,
        createdAt: now,
        updatedAt: now,
      );

      channelCalls.clear();
      await service.reconcileScheduledNotifications(
        tasks: [activeTask, completedTask],
        habits: [activeHabit, inactiveHabit],
        hasTodayTx: false,
      );

      final scheduled = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      final scheduledIds = scheduled.map((c) => c.arguments['id'] as int).toSet();

      // Active task and active habit should be scheduled
      expect(scheduledIds.contains(service.getTaskNotificationId5m(activeTask.id)), isTrue);
      expect(scheduledIds.contains(service.getTaskNotificationIdDeadline(activeTask.id)), isTrue);
      expect(scheduledIds.contains(service.getHabitNotificationId(activeHabit.id)), isTrue);

      // Completed task and inactive habit should NOT be scheduled
      expect(scheduledIds.contains(service.getTaskNotificationId5m(completedTask.id)), isFalse);
      expect(scheduledIds.contains(service.getHabitNotificationId(inactiveHabit.id)), isFalse);
    });
  });

  group('Step 14 & 15 — Auth Lifecycle & User Isolation', () {
    final service = NotificationService();

    test('cancelAllUserNotifications cancels all active notifications on logout', () async {
      channelCalls.clear();
      await service.cancelAllUserNotifications();

      expect(channelCalls.any((c) => c.method == 'cancelAll'), isTrue);
    });

    test('User Switch: User A logout clears all notifications; User B login reconciles only User B data', () async {
      final now = DateTime.now();

      // User A data
      final userATask = Task(
        id: 'user_a_task_1',
        title: 'User A Task',
        description: '',
        priority: 'High',
        category: 'Work',
        labels: [],
        dueDate: now.add(const Duration(days: 1)),
        dueTime: '10:00',
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      // 1. User A is active
      channelCalls.clear();
      await service.scheduleTaskReminders(userATask);
      expect(channelCalls.any((c) => c.method == 'zonedSchedule'), isTrue);

      // 2. User A logs out
      channelCalls.clear();
      await service.cancelAllUserNotifications();
      expect(channelCalls.any((c) => c.method == 'cancelAll'), isTrue);

      // 3. User B logs in with their own task
      final userBTask = Task(
        id: 'user_b_task_1',
        title: 'User B Task',
        description: '',
        priority: 'Low',
        category: 'Personal',
        labels: [],
        dueDate: now.add(const Duration(days: 2)),
        dueTime: '15:00',
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      channelCalls.clear();
      await service.reconcileScheduledNotifications(
        tasks: [userBTask],
        habits: [],
        hasTodayTx: true,
      );

      final scheduledIds = channelCalls
          .where((c) => c.method == 'zonedSchedule')
          .map((c) => c.arguments['id'] as int)
          .toSet();

      // User B's task notifications are scheduled
      expect(scheduledIds.contains(service.getTaskNotificationId5m(userBTask.id)), isTrue);
      // User A's task notifications are NOT scheduled
      expect(scheduledIds.contains(service.getTaskNotificationId5m(userATask.id)), isFalse);
    });
  });

  group('Step 20 — Permission & Status Methods', () {
    final service = NotificationService();

    test('requestPermissions and areNotificationsEnabled complete safely without throwing', () async {
      final granted = await service.requestPermissions();
      expect(granted, isTrue);

      final enabled = await service.areNotificationsEnabled();
      expect(enabled, isTrue);
    });
  });
}
