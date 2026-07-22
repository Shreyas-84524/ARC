import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/providers/global_providers.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  final List<Map<String, dynamic>> _dismissedNotifications = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tasks = ref.watch(tasksProvider);
    final habits = ref.watch(habitsProvider);

    final List<Map<String, dynamic>> notifications = [];
    final now = DateTime.now();

    // Task Notifications
    for (final task in tasks) {
      if (task.dueDate != null) {
        final isOverdue = !task.completed && task.dueDate!.isBefore(now);
        notifications.add({
          'id': 'task_${task.id}',
          'module': 'Task Manager',
          'title': task.title,
          'body': isOverdue
              ? 'Task is overdue! Due ${DateFormat('MMM d').format(task.dueDate!)}'
              : 'Task scheduled for ${DateFormat('MMM d').format(task.dueDate!)}${task.dueTime != null ? " at ${task.dueTime}" : ""}',
          'timestamp': task.dueDate!,
          'type': isOverdue ? 'overdue' : 'reminder',
          'icon': LucideIcons.checkSquare,
          'color': isOverdue ? AppColors.danger : AppColors.info,
        });
      }
    }

    // Habit Reminders
    final dailyHabits = habits.where((h) => h.goalType == 'Daily').toList();
    if (dailyHabits.isNotEmpty) {
      notifications.add({
        'id': 'habit_evening_reminder',
        'module': 'Habit Tracker',
        'title': 'Evening Habit Check-in',
        'body': 'Daily reminder scheduled at 8:00 PM to log daily habits.',
        'timestamp': DateTime(now.year, now.month, now.day, 20, 0),
        'type': 'reminder',
        'icon': LucideIcons.zap,
        'color': AppColors.accent,
      });
    }

    // Money Reminders
    notifications.add({
      'id': 'money_daily_reminder',
      'module': 'Money Tracker',
      'title': 'Daily Expense Reminder',
      'body': 'Scheduled at 8:00 PM and 10:00 PM to record daily transactions.',
      'timestamp': DateTime(now.year, now.month, now.day, 20, 0),
      'type': 'reminder',
      'icon': LucideIcons.wallet,
      'color': AppColors.success,
    });

    final activeNotifications = notifications
        .where((n) => !_dismissedNotifications.any((d) => d['id'] == n['id']))
        .toList();

    activeNotifications.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notification Center',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (activeNotifications.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _dismissedNotifications.addAll(activeNotifications);
                });
              },
              child: const Text(
                'Clear All',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
        ],
      ),
      body: activeNotifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.bellOff,
                    size: 48,
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active notifications',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You are all caught up!',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: activeNotifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notif = activeNotifications[index];
                final icon = notif['icon'] as IconData;
                final color = notif['color'] as Color;
                final timestamp = notif['timestamp'] as DateTime;

                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(
                      notif['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${notif['body']}\n${DateFormat('MMM d, h:mm a').format(timestamp)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
                      ),
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        setState(() {
                          _dismissedNotifications.add(notif);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
