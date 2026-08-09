import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/core/constants/app_constants.dart';
import 'package:arc/core/theme/app_theme.dart';

void main() {
  group('Task Priority Renaming ("Much" -> "Must") & Backward Compatibility Tests', () {
    test('TaskPriority enum uses Must as displayName and emoji', () {
      expect(TaskPriority.must.displayName, equals('Must'));
      expect(TaskPriority.must.emoji, equals('🟠'));
      expect(TaskPriority.must.color, equals(AppColors.priorityMust));
    });

    test('New task with priority Must retains priority and displays as Must', () {
      final task = Task(
        id: 'must_1',
        title: 'New Must Task',
        description: 'Testing Must priority',
        priority: 'Must',
        category: 'Work',
        labels: [],
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.priority, equals('Must'));
      expect(task.displayPriority, equals('Must'));
    });

    test('Existing legacy task with priority Much automatically displays as Must', () {
      final legacyTask = Task(
        id: 'legacy_1',
        title: 'Legacy Much Task',
        description: 'Existing task stored in Hive/Firebase',
        priority: 'Much',
        category: 'Work',
        labels: [],
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Display priority should map "Much" -> "Must"
      expect(legacyTask.displayPriority, equals('Must'));

      // Copying / editing updates priority to "Must"
      final updatedTask = legacyTask.copyWith(priority: 'Must');
      expect(updatedTask.priority, equals('Must'));
      expect(updatedTask.displayPriority, equals('Must'));
    });

    test('Task.fromMap maps legacy "Much" priority to "Must"', () {
      final map = {
        'id': 'map_1',
        'title': 'Map Task',
        'description': '',
        'priority': 'Much',
        'category': 'Work',
        'labels': <String>[],
        'completed': false,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final task = Task.fromMap(map);
      expect(task.priority, equals('Must'));
      expect(task.displayPriority, equals('Must'));
    });
  });
}
