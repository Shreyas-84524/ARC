import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/task_manager/screens/tasks_screen.dart';
import 'package:arc/providers/global_providers.dart';

class InMemoryTaskRepository implements TaskRepository {
  final List<Task> _tasks = [];

  @override
  String? get userId => 'test_user';

  @override
  List<Task> getTasks() => List.unmodifiable(_tasks);

  @override
  Future<void> saveTask(Task task) async {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      _tasks[idx] = task;
    } else {
      _tasks.add(task);
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }

  @override
  Future<bool> syncPending() async => true;

  @override
  Future<int> performEndOfDayCleanup({String? overrideDateStr}) async => 0;
}

void main() {
  final now = DateTime.now();

  Widget buildTestWidget({List<Task>? initialTasks}) {
    final repo = InMemoryTaskRepository();
    if (initialTasks != null) {
      for (final t in initialTasks) {
        repo.saveTask(t);
      }
    }

    return ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const TasksScreen(),
      ),
    );
  }

  testWidgets('TasksScreen verifies search bar and Today filter are removed, Pending is default', (WidgetTester tester) async {
    final pendingTask = Task(
      id: 'task_p1',
      title: 'Complete Project Documentation',
      description: '',
      labels: const [],
      dueDate: now.add(const Duration(days: 1)),
      dueTime: '18:00',
      priority: 'Must',
      category: 'Work',
      completed: false,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(buildTestWidget(initialTasks: [pendingTask]));
    await tester.pumpAndSettle();

    // 1. Verify Search Bar is COMPLETELY ABSENT
    expect(find.text('Search tasks...'), findsNothing);

    // 2. Verify "Today" option is COMPLETELY ABSENT from filters
    expect(find.text('Today'), findsNothing);

    // 3. Verify "Pending" is selected by default and displays pending task
    final container = ProviderScope.containerOf(tester.element(find.byType(TasksScreen)));
    expect(container.read(taskStatusFilterProvider), 'Pending');
    expect(find.text('Complete Project Documentation'), findsOneWidget);

    // 4. Verify other filter chips exist
    expect(find.text('All Tasks'), findsOneWidget);
    expect(find.text('Pending'), findsNWidgets(2)); // Stats badge + Filter chip
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Overdue'), findsNWidgets(2)); // Stats badge + Filter chip
    expect(find.text('Completed'), findsOneWidget);

    // 5. Verify Sort By and Category dropdowns have vertical padding 10.0 (total 20.0px)
    final dropdown1 = tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>));
    final dropdown2 = tester.widget<DropdownButtonFormField<String?>>(find.byType(DropdownButtonFormField<String?>));
    expect((dropdown1.decoration.contentPadding as EdgeInsets).vertical, 20.0);
    expect((dropdown2.decoration.contentPadding as EdgeInsets).vertical, 20.0);
  });
}
