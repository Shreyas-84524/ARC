import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:arc/core/notifications/notification_service.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/settings/models/settings_model.dart';
import 'package:arc/features/settings/repository/settings_repository.dart';

/// NotificationReconciler is responsible for determining what notifications
/// should currently exist and reconciling expected notifications against
/// locally scheduled on-device notifications.
///
/// It strictly observes:
/// - Active Firebase UID
/// - Incomplete tasks with valid deadlines
/// - Habits and their completion state for the current day
/// - Global `rem_time`
/// - Notification settings (master, tasks, habits, money)
class NotificationReconciler {
  final NotificationService _notificationService;

  NotificationReconciler({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  /// Reconciles all local notifications for the active user session.
  Future<void> reconcile({
    required String? userId,
    List<Task>? tasks,
    List<Habit>? habits,
    List<HabitEntry>? habitEntries,
    String? remTime,
    SettingsModel? settings,
  }) async {
    if (kIsWeb) return;

    if (userId == null || userId.isEmpty) {
      debugPrint('NotificationReconciler: No active user. Purging all notifications.');
      await _notificationService.cancelAllUserNotifications();
      return;
    }

    final activeSettings =
        settings ?? SettingsRepository(userId: userId).getSettings();

    // If master notifications are disabled, purge all user notifications
    if (!activeSettings.masterNotificationsEnabled) {
      debugPrint('NotificationReconciler: Master notifications disabled. Purging all.');
      await _notificationService.cancelAllUserNotifications();
      return;
    }

    final effectiveRemTime = remTime ?? activeSettings.remTime;
    final activeTasks = tasks ?? TaskRepository(userId: userId).getTasks();
    final activeHabits = habits ?? HabitRepository(userId: userId).getHabits();
    final activeEntries =
        habitEntries ?? HabitRepository(userId: userId).getEntries();

    debugPrint(
      'NotificationReconciler: Reconciling for user $userId (rem_time: $effectiveRemTime, tasks: ${activeTasks.length}, habits: ${activeHabits.length})',
    );

    // 1. Reconcile Tasks
    if (activeSettings.taskRemindersEnabled) {
      final now = DateTime.now();
      for (final task in activeTasks) {
        if (task.completed || task.dueDate == null || task.dueTime == null) {
          await _notificationService.cancelTaskReminders(task.id);
        } else {
          final parts = task.dueTime!.split(':');
          if (parts.length == 2) {
            final hour = int.tryParse(parts[0]);
            final minute = int.tryParse(parts[1]);
            if (hour != null && minute != null) {
              final dueDateTime = DateTime(
                task.dueDate!.year,
                task.dueDate!.month,
                task.dueDate!.day,
                hour,
                minute,
              );
              if (dueDateTime.isBefore(now)) {
                await _notificationService.cancelTaskReminders(task.id);
              } else {
                await _notificationService.scheduleTaskReminders(task);
              }
            }
          }
        }
      }
    } else {
      for (final task in activeTasks) {
        await _notificationService.cancelTaskReminders(task.id);
      }
    }

    // 2. Reconcile Habits
    if (activeSettings.habitRemindersEnabled) {
      await reconcileHabits(
        habits: activeHabits,
        entries: activeEntries,
        remTime: effectiveRemTime,
      );
    } else {
      for (final habit in activeHabits) {
        await _notificationService.cancelHabitReminders(habit.id);
      }
    }

    // 3. Reconcile Money Manager Reminder
    if (activeSettings.moneyRemindersEnabled) {
      await _notificationService.scheduleDailyMoneyReminder(effectiveRemTime);
    } else {
      await _notificationService.cancelMoneyReminders();
    }

    debugPrint('NotificationReconciler: Reconciliation completed successfully.');
  }

  /// Reconciles habit deadline and pending `rem_time` notifications against
  /// current day's completion state.
  Future<void> reconcileHabits({
    required List<Habit> habits,
    required List<HabitEntry> entries,
    required String remTime,
  }) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (final habit in habits) {
      final bool completedToday = entries.any(
        (e) => e.habitId == habit.id && e.dateStr == todayStr && e.completed,
      );

      await _notificationService.scheduleHabitReminders(
        habit: habit,
        completedToday: completedToday,
        remTime: remTime,
      );
    }
  }

  /// Called when the user updates `rem_time` in Settings.
  /// Cancels old `rem_time` dependent schedules and reschedules Habit pending
  /// and Money Manager reminders, without touching task notifications.
  Future<void> onRemTimeChanged({
    required String newRemTime,
    required String? userId,
    List<Habit>? habits,
    List<HabitEntry>? habitEntries,
    SettingsModel? settings,
  }) async {
    if (kIsWeb || userId == null || userId.isEmpty) return;

    final activeSettings =
        settings ?? SettingsRepository(userId: userId).getSettings();
    if (!activeSettings.masterNotificationsEnabled) return;

    debugPrint('NotificationReconciler: Rescheduling rem_time dependents for new time: $newRemTime');

    final activeHabits = habits ?? HabitRepository(userId: userId).getHabits();
    final activeEntries =
        habitEntries ?? HabitRepository(userId: userId).getEntries();

    // Reschedule habit pending reminders
    if (activeSettings.habitRemindersEnabled) {
      await reconcileHabits(
        habits: activeHabits,
        entries: activeEntries,
        remTime: newRemTime,
      );
    }

    // Reschedule money manager reminder
    if (activeSettings.moneyRemindersEnabled) {
      await _notificationService.scheduleDailyMoneyReminder(newRemTime);
    }
  }

  /// Called when a habit is toggled (completed or uncompleted) for today.
  Future<void> onHabitToggled({
    required String habitId,
    required bool completed,
    required String? userId,
    required String remTime,
    Habit? habit,
  }) async {
    if (kIsWeb || userId == null || userId.isEmpty) return;

    if (completed) {
      // Habit is complete today: cancel both deadline and rem_time reminders
      await _notificationService.cancelHabitReminders(habitId);
      debugPrint('NotificationReconciler: Habit $habitId completed today. Reminders cancelled.');
    } else {
      // Habit is incomplete: look up habit and reschedule for today
      final targetHabit = habit ??
          HabitRepository(userId: userId)
              .getHabits()
              .firstWhere((h) => h.id == habitId, orElse: () => throw Exception('Habit not found'));
      await _notificationService.scheduleHabitReminders(
        habit: targetHabit,
        completedToday: false,
        remTime: remTime,
      );
      debugPrint('NotificationReconciler: Habit $habitId marked incomplete today. Reminders rescheduled.');
    }
  }
}
