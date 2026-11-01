import 'package:arc/features/dashboard/repository/dashboard_repository.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 1, 10);

  Task task({required String id, DateTime? dueDate, bool completed = false}) {
    return Task(
      id: id,
      title: id,
      description: '',
      priority: 'Low',
      category: 'Personal',
      labels: const [],
      dueDate: dueDate,
      completed: completed,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('empty dashboard and orphaned habit entries do not throw', () {
    final data = DashboardRepository.calculate(
      tasks: const [],
      habits: const [],
      entries: [
        HabitEntry(
          id: 'missing_2026-11-01',
          habitId: 'missing',
          dateStr: '2026-11-01',
          completed: true,
        ),
      ],
      transactions: const [],
      monthlyBudget: 0,
      currentMonth: '2026-11',
      now: now,
    );

    expect(data.completedHabits, 0);
    expect(data.recentActivities, isEmpty);
    expect(data.todayProductivityScore, 0);
  });

  test('daily tasks and monthly money use the requested date boundaries', () {
    final data = DashboardRepository.calculate(
      tasks: [
        task(id: 'undated', completed: true),
        task(id: 'today', dueDate: DateTime(2026, 11, 1, 23, 59)),
        task(id: 'future', dueDate: DateTime(2026, 11, 3)),
      ],
      habits: const [],
      entries: const [],
      transactions: [
        Transaction(
          id: 'income',
          amount: 1000,
          type: 'Income',
          category: 'Salary',
          date: now,
          time: '10:00',
          notes: '',
          createdAt: now,
        ),
        Transaction(
          id: 'expense',
          amount: 250,
          type: 'Expense',
          category: 'Food',
          date: now,
          time: '10:00',
          notes: '',
          createdAt: now,
        ),
      ],
      monthlyBudget: 800,
      currentMonth: '2026-11',
      now: now,
    );

    expect(data.todayTasks.map((item) => item.id), ['undated', 'today']);
    expect(data.upcomingDeadlines.single.id, 'future');
    expect(data.todayIncome, 1000);
    expect(data.todayExpenses, 250);
    expect(data.remainingBudget, 550);
    expect(data.monthlySavings, 750);
    expect(data.recentActivities, hasLength(5));
  });
}
