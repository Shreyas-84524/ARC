import 'package:flutter_test/flutter_test.dart';

import 'package:arc/core/notifications/notification_models.dart';
import 'package:arc/core/notifications/notification_policy.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/settings/models/settings_model.dart';
import 'package:arc/features/task_manager/models/task_model.dart';

void main() {
  final policy = NotificationPolicy();
  final now = DateTime(2026, 10, 29, 9);

  NotificationSnapshot snapshot({
    List<Task> tasks = const [],
    List<Habit> habits = const [],
  }) {
    return NotificationSnapshot(
      userId: 'user',
      settings: SettingsModel.defaultSettings(),
      tasks: tasks,
      habits: habits,
      habitEntries: const [],
      transactions: const [],
      now: now,
    );
  }

  Task task(String id, String priority) => Task(
    id: id,
    title: 'Prepare report',
    description: '',
    priority: priority,
    category: 'Work',
    labels: const [],
    dueDate: DateTime(2026, 10, 29),
    dueTime: '10:00',
    completed: false,
    createdAt: now,
    updatedAt: now,
  );

  test('high priority creates 15m, 5m and persistent due notifications', () {
    final specs = policy.build(snapshot(tasks: [task('high', 'High')]));
    final taskSpecs = specs
        .where((spec) => spec.channel == ArcNotificationChannel.tasks)
        .toList();

    expect(taskSpecs, hasLength(3));
    expect(taskSpecs.map((spec) => spec.scheduledAt), [
      DateTime(2026, 10, 29, 9, 45),
      DateTime(2026, 10, 29, 9, 55),
      DateTime(2026, 10, 29, 10),
    ]);
    expect(
      taskSpecs[0].body,
      'Prepare report is scheduled in 15 minutes. Make sure you\'re ready.',
    );
    expect(
      taskSpecs[1].body,
      'Your high-priority task, Prepare report, starts in 5 minutes.',
    );
    expect(taskSpecs[2].persistent, isTrue);
    expect(taskSpecs[2].actions.map((action) => action.title), [
      'Dismiss',
      'Completed',
    ]);
  });

  test(
    'medium and legacy Must priorities create 10m and actionable due alerts',
    () {
      for (final priority in ['Medium', 'Must']) {
        final specs = policy.build(snapshot(tasks: [task(priority, priority)]));
        final taskSpecs = specs
            .where((spec) => spec.channel == ArcNotificationChannel.tasks)
            .toList();
        expect(taskSpecs, hasLength(2));
        expect(taskSpecs.first.scheduledAt, DateTime(2026, 10, 29, 9, 50));
        expect(taskSpecs.last.title, 'Time to Start');
        expect(taskSpecs.last.persistent, isTrue);
        expect(taskSpecs.last.actions, hasLength(2));
      }
    },
  );

  test('low priority creates only a swipeable due-time notification', () {
    final specs = policy.build(snapshot(tasks: [task('low', 'Low')]));
    final taskSpecs = specs
        .where((spec) => spec.channel == ArcNotificationChannel.tasks)
        .toList();

    expect(taskSpecs, hasLength(1));
    expect(taskSpecs.single.title, 'Task Reminder');
    expect(taskSpecs.single.persistent, isFalse);
    expect(taskSpecs.single.actions, isEmpty);
  });

  test('task without a time has no scheduled task notification', () {
    final withoutTime = task('untimed', 'High').copyWith(dueTime: null);
    // copyWith intentionally preserves null values, so construct the untimed record.
    final actual = Task(
      id: withoutTime.id,
      title: withoutTime.title,
      description: '',
      priority: 'High',
      category: 'Work',
      labels: const [],
      dueDate: DateTime(2026, 10, 29),
      completed: false,
      createdAt: now,
      updatedAt: now,
    );
    final specs = policy.build(snapshot(tasks: [actual]));
    expect(
      specs.where((spec) => spec.channel == ArcNotificationChannel.tasks),
      isEmpty,
    );
  });

  test('habit reminder uses one of the approved messages', () {
    final habit = Habit(
      id: 'habit-1',
      name: 'Meditation',
      category: 'Health',
      colorValue: 0xff00ff00,
      reminderTime: '10:30',
      createdAt: now,
      updatedAt: now,
    );
    final reminder = policy
        .build(snapshot(habits: [habit]))
        .firstWhere((spec) => spec.type == ArcNotificationType.habitReminder);

    expect(
      reminder.title,
      isIn([
        'Time for Your Habit',
        'Keep Your Streak Going',
        'One Step at a Time',
      ]),
    );
    expect(reminder.body, contains('Meditation'));
  });
}
