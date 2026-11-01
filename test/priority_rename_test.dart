import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/core/constants/app_constants.dart';
import 'package:arc/core/theme/app_theme.dart';

void main() {
  group('Task Priority Medium naming and backward compatibility', () {
    test('TaskPriority enum uses Medium as displayName and emoji', () {
      expect(TaskPriority.must.displayName, equals('Medium'));
      expect(TaskPriority.must.emoji, equals('🟠'));
      expect(TaskPriority.must.color, equals(AppColors.priorityMust));
    });

    test('New task with priority Medium retains its display name', () {
      final task = Task(
        id: 'must_1',
        title: 'New Medium Task',
        description: 'Testing Medium priority',
        priority: 'Medium',
        category: 'Work',
        labels: [],
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.priority, equals('Medium'));
      expect(task.displayPriority, equals('Medium'));
    });

    test('Existing legacy priority names automatically display as Medium', () {
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

      expect(legacyTask.displayPriority, equals('Medium'));

      final updatedTask = legacyTask.copyWith(priority: 'Medium');
      expect(updatedTask.priority, equals('Medium'));
      expect(updatedTask.displayPriority, equals('Medium'));
    });

    test('Task.fromMap maps legacy "Much" priority to "Medium"', () {
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
      expect(task.priority, equals('Medium'));
      expect(task.displayPriority, equals('Medium'));
    });
  });
}
