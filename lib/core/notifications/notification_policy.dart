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

  List<ArcNotificationSpec> _taskNotifications(NotificationSnapshot snapshot) {
    final specs = <ArcNotificationSpec>[];
    for (final task in snapshot.tasks) {
      if (task.completed || task.dueDate == null || task.dueTime == null) {
        continue;
      }
      final dueAt = _dateWithTime(task.dueDate!, task.dueTime!);
      if (dueAt == null || !dueAt.isAfter(snapshot.now)) continue;

      final priority = task.priority.trim().toLowerCase();
      final isHigh = priority == 'high';
      final isMedium =
          priority == 'medium' || priority == 'must' || priority == 'much';

      if (isHigh) {
        _addFutureTaskReminder(
          specs,
          now: snapshot.now,
          scheduledAt: dueAt.subtract(const Duration(minutes: 15)),
          id: getTaskNotificationId15m(task.id),
          taskId: task.id,
          title: 'Task reminder',
          body:
              '${task.title} is scheduled in 15 minutes. Make sure you\'re ready.',
        );
        _addFutureTaskReminder(
          specs,
          now: snapshot.now,
          scheduledAt: dueAt.subtract(const Duration(minutes: 5)),
          id: getTaskNotificationId5m(task.id),
          taskId: task.id,
          title: 'Task reminder',
          body: 'Your high-priority task, ${task.title}, starts in 5 minutes.',
        );
      } else if (isMedium) {
        _addFutureTaskReminder(
          specs,
          now: snapshot.now,
          scheduledAt: dueAt.subtract(const Duration(minutes: 10)),
          id: getTaskNotificationId10m(task.id),
          taskId: task.id,
          title: 'Task reminder',
          body: '${task.title} starts in 10 minutes. Make sure you\'re ready.',
        );
      }

      specs.add(
        _oneShot(
          id: getTaskNotificationIdDeadline(task.id),
          type: ArcNotificationType.taskDeadline,
          channel: ArcNotificationChannel.tasks,
          entityId: task.id,
          title: isHigh
              ? 'Time for ${task.title}'
              : isMedium
              ? 'Time to Start'
              : 'Task Reminder',
          body: isHigh
              ? 'It\'s time for ${task.title}. Time to focus and get it done!'
              : isMedium
              ? '${task.title} is scheduled to begin now. Time to focus and get it done!'
              : '${task.title} is scheduled to start now.',
          scheduledAt: dueAt,
          persistent: isHigh || isMedium,
          actions: isHigh || isMedium
              ? const [
                  ArcNotificationAction(id: 'task_dismiss', title: 'Dismiss'),
                  ArcNotificationAction(
                    id: 'task_complete',
                    title: 'Completed',
                  ),
                ]
              : const [],
        ),
      );
    }
    return specs;
  }

  void _addFutureTaskReminder(
    List<ArcNotificationSpec> specs, {
    required DateTime now,
    required DateTime scheduledAt,
    required int id,
    required String taskId,
    required String title,
    required String body,
  }) {
    if (!scheduledAt.isAfter(now)) return;
    specs.add(
      _oneShot(
        id: id,
        type: ArcNotificationType.taskReminder,
        channel: ArcNotificationChannel.tasks,
        entityId: taskId,
        title: title,
        body: body,
        scheduledAt: scheduledAt,
      ),
    );
  }

  List<ArcNotificationSpec> _habitNotifications(NotificationSnapshot snapshot) {
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
          final message = _habitMessage(habit.id, habit.name);
          specs.add(
            _daily(
              id: getHabitNotificationIdDeadline(habit.id),
              type: ArcNotificationType.habitReminder,
              channel: ArcNotificationChannel.habits,
              entityId: habit.id,
              title: message.$1,
              body: message.$2,
              scheduledAt: firstTrigger,
              localTime: habit.reminderTime!,
              suppressedDate: suppressedDate,
            ),
          );
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
        specs.add(
          _daily(
            id: dailyHabitCheckInId,
            type: ArcNotificationType.habitEveningCheckIn,
            channel: ArcNotificationChannel.habits,
            entityId: 'daily_habit_checkin',
            title: 'Habit check-in',
            body: "Don't forget to review today's habits.",
            scheduledAt: checkInTrigger,
            localTime: snapshot.settings.remTime,
            suppressedDate: allCompleted ? today : null,
          ),
        );
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
    bool persistent = false,
    List<ArcNotificationAction> actions = const [],
  }) {
    final fingerprint = [
      type.name,
      entityId,
      scheduledAt.toIso8601String(),
      title,
      body,
      persistent,
      ...actions.map((action) => '${action.id}:${action.title}'),
    ].join('|');
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
      persistent: persistent,
      actions: actions,
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
      title,
      body,
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

  (String, String) _habitMessage(String habitId, String habitName) {
    final variant = getStableHash('habit_copy_$habitId') % 3;
    return switch (variant) {
      0 => (
        'Time for Your Habit',
        'It\'s time for $habitName. A small step today builds a stronger routine.',
      ),
      1 => (
        'Keep Your Streak Going',
        'Your $habitName reminder is here. Show up for yourself today!',
      ),
      _ => (
        'One Step at a Time',
        'Time to practise $habitName. Consistency matters more than perfection.',
      ),
    };
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

  int getTaskNotificationId15m(String taskId) =>
      taskPreDeadlineMin +
      (getStableHash('task_15m_$taskId') % taskPreDeadlineRange);

  int getTaskNotificationId10m(String taskId) =>
      taskPreDeadlineMin +
      (getStableHash('task_10m_$taskId') % taskPreDeadlineRange);

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
