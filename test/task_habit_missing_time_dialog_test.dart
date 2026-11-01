import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/habit_tracker/widgets/habit_editor_sheet.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/task_manager/widgets/task_editor_sheet.dart';
import 'package:arc/providers/global_providers.dart';

class _TaskRepository implements TaskRepository {
  final tasks = <Task>[];

  @override
  String? get userId => 'test';
  @override
  List<Task> getTasks() => List.unmodifiable(tasks);
  @override
  Future<void> saveTask(Task task) async => tasks.add(task);
  @override
  Future<void> deleteTask(String id) async =>
      tasks.removeWhere((task) => task.id == id);
  @override
  Future<bool> syncPending() async => true;
  @override
  Future<int> performEndOfDayCleanup({String? overrideDateStr}) async => 0;
}

class _HabitRepository implements HabitRepository {
  final habits = <Habit>[];

  @override
  String? get userId => 'test';
  @override
  List<Habit> getHabits() => List.unmodifiable(habits);
  @override
  List<HabitEntry> getEntries() => const [];
  @override
  Future<void> saveHabit(Habit habit) async => habits.add(habit);
  @override
  Future<void> deleteHabit(String id) async =>
      habits.removeWhere((habit) => habit.id == id);
  @override
  Future<void> toggleEntry(
    String habitId,
    String dateStr,
    bool completed,
  ) async {}
  @override
  Future<bool> syncPending() async => true;
}

void main() {
  testWidgets('task editor warns before saving without a time', (tester) async {
    final repository = _TaskRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: Scaffold(body: TaskEditorSheet()),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Write proposal');
    final save = find.widgetWithText(ElevatedButton, 'Create Task');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Set a Time for Your Task?'), findsOneWidget);
    expect(
      find.text(
        'Add a time to Write proposal so we can remind you when it\'s time to get started.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Set Time'), findsOneWidget);
    expect(find.text('Continue Without Time'), findsOneWidget);

    await tester.tap(find.text('Continue Without Time'));
    await tester.pumpAndSettle();
    expect(repository.tasks, hasLength(1));
    expect(repository.tasks.single.dueTime, isNull);
  });

  testWidgets('habit editor warns before saving without a time', (tester) async {
    final repository = _HabitRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [habitRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: Scaffold(body: HabitEditorSheet()),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Meditate');
    final save = find.widgetWithText(ElevatedButton, 'Create Habit');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('When Will You Do It?'), findsOneWidget);
    expect(
      find.text('Add a time for Meditate in your daily routine.'),
      findsOneWidget,
    );
    expect(find.text('Set Time'), findsOneWidget);
    expect(find.text('Continue Without Time'), findsOneWidget);

    await tester.tap(find.text('Continue Without Time'));
    await tester.pumpAndSettle();
    expect(repository.habits, hasLength(1));
    expect(repository.habits.single.reminderTime, isNull);
  });
}
