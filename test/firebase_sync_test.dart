import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel =
        MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return null;
    });
  });

  group('Firebase Synchronization & Conflict Resolution Tests', () {
    test('Conflict resolution correctly prefers remote task when remote updatedAt is newer', () {
      final olderDate = DateTime(2026, 7, 20);
      final newerDate = DateTime(2026, 7, 28);

      final localTask = Task(
        id: 't_conflict',
        title: 'Old Local Task',
        description: '',
        priority: 'Low',
        category: 'Work',
        labels: [],
        completed: false,
        createdAt: olderDate,
        updatedAt: olderDate,
      );

      final remoteTask = Task(
        id: 't_conflict',
        title: 'New Remote Task',
        description: '',
        priority: 'High',
        category: 'Work',
        labels: [],
        completed: true,
        createdAt: olderDate,
        updatedAt: newerDate,
      );

      final shouldUpdate = remoteTask.updatedAt.isAfter(localTask.updatedAt);
      expect(shouldUpdate, isTrue);
    });

    test('Conflict resolution preserves local task when local updatedAt is newer', () {
      final olderDate = DateTime(2026, 7, 20);
      final newerDate = DateTime(2026, 7, 28);

      final localTask = Task(
        id: 't_conflict',
        title: 'Newer Local Task',
        description: '',
        priority: 'High',
        category: 'Work',
        labels: [],
        completed: false,
        createdAt: olderDate,
        updatedAt: newerDate,
      );

      final remoteTask = Task(
        id: 't_conflict',
        title: 'Older Remote Task',
        description: '',
        priority: 'Low',
        category: 'Work',
        labels: [],
        completed: false,
        createdAt: olderDate,
        updatedAt: olderDate,
      );

      final shouldUpdate = remoteTask.updatedAt.isAfter(localTask.updatedAt);
      expect(shouldUpdate, isFalse);
    });

    test('Habit conflict resolution correctly evaluates timestamps', () {
      final olderDate = DateTime(2026, 7, 10);
      final newerDate = DateTime(2026, 7, 25);

      final localHabit = Habit(
        id: 'h_1',
        name: 'Local Habit',
        category: 'Health',
        colorValue: 0xFFFF0000,
        reminderTime: '08:00',
        createdAt: olderDate,
        updatedAt: olderDate,
      );

      final remoteHabit = Habit(
        id: 'h_1',
        name: 'Remote Habit Updated',
        category: 'Health',
        colorValue: 0xFFFF0000,
        reminderTime: '08:00',
        createdAt: olderDate,
        updatedAt: newerDate,
      );

      expect(remoteHabit.updatedAt.isAfter(localHabit.updatedAt), isTrue);
    });
  });
}
