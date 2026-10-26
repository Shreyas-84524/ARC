import 'package:intl/intl.dart';

import 'package:arc/core/notifications/notification_models.dart';

class NotificationPolicy {
  static const int moneyReminderId = 888888;
  static const int dailyHabitCheckInId = 999999;
  static const int eveningHabitReminderId = 999999;

  static const int taskPreDeadlineMin = 10000000;
  static const int taskPreDeadlineRange = 390000000;
  static const int taskDeadlineMin = 400000000;
  static const int taskDeadlineRange = 400000000;
  static const int habitDeadlineMin = 800000000;
  static const int habitDeadlineRange = 300000000;
  static const int habitRemTimeMin = 1100000000;
  static const int habitRemTimeRange = 300000000;
  static const int feedbackNotificationMin = 1400000000;
  static const int feedbackNotificationRange = 600000000;

  List<ArcNotificationSpec> build(NotificationSnapshot snapshot) {
    final userId = snapshot.userId;
    if (userId == null ||
        userId.isEmpty ||
        !snapshot.settings.masterNotificationsEnabled) {
      return const [];
    }

    final specs = <ArcNotificationSpec>[];
    if (snapshot.settings.taskRemindersEnabled) {
      specs.addAll(_taskNotifications(snapshot));
    }
    if (snapshot.settings.habitRemindersEnabled) {
      specs.addAll(_habitNotifications(snapshot));
    }
    if (snapshot.settings.moneyRemindersEnabled) {
      final money = _moneyNotification(snapshot);
      if (money != null) specs.add(money);
    }

    specs.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return List.unmodifiable(specs);
  }

  List<ArcNotificationSpec> _taskNotifications(
    NotificationSnapshot snapshot,
  ) {
    final specs = <ArcNotificationSpec>[];
    for (final task in snapshot.tasks) {
      if (task.completed || task.dueDate == null) continue;

      DateTime? dueAt;
      if (task.dueTime != null) {
        dueAt = _dateWithTime(task.dueDate!, task.dueTime!);
      }

      // The editor persists 09:00 in Task.reminder for date-only tasks.
      final explicitReminder = task.reminder;
      if (dueAt == null) {
        if (explicitReminder != null && explicitReminder.isAfter(snapshot.now)) {
          specs.add(_oneShot(
            id: getTaskNotificationId5m(task.id),
            type: ArcNotificationType.taskReminder,
            channel: ArcNotificationChannel.tasks,
            entityId: task.id,
            title: 'Task reminder',
            body: '${task.title} is scheduled for today.',
            scheduledAt: explicitReminder,
          ));
        }
        continue;
      }

      if (!dueAt.isAfter(snapshot.now)) continue;

      final defaultPreReminder = dueAt.subtract(const Duration(minutes: 5));
      final preReminder = explicitReminder != null &&
              explicitReminder.isBefore(dueAt)
          ? explicitReminder
          : defaultPreReminder;

      if (preReminder.isAfter(snapshot.now)) {
        specs.add(_oneShot(
          id: getTaskNotificationId5m(task.id),
          type: ArcNotificationType.taskReminder,
          channel: ArcNotificationChannel.tasks,
          entityId: task.id,
          title: 'Task due soon',
          body: '${task.title} is due soon.',
          scheduledAt: preReminder,
        ));
      }

      specs.add(_oneShot(
        id: getTaskNotificationIdDeadline(task.id),
        type: ArcNotificationType.taskDeadline,
        channel: ArcNotificationChannel.tasks,
        entityId: task.id,
        title: 'Task deadline reached',
        body: '${task.title} is due now.',
        scheduledAt: dueAt,
      ));
    }
    return specs;
  }

  List<ArcNotificationSpec> _habitNotifications(
    NotificationSnapshot snapshot,
  ) {
    final specs = <ArcNotificationSpec>[];
    final today = DateFormat('yyyy-MM-dd').format(snapshot.now);
    var incompleteCount = 0;

    for (final habit in snapshot.habits) {
      final completedToday = snapshot.habitEntries.any(
        (entry) =>
            entry.habitId == habit.id &&
            entry.dateStr == today &&
            entry.completed,
      );
      if (!completedToday) incompleteCount++;

      final suppressedDate = completedToday ? today : null;
      if (habit.reminderTime != null && habit.reminderTime!.trim().isNotEmpty) {
        final firstTrigger = _nextDailyTrigger(
          snapshot.now,
          habit.reminderTime!,
          forceTomorrow: completedToday,
        );
        if (firstTrigger != null) {
          specs.add(_daily(
            id: getHabitNotificationIdDeadline(habit.id),
            type: ArcNotificationType.habitReminder,
            channel: ArcNotificationChannel.habits,
            entityId: habit.id,
            title: 'Habit reminder',
            body: 'Time to complete: ${habit.name}',
            scheduledAt: firstTrigger,
            localTime: habit.reminderTime!,
            suppressedDate: suppressedDate,
          ));
        }
      }
    }

    // Consolidated single Habit Tracker check-in reminder at the user's configured reminder time
    if (snapshot.habits.isNotEmpty) {
      final allCompleted = incompleteCount == 0;
      final checkInTrigger = _nextDailyTrigger(
        snapshot.now,
        snapshot.settings.remTime,
        forceTomorrow: allCompleted,
      );
      if (checkInTrigger != null) {
        specs.add(_daily(
          id: dailyHabitCheckInId,
          type: ArcNotificationType.habitEveningCheckIn,
          channel: ArcNotificationChannel.habits,
          entityId: 'daily_habit_checkin',
          title: 'Habit check-in',
          body: "Don't forget to review today's habits.",
          scheduledAt: checkInTrigger,
          localTime: snapshot.settings.remTime,
          suppressedDate: allCompleted ? today : null,
        ));
      }
    }
    return specs;
  }

