import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';

class TestTaskRepository implements TaskRepository {
  @override
  String? get userId => null;
  final List<Task> _tasks = [];
  String? _lastCleanupDate;

  @override
  List<Task> getTasks() => List.unmodifiable(_tasks);

  @override
  Future<void> saveTask(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
    } else {
      _tasks.add(task);
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> syncPending() async {}

  @override
  Future<int> performEndOfDayCleanup({String? overrideDateStr}) async {
    final todayStr = overrideDateStr ?? DateTime.now().toIso8601String().substring(0, 10);
    if (_lastCleanupDate == todayStr) {
      return 0;
    }

    final completedTasks = _tasks.where((t) => t.completed).toList();
    int count = 0;
    for (final task in completedTasks) {
      await deleteTask(task.id);
      count++;
    }

    _lastCleanupDate = todayStr;
    return count;
  }
}

void main() {
  group('Task Completion Workflow Tests', () {
    late TestTaskRepository repository;

    setUp(() {
      repository = TestTaskRepository();
    });

    test('Task model correctly serializes completed and completedAt', () {
      final now = DateTime.now();
      final task = Task(
        id: 't1',
        title: 'Complete Project Arc',
        description: 'Implement task completion workflow',
        priority: 'High',
        category: 'Work',
        labels: ['flutter', 'arc'],
        completed: true,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final map = task.toMap();
      expect(map['completed'], isTrue);
      expect(map['completedAt'], equals(now.toIso8601String()));

      final reconstructed = Task.fromMap(map);
      expect(reconstructed.completed, isTrue);
      expect(reconstructed.completedAt, equals(now));
    });

    test('Task copyWith updates completed state and completedAt timestamp', () {
      final now = DateTime.now();
      final task = Task(
        id: 't1',
        title: 'Test Task',
        description: '',
        priority: 'Low',
        category: 'Personal',
        labels: [],
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      final completedTask = task.copyWith(
        completed: true,
        completedAt: now,
      );
      expect(completedTask.completed, isTrue);
      expect(completedTask.completedAt, equals(now));

      final uncheckedTask = completedTask.copyWith(
        completed: false,
        setCompletedAtNull: true,
      );
      expect(uncheckedTask.completed, isFalse);
      expect(uncheckedTask.completedAt, isNull);
    });

    test('End of day cleanup deletes only completed tasks and leaves incomplete tasks untouched', () async {
      final now = DateTime.now();
      final t1 = Task(
        id: '1',
        title: 'Incomplete Task',
        description: '',
        priority: 'High',
        category: 'Work',
        labels: [],
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      final t2 = Task(
        id: '2',
        title: 'Completed Task',
        description: '',
        priority: 'Low',
        category: 'Work',
        labels: [],
        completed: true,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveTask(t1);
      await repository.saveTask(t2);

      expect(repository.getTasks().length, equals(2));

      final count = await repository.performEndOfDayCleanup(overrideDateStr: '2026-07-22');
      expect(count, equals(1));

      final remaining = repository.getTasks();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('1'));
      expect(remaining.first.completed, isFalse);
    });

    test('End of day cleanup is safe against duplicate executions on the same day', () async {
      final now = DateTime.now();
      final t1 = Task(
        id: '1',
        title: 'Completed Task',
        description: '',
        priority: 'Must',
        category: 'Work',
        labels: [],
        completed: true,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveTask(t1);

      final count1 = await repository.performEndOfDayCleanup(overrideDateStr: '2026-07-22');
      expect(count1, equals(1));

      final count2 = await repository.performEndOfDayCleanup(overrideDateStr: '2026-07-22');
      expect(count2, equals(0));
    });
  });
}
