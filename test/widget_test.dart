import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/main.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
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

class FakeHabitRepository implements HabitRepository {
  final List<Habit> _habits = [];
  final List<HabitEntry> _entries = [];

  @override
  List<Habit> getHabits() => _habits;

  @override
  List<HabitEntry> getEntries() => _entries;

  @override
  Future<void> saveHabit(Habit habit) async {
    _habits.removeWhere((h) => h.id == habit.id);
    _habits.add(habit);
  }

  @override
  Future<void> deleteHabit(String id) async {
    _habits.removeWhere((h) => h.id == id);
    _entries.removeWhere((e) => e.habitId == id);
  }

  @override
  Future<void> toggleEntry(String habitId, String dateStr, bool completed) async {
    final entryId = '${habitId}_$dateStr';
    _entries.removeWhere((e) => e.id == entryId);
    if (completed) {
      _entries.add(HabitEntry(id: entryId, habitId: habitId, dateStr: dateStr, completed: true));
    }
  }

  @override
  Future<void> syncPending() async {}
}

class FakeMoneyRepository implements MoneyRepository {
  final List<Transaction> _txs = [];
  final Map<String, double> _budgets = {};

  @override
  List<Transaction> getTransactions() => _txs;

  @override
  double getMonthlyBudget(String yearMonth) {
    return _budgets[yearMonth] ?? 0.0;
  }

  @override
  Future<void> saveMonthlyBudget(String yearMonth, double amount) async {
    _budgets[yearMonth] = amount;
  }

  @override
  Future<void> saveTransaction(Transaction tx) async {
    _txs.removeWhere((t) => t.id == tx.id);
    _txs.add(tx);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _txs.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> syncPending() async {}
}

void main() {
  testWidgets('App renders successfully and shows dashboard contents', (WidgetTester tester) async {
    // Build our app with all fake overrides and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
          habitRepositoryProvider.overrideWithValue(FakeHabitRepository()),
          moneyRepositoryProvider.overrideWithValue(FakeMoneyRepository()),
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