  ArcNotificationSpec? _moneyNotification(NotificationSnapshot snapshot) {
    final today = DateFormat('yyyy-MM-dd').format(snapshot.now);
    final hasTodayTransaction = snapshot.transactions.any(
      (transaction) =>
          DateFormat('yyyy-MM-dd').format(transaction.date) == today,
    );
    final trigger = _nextDailyTrigger(
      snapshot.now,
      snapshot.settings.remTime,
      forceTomorrow: hasTodayTransaction,
    );
    if (trigger == null) return null;

    return _daily(
      id: moneyReminderId,
      type: ArcNotificationType.moneyDaily,
      channel: ArcNotificationChannel.money,
      entityId: 'daily_money',
      title: "Update today's spending",
      body: "Don't forget to add today's expenses to Arc.",
      scheduledAt: trigger,
      localTime: snapshot.settings.remTime,
      suppressedDate: hasTodayTransaction ? today : null,
    );
  }

  ArcNotificationSpec _oneShot({
    required int id,
    required ArcNotificationType type,
    required ArcNotificationChannel channel,
    required String entityId,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) {
    final fingerprint = '${type.name}|$entityId|${scheduledAt.toIso8601String()}';
    return ArcNotificationSpec(
      id: id,
      type: type,
      channel: channel,
      entityId: entityId,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      recurrence: ArcNotificationRecurrence.none,
      fingerprint: fingerprint,
    );
  }

  ArcNotificationSpec _daily({
    required int id,
    required ArcNotificationType type,
    required ArcNotificationChannel channel,
    required String entityId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String localTime,
    String? suppressedDate,
  }) {
    final normalizedTime = _normalizeTime(localTime) ?? localTime;
    final fingerprint = [
      type.name,
      entityId,
      'daily',
      normalizedTime,
      if (suppressedDate != null) 'skip:$suppressedDate',
    ].join('|');
    return ArcNotificationSpec(
      id: id,
      type: type,
      channel: channel,
      entityId: entityId,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      recurrence: ArcNotificationRecurrence.daily,
      fingerprint: fingerprint,
    );
  }

  DateTime? _dateWithTime(DateTime date, String time) {
    final parsed = _parseTime(time);
    if (parsed == null) return null;
    return DateTime(date.year, date.month, date.day, parsed.$1, parsed.$2);
  }

  DateTime? _nextDailyTrigger(
    DateTime now,
    String time, {
    required bool forceTomorrow,
  }) {
    final parsed = _parseTime(time);
    if (parsed == null) return null;
    var trigger = DateTime(now.year, now.month, now.day, parsed.$1, parsed.$2);
    if (forceTomorrow || !trigger.isAfter(now)) {
      trigger = trigger.add(const Duration(days: 1));
    }
    return trigger;
  }

  (int, int)? _parseTime(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour, minute);
  }

  String? _normalizeTime(String value) {
    final parsed = _parseTime(value);
    if (parsed == null) return null;
    return '${parsed.$1.toString().padLeft(2, '0')}:${parsed.$2.toString().padLeft(2, '0')}';
  }

  int getStableHash(String input) {
    var hash = 5381;
    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
      hash &= 0x7FFFFFFF;
    }
    return hash;
  }

  int getTaskNotificationId5m(String taskId) =>
      taskPreDeadlineMin +
      (getStableHash('task_pre_$taskId') % taskPreDeadlineRange);

  int getTaskNotificationIdDeadline(String taskId) =>
      taskDeadlineMin +
      (getStableHash('task_dead_$taskId') % taskDeadlineRange);

  int getHabitNotificationIdDeadline(String habitId) =>
      habitDeadlineMin +
      (getStableHash('habit_dead_$habitId') % habitDeadlineRange);

  int getHabitNotificationIdRemTime(String habitId) =>
      habitRemTimeMin +
      (getStableHash('habit_rem_$habitId') % habitRemTimeRange);

  int getFeedbackNotificationId(String feedbackId) =>
      feedbackNotificationMin +
      (getStableHash('fb_ack_$feedbackId') % feedbackNotificationRange);
}
