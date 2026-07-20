import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/main.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/providers/global_providers.dart';

class FakeTaskRepository implements TaskRepository {
  final List<Task> _tasks = [
    Task(
      id: '1',
      title: 'Mock Task 1',
      description: 'Mock Description 1',
      priority: 'High',
      category: 'Work',
      labels: [],
      completed: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  List<Task> getTasks() => _tasks;

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
  Future<void> syncPending() async {}
}

void main() {
  testWidgets('App renders successfully and shows dashboard contents', (WidgetTester tester) async {
    // Build our app with the FakeTaskRepository override and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        ],
        child: const ProjectArcApp(),
      ),
    );

    // Let all animations complete and timers settle
    await tester.pumpAndSettle();

    // Verify that the app launches and shows text from the dashboard.
    expect(find.textContaining("Today's Progress"), findsOneWidget);
  });
}
