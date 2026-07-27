import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/providers/global_providers.dart';

class MockTaskRepository implements TaskRepository {
  final List<Task> _tasks = [];

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
    final completed = _tasks.where((t) => t.completed).toList();
    for (final task in completed) {
      _tasks.removeWhere((t) => t.id == task.id);
    }
    return completed.length;
  }
}

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

  group('Task Manager Filter System Tests', () {
    late MockTaskRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = MockTaskRepository();
      container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Task createTask({
      required String id,
      required String title,
      required bool completed,
      DateTime? dueDate,
      String? dueTime,
    }) {
      final now = DateTime.now();
      return Task(
        id: id,
        title: title,
        description: 'Test Description',
        priority: 'Low',
        category: 'Work',
        labels: ['test'],
        dueDate: dueDate,
        dueTime: dueTime,
        completed: completed,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('Scenario 1: Future task appears in Pending and Upcoming only', () async {
      final futureDate = DateTime.now().add(const Duration(days: 2));
      final futureTask = createTask(
        id: 'future_1',
        title: 'Future Task',
        completed: false,
        dueDate: futureDate,
      );

      await container.read(tasksProvider.notifier).addTask(futureTask);

      // Filter: All Tasks
      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('future_1'));

      // Filter: Pending
      container.read(taskStatusFilterProvider.notifier).state = 'Pending';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('future_1'));

      // Filter: Upcoming
      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'Upcoming';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('future_1'));

      // Filter: Today
      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'Today';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('future_1')));

      // Filter: Completed
      container.read(taskStatusFilterProvider.notifier).state = 'Completed';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('future_1')));

      // Filter: Overdue
      container.read(taskStatusFilterProvider.notifier).state = 'Overdue';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('future_1')));
    });

    test('Scenario 2: Today task appears in Pending and Today only', () async {
      final todayDate = DateTime.now();
      final todayTask = createTask(
        id: 'today_1',
        title: 'Today Task',
        completed: false,
        dueDate: todayDate,
      );

      await container.read(tasksProvider.notifier).addTask(todayTask);

      // Filter: All Tasks
      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('today_1'));

      // Filter: Pending
      container.read(taskStatusFilterProvider.notifier).state = 'Pending';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('today_1'));

      // Filter: Today
      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'Today';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('today_1'));

      // Filter: Upcoming
      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'Upcoming';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('today_1')));

      // Filter: Completed
      container.read(taskStatusFilterProvider.notifier).state = 'Completed';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('today_1')));

      // Filter: Overdue
      container.read(taskStatusFilterProvider.notifier).state = 'Overdue';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('today_1')));
    });

    test('Scenario 3: Completed today task appears in Completed only', () async {
      final todayDate = DateTime.now();
      final completedTodayTask = createTask(
        id: 'comp_today',
        title: 'Completed Today Task',
        completed: true,
        dueDate: todayDate,
      );

      await container.read(tasksProvider.notifier).addTask(completedTodayTask);

      // Filter: All Tasks
      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('comp_today'));

      // Filter: Completed
      container.read(taskStatusFilterProvider.notifier).state = 'Completed';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('comp_today'));

      // Excluded from Pending, Today, Upcoming, Overdue
      container.read(taskStatusFilterProvider.notifier).state = 'Pending';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('comp_today')));

      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'Today';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('comp_today')));

      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'Upcoming';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('comp_today')));

      container.read(taskStatusFilterProvider.notifier).state = 'Overdue';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('comp_today')));
    });

    test('Scenario 4: Yesterday unfinished task appears in Overdue only', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 2));
      final overdueTask = createTask(
        id: 'overdue_1',
        title: 'Overdue Task',
        completed: false,
        dueDate: yesterday,
      );

      await container.read(tasksProvider.notifier).addTask(overdueTask);

      // Filter: All Tasks
      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('overdue_1'));

      // Filter: Overdue
      container.read(taskStatusFilterProvider.notifier).state = 'Overdue';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('overdue_1'));

      // Excluded from Pending, Today, Upcoming, Completed
      container.read(taskStatusFilterProvider.notifier).state = 'Pending';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('overdue_1')));

      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'Today';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('overdue_1')));

      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'Upcoming';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('overdue_1')));

      container.read(taskStatusFilterProvider.notifier).state = 'Completed';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('overdue_1')));
    });

    test('Scenario 5: Yesterday completed task appears in Completed only', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 2));
      final completedYesterdayTask = createTask(
        id: 'comp_yesterday',
        title: 'Completed Yesterday Task',
        completed: true,
        dueDate: yesterday,
      );

      await container.read(tasksProvider.notifier).addTask(completedYesterdayTask);

      // Filter: Completed
      container.read(taskStatusFilterProvider.notifier).state = 'Completed';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('comp_yesterday'));

      // Excluded from Overdue & Pending
      container.read(taskStatusFilterProvider.notifier).state = 'Overdue';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('comp_yesterday')));

      container.read(taskStatusFilterProvider.notifier).state = 'Pending';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('comp_yesterday')));
    });

    test('Scenario 6: Future completed task appears in Completed only', () async {
      final futureDate = DateTime.now().add(const Duration(days: 3));
      final completedFutureTask = createTask(
        id: 'comp_future',
        title: 'Completed Future Task',
        completed: true,
        dueDate: futureDate,
      );

      await container.read(tasksProvider.notifier).addTask(completedFutureTask);

      // Filter: Completed
      container.read(taskStatusFilterProvider.notifier).state = 'Completed';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('comp_future'));

      // Excluded from Upcoming & Pending
      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'Upcoming';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('comp_future')));

      container.read(taskStatusFilterProvider.notifier).state = 'Pending';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('comp_future')));
    });

    test('Scenario 7: Multiple mixed tasks verify every filter independently', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 2));
      final tomorrow = now.add(const Duration(days: 2));

      final tPendingToday = createTask(id: 't1', title: 'Pending Today', completed: false, dueDate: now);
      final tPendingUpcoming = createTask(id: 't2', title: 'Pending Upcoming', completed: false, dueDate: tomorrow);
      final tOverdue = createTask(id: 't3', title: 'Overdue Task', completed: false, dueDate: yesterday);
      final tCompleted = createTask(id: 't4', title: 'Completed Task', completed: true, dueDate: now);

      final notifier = container.read(tasksProvider.notifier);
      await notifier.addTask(tPendingToday);
      await notifier.addTask(tPendingUpcoming);
      await notifier.addTask(tOverdue);
      await notifier.addTask(tCompleted);

      // 1. All Tasks
      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).length, equals(4));

      // 2. Pending Tasks (t1, t2)
      container.read(taskStatusFilterProvider.notifier).state = 'Pending';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      final pendingIds = container.read(filteredTasksProvider).map((t) => t.id).toList();
      expect(pendingIds, containsAll(['t1', 't2']));
      expect(pendingIds, isNot(contains('t3')));
      expect(pendingIds, isNot(contains('t4')));

      // 3. Today Tasks (t1)
      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'Today';
      final todayIds = container.read(filteredTasksProvider).map((t) => t.id).toList();
      expect(todayIds, equals(['t1']));

      // 4. Upcoming Tasks (t2)
      container.read(taskStatusFilterProvider.notifier).state = 'All';
      container.read(taskDateFilterProvider.notifier).state = 'Upcoming';
      final upcomingIds = container.read(filteredTasksProvider).map((t) => t.id).toList();
      expect(upcomingIds, equals(['t2']));

      // 5. Overdue Tasks (t3)
      container.read(taskStatusFilterProvider.notifier).state = 'Overdue';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      final overdueIds = container.read(filteredTasksProvider).map((t) => t.id).toList();
      expect(overdueIds, equals(['t3']));

      // 6. Completed Tasks (t4)
      container.read(taskStatusFilterProvider.notifier).state = 'Completed';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      final completedIds = container.read(filteredTasksProvider).map((t) => t.id).toList();
      expect(completedIds, equals(['t4']));
    });

    test('Real-time task completion toggle instantly updates filters', () async {
      final now = DateTime.now();
      final task = createTask(id: 'toggle_1', title: 'Toggle Task', completed: false, dueDate: now);
      final notifier = container.read(tasksProvider.notifier);
      await notifier.addTask(task);

      // Verify in Pending & Today
      container.read(taskStatusFilterProvider.notifier).state = 'Pending';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('toggle_1'));

      // Toggle Task to completed
      await notifier.toggleTask('toggle_1');

      // Verify immediately removed from Pending
      expect(container.read(filteredTasksProvider).map((t) => t.id), isNot(contains('toggle_1')));

      // Verify immediately appears in Completed
      container.read(taskStatusFilterProvider.notifier).state = 'Completed';
      container.read(taskDateFilterProvider.notifier).state = 'All';
      expect(container.read(filteredTasksProvider).map((t) => t.id), contains('toggle_1'));
    });
  });
}
