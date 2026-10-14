import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:arc/core/notifications/notification_service.dart';
import 'package:arc/core/notifications/notification_reconciler.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/settings/models/settings_model.dart';

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

  (String, String) getSafeFutureTimesToday() {
    final now = DateTime.now();
    final deadline = now.hour == 23 && now.minute >= 55
        ? DateTime(now.year, now.month, now.day, 23, 58)
        : now.add(const Duration(minutes: 2));
    final remTime = now.hour == 23 && now.minute >= 55
        ? DateTime(now.year, now.month, now.day, 23, 59)
        : now.add(const Duration(minutes: 4));
    return (
      DateFormat('HH:mm').format(deadline),
      DateFormat('HH:mm').format(remTime),
    );
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

  group('Section 8 — Deterministic Notification IDs & Collision Immunity', () {
    final service = NotificationService();

    test('Fixed system IDs are strictly in fixed range < 1,000,000', () {
      expect(NotificationService.moneyReminderId, equals(888888));
      expect(NotificationService.moneyReminderId, lessThan(1000000));
      expect(NotificationService.eveningHabitReminderId, lessThan(1000000));
      expect(NotificationService.moneyReminderEarlyId, lessThan(1000000));
      expect(NotificationService.moneyReminderLateId, lessThan(1000000));
    });

    test('Task and Habit notification IDs are strictly disjoint and mathematically separated', () {
      const sampleIds = ['uuid_1', 'abc', '123', 'same_id_for_both', 'task_1', 'habit_1'];

      for (final id in sampleIds) {
        final task5m = service.getTaskNotificationId5m(id);
        final taskDeadline = service.getTaskNotificationIdDeadline(id);
        final habitDeadline = service.getHabitNotificationIdDeadline(id);
        final habitRemTime = service.getHabitNotificationIdRemTime(id);

        // Task pre-deadline IDs reside in [10,000,000, 399,999,999]
        expect(task5m, greaterThanOrEqualTo(10000000));
        expect(task5m, lessThanOrEqualTo(399999999));

        // Task deadline IDs reside in [400,000,000, 799,999,999]
        expect(taskDeadline, greaterThanOrEqualTo(400000000));
        expect(taskDeadline, lessThanOrEqualTo(799999999));

        // Habit deadline IDs reside in [800,000,000, 1,099,999,999]
        expect(habitDeadline, greaterThanOrEqualTo(800000000));
        expect(habitDeadline, lessThanOrEqualTo(1099999999));

        // Habit rem_time IDs reside in [1,100,000,000, 1,399,999,999]
        expect(habitRemTime, greaterThanOrEqualTo(1100000000));
        expect(habitRemTime, lessThanOrEqualTo(1399999999));

        // Zero collision between task notifications and habit notifications
        expect(task5m, isNot(equals(habitDeadline)));
        expect(taskDeadline, isNot(equals(habitDeadline)));
        expect(task5m, isNot(equals(taskDeadline)));
        expect(habitDeadline, isNot(equals(habitRemTime)));

        // Zero collision with fixed system reminder IDs
        expect(task5m, isNot(equals(NotificationService.moneyReminderId)));
        expect(habitDeadline, isNot(equals(NotificationService.moneyReminderId)));
      }
    });

    test('Notification IDs are stable and deterministic across multiple calls', () {
      const key = 'test_item_unique_key';
      expect(service.getTaskNotificationId5m(key), equals(service.getTaskNotificationId5m(key)));
      expect(service.getTaskNotificationIdDeadline(key), equals(service.getTaskNotificationIdDeadline(key)));
      expect(service.getHabitNotificationIdDeadline(key), equals(service.getHabitNotificationIdDeadline(key)));
      expect(service.getHabitNotificationIdRemTime(key), equals(service.getHabitNotificationIdRemTime(key)));
    });
  });

  group('Dynamic Timezone Resolution', () {
    test('Configures a valid Olson timezone location and sets local location', () async {
      final service = NotificationService();
      await service.init();

      expect(tz.local, isNotNull);
      expect(tz.local.name.isNotEmpty, isTrue);
      expect(tz.local.name, isNot(equals('UTC_INVALID')));
    });
  });

  group('Task Manager Notifications — Exact Business Rules', () {
    final service = NotificationService();

    test('Active future task schedules exactly two notifications with exact titles and bodies', () async {
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

      // Notification 1: Five-minute warning
      final notif5m = scheduledCalls.firstWhere(
        (c) => c.arguments['id'] == service.getTaskNotificationId5m('task_lifecycle_1'),
      );
      expect(notif5m.arguments['title'], equals('Task due soon'));
      expect(notif5m.arguments['body'], equals('Submit Quarterly Report is due in 5 minutes.'));

      // Notification 2: Deadline reached
      final notifDeadline = scheduledCalls.firstWhere(
        (c) => c.arguments['id'] == service.getTaskNotificationIdDeadline('task_lifecycle_1'),
      );
      expect(notifDeadline.arguments['title'], equals('Task deadline reached'));
      expect(notifDeadline.arguments['body'], equals('Submit Quarterly Report is due now.'));

      // Verify payload correctly specifies task type and id
      final callPayload = notif5m.arguments['payload'] as String;
      final decoded = jsonDecode(callPayload) as Map<String, dynamic>;
      expect(decoded['type'], equals('task'));
      expect(decoded['id'], equals('task_lifecycle_1'));
    });

    test('Task created less than 5 minutes before deadline schedules only deadline notification', () async {
      channelCalls.clear();
      final now = DateTime.now();
      // Deadline in 3 minutes
      final dueTimeToday = now.add(const Duration(minutes: 3));
      final taskNearDeadline = Task(
        id: 'task_near_deadline',
        title: 'Emergency Hotfix',
        description: 'Deploy hotfix immediately',
        priority: 'High',
        category: 'Work',
        labels: [],
        dueDate: dueTimeToday,
        dueTime: DateFormat('HH:mm').format(dueTimeToday),
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      await service.scheduleTaskReminders(taskNearDeadline);

      final scheduledCalls = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      // Only deadline alert scheduled; 5m warning is suppressed because it falls in the past
      expect(scheduledCalls.length, equals(1));
      expect(scheduledCalls.first.arguments['id'], equals(service.getTaskNotificationIdDeadline('task_near_deadline')));
      expect(scheduledCalls.first.arguments['title'], equals('Task deadline reached'));
      expect(scheduledCalls.first.arguments['body'], equals('Emergency Hotfix is due now.'));
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

  group('Habit Manager Notifications — Exact Business Rules', () {
    final service = NotificationService();

    test('Incomplete habit with future deadline and future rem_time schedules both notifications', () async {
      channelCalls.clear();
      final habit = Habit(
        id: 'habit_run_01',
        name: 'Evening Jog',
        category: 'Health',
        colorValue: 0xFF4CAF50,
        reminderTime: '22:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Use safe future times for today's tests that won't wrap past midnight
      final (deadlineStr, remTimeStr) = getSafeFutureTimesToday();

      final testHabit = habit.copyWith(reminderTime: deadlineStr);

      await service.scheduleHabitReminders(
        habit: testHabit,
        completedToday: false,
        remTime: remTimeStr,
      );

      final scheduled = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduled.length, equals(2));

      // Notification 1: Habit Deadline
      final deadlineCall = scheduled.firstWhere(
        (c) => c.arguments['id'] == service.getHabitNotificationIdDeadline('habit_run_01'),
      );
      expect(deadlineCall.arguments['title'], equals('Habit reminder'));
      expect(deadlineCall.arguments['body'], equals('Time to complete: Evening Jog'));

      // Notification 2: Global Reminder Time (Pending)
      final remTimeCall = scheduled.firstWhere(
        (c) => c.arguments['id'] == service.getHabitNotificationIdRemTime('habit_run_01'),
      );
      expect(remTimeCall.arguments['title'], equals('Habit still pending'));
      expect(remTimeCall.arguments['body'], equals("You haven't completed Evening Jog today."));
    });

    test('Habit completed today suppresses BOTH deadline and rem_time notifications', () async {
      channelCalls.clear();
      final now = DateTime.now();
      final (deadlineStr, remTimeStr) = getSafeFutureTimesToday();

      final habit = Habit(
        id: 'habit_completed_today',
        name: 'Drink Water',
        category: 'Health',
        colorValue: 0xFF2196F3,
        reminderTime: deadlineStr,
        createdAt: now,
        updatedAt: now,
      );

      await service.scheduleHabitReminders(
        habit: habit,
        completedToday: true, // Marked completed today!
        remTime: remTimeStr,
      );

      final scheduled = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      // Neither notification should be scheduled
      expect(scheduled.isEmpty, isTrue);

      // Pre-existing notifications are cancelled
      final cancelCalls = channelCalls.where((c) => c.method == 'cancel').toList();
      expect(cancelCalls.isNotEmpty, isTrue);
    });

    test('Habit without reminderTime schedules only pending rem_time notification', () async {
      channelCalls.clear();
      final now = DateTime.now();
      final (_, remTimeStr) = getSafeFutureTimesToday();

      final habitNoReminder = Habit(
        id: 'habit_no_rem',
        name: 'Read Book',
        category: 'Leisure',
        colorValue: 0xFF9C27B0,
        reminderTime: null,
        createdAt: now,
        updatedAt: now,
      );

      await service.scheduleHabitReminders(
        habit: habitNoReminder,
        completedToday: false,
        remTime: remTimeStr,
      );

      final scheduled = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduled.length, equals(1));
      expect(scheduled.first.arguments['id'], equals(service.getHabitNotificationIdRemTime('habit_no_rem')));
      expect(scheduled.first.arguments['title'], equals('Habit still pending'));
      expect(scheduled.first.arguments['body'], equals("You haven't completed Read Book today."));
    });

    test('Deleting habit explicitly cancels both deadline and rem_time notifications', () async {
      channelCalls.clear();
      await service.cancelHabitReminders('habit_delete_01');

      final cancelCalls = channelCalls.where((c) => c.method == 'cancel').toList();
      final canceledIds = cancelCalls.map(extractCancelId).whereType<int>().toSet();
      expect(canceledIds.contains(service.getHabitNotificationIdDeadline('habit_delete_01')), isTrue);
      expect(canceledIds.contains(service.getHabitNotificationIdRemTime('habit_delete_01')), isTrue);
    });
  });

  group('Money Manager Reminder — Exact Business Rules', () {
    final service = NotificationService();

    test('Schedules exactly one daily reminder at rem_time with exact title and body', () async {
      channelCalls.clear();
      await service.scheduleDailyMoneyReminder('21:00');

      final scheduled = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduled.length, equals(1));
      final call = scheduled.first;
      expect(call.arguments['id'], equals(NotificationService.moneyReminderId));
      expect(call.arguments['title'], equals("Update today's spending"));
      expect(call.arguments['body'], equals("Don't forget to add today's expenses to ARC."));
      expect(call.arguments['matchDateTimeComponents'], equals(DateTimeComponents.time.index));

      final payload = jsonDecode(call.arguments['payload'] as String);
      expect(payload['type'], equals('money'));
    });

    test('cancelMoneyReminders cancels the deterministic money reminder ID 888888', () async {
      channelCalls.clear();
      await service.cancelMoneyReminders();

      final cancelCalls = channelCalls.where((c) => c.method == 'cancel').toList();
      final canceledIds = cancelCalls.map(extractCancelId).whereType<int>().toSet();
      expect(canceledIds.contains(NotificationService.moneyReminderId), isTrue);
    });
  });

  group('NotificationReconciler — Lifecycle & Global rem_time Operations', () {
    final service = NotificationService();
    final reconciler = NotificationReconciler(notificationService: service);

    test('onRemTimeChanged reschedules habit pending and money reminder without touching tasks', () async {
      final now = DateTime.now();
      final (futureDeadlineStr, newRemTime) = getSafeFutureTimesToday();

      final habit = Habit(
        id: 'habit_remtime_change',
        name: 'Meditation',
        category: 'Mindfulness',
        colorValue: 0xFF4CAF50,
        reminderTime: futureDeadlineStr,
        createdAt: now,
        updatedAt: now,
      );

      channelCalls.clear();
      await reconciler.onRemTimeChanged(
        newRemTime: newRemTime,
        userId: 'user_123',
        habits: [habit],
        habitEntries: [],
        settings: SettingsModel.defaultSettings().copyWith(
          remTime: '21:00',
          masterNotificationsEnabled: true,
          habitRemindersEnabled: true,
          moneyRemindersEnabled: true,
        ),
      );

      final scheduled = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      final scheduledIds = scheduled.map((c) => c.arguments['id'] as int).toSet();

      // Should schedule habit rem_time alert and money reminder
      expect(scheduledIds.contains(service.getHabitNotificationIdRemTime('habit_remtime_change')), isTrue);
      expect(scheduledIds.contains(NotificationService.moneyReminderId), isTrue);

      // Does NOT schedule or touch any task IDs
      expect(scheduledIds.any((id) => id >= 10000000 && id < 800000000), isFalse);
    });

    test('onHabitToggled: completing habit cancels its reminders; uncompleting reschedules them', () async {
      final now = DateTime.now();
      final (futureDeadlineStr, remTimeStr) = getSafeFutureTimesToday();

      final habit = Habit(
        id: 'habit_toggle_test',
        name: 'Workout',
        category: 'Fitness',
        colorValue: 0xFFE91E63,
        reminderTime: futureDeadlineStr,
        createdAt: now,
        updatedAt: now,
      );

      // 1. Toggled to complete -> cancels
      channelCalls.clear();
      await reconciler.onHabitToggled(
        habitId: habit.id,
        completed: true,
        userId: 'user_123',
        remTime: remTimeStr,
        habit: habit,
      );

      final cancelCalls = channelCalls.where((c) => c.method == 'cancel').toList();
      final canceledIds = cancelCalls.map(extractCancelId).whereType<int>().toSet();
      expect(canceledIds.contains(service.getHabitNotificationIdDeadline(habit.id)), isTrue);
      expect(canceledIds.contains(service.getHabitNotificationIdRemTime(habit.id)), isTrue);

      // 2. Toggled back to incomplete -> reschedules
      channelCalls.clear();
      await reconciler.onHabitToggled(
        habitId: habit.id,
        completed: false,
        userId: 'user_123',
        remTime: remTimeStr,
        habit: habit,
      );

      final scheduledCalls = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      final scheduledIds = scheduledCalls.map((c) => c.arguments['id'] as int).toSet();
      expect(scheduledIds.contains(service.getHabitNotificationIdDeadline(habit.id)), isTrue);
      expect(scheduledIds.contains(service.getHabitNotificationIdRemTime(habit.id)), isTrue);
    });

    test('Reconcile with masterNotificationsEnabled == false cancels all notifications', () async {
      channelCalls.clear();
      await reconciler.reconcile(
        userId: 'user_test',
        tasks: [],
        habits: [],
        habitEntries: [],
        settings: SettingsModel.defaultSettings().copyWith(masterNotificationsEnabled: false),
      );

      expect(channelCalls.any((c) => c.method == 'cancelAll'), isTrue);
    });

    test('Reconciles mixed task and habit lists: cancels completed/past, schedules active future', () async {
      final now = DateTime.now();
      final (futureDeadlineStr, futureRemTimeStr) = getSafeFutureTimesToday();

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
        reminderTime: futureDeadlineStr,
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
      await reconciler.reconcile(
        userId: 'reconcile_user',
        tasks: [activeTask, completedTask],
        habits: [activeHabit, inactiveHabit],
        habitEntries: [],
        remTime: futureRemTimeStr,
        settings: SettingsModel.defaultSettings().copyWith(
          masterNotificationsEnabled: true,
          taskRemindersEnabled: true,
          habitRemindersEnabled: true,
          moneyRemindersEnabled: true,
        ),
      );

      final scheduled = channelCalls.where((c) => c.method == 'zonedSchedule').toList();
      final scheduledIds = scheduled.map((c) => c.arguments['id'] as int).toSet();

      // Active task and active habit should be scheduled
      expect(scheduledIds.contains(service.getTaskNotificationId5m(activeTask.id)), isTrue);
      expect(scheduledIds.contains(service.getTaskNotificationIdDeadline(activeTask.id)), isTrue);
      expect(scheduledIds.contains(service.getHabitNotificationIdDeadline(activeHabit.id)), isTrue);
      expect(scheduledIds.contains(service.getHabitNotificationIdRemTime(activeHabit.id)), isTrue);

      // Completed task should NOT be scheduled
      expect(scheduledIds.contains(service.getTaskNotificationId5m(completedTask.id)), isFalse);
      expect(scheduledIds.contains(service.getTaskNotificationIdDeadline(completedTask.id)), isFalse);
    });
  });

  group('Auth Lifecycle & Multi-User Isolation', () {
    final service = NotificationService();
    final reconciler = NotificationReconciler(notificationService: service);

    test('cancelAllUserNotifications cancels all active notifications on logout', () async {
      channelCalls.clear();
      await service.cancelAllUserNotifications();

      expect(channelCalls.any((c) => c.method == 'cancelAll'), isTrue);
    });

    test('reconcile with null or empty userId purges all notifications', () async {
      channelCalls.clear();
      await reconciler.reconcile(userId: null);
      expect(channelCalls.any((c) => c.method == 'cancelAll'), isTrue);

      channelCalls.clear();
      await reconciler.reconcile(userId: '');
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
      await reconciler.reconcile(
        userId: 'user_b',
        tasks: [userBTask],
        habits: [],
        habitEntries: [],
        settings: SettingsModel.defaultSettings().copyWith(
          masterNotificationsEnabled: true,
          taskRemindersEnabled: true,
          habitRemindersEnabled: true,
          moneyRemindersEnabled: true,
        ),
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

  group('Permission & Status Methods', () {
    final service = NotificationService();

    test('requestPermissions and areNotificationsEnabled complete safely without throwing', () async {
      final granted = await service.requestPermissions();
      expect(granted, isTrue);

      final enabled = await service.areNotificationsEnabled();
      expect(enabled, isTrue);
    });
  });
}
