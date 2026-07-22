import 'package:intl/intl.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/providers/global_providers.dart' show getHabitMetrics;

class DashboardRepository {
  final TaskRepository _taskRepository;
  final HabitRepository _habitRepository;
  final MoneyRepository _moneyRepository;

  DashboardRepository({
    required TaskRepository taskRepository,
    required HabitRepository habitRepository,
    required MoneyRepository moneyRepository,
  })  : _taskRepository = taskRepository,
        _habitRepository = habitRepository,
        _moneyRepository = moneyRepository;

  Map<String, dynamic> getDashboardData(String currentMonthStr) {
    final tasks = _taskRepository.getTasks();
    final completedTasks = tasks.where((t) => t.completed).length;
    final totalTasks = tasks.length;

    final habits = _habitRepository.getHabits();
    final entries = _habitRepository.getEntries();

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final completedHabits =
        entries.where((e) => e.dateStr == todayStr && e.completed).length;
    final dailyHabitsCount = habits.where((h) => h.goalType == 'Daily').length;
    final totalHabits = dailyHabitsCount > 0 ? dailyHabitsCount : habits.length;

    int maxStreak = 0;
    for (final h in habits) {
      final metrics = getHabitMetrics(h.id, entries, h.createdAt);
      final streak = (metrics['currentStreak'] as int?) ?? 0;
      if (streak > maxStreak) {
        maxStreak = streak;
      }
    }

    final transactions = _moneyRepository.getTransactions();
    final monthlyBudget = _moneyRepository.getMonthlyBudget(currentMonthStr);

    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    double todayIncome = 0.0;
    double todayExpenses = 0.0;

    for (final tx in transactions) {
      final txMonthStr = DateFormat('yyyy-MM').format(tx.date);
      final txDateStr = DateFormat('yyyy-MM-dd').format(tx.date);

      if (txMonthStr == currentMonthStr) {
        if (tx.type == 'Income') {
          totalIncome += tx.amount;
          if (txDateStr == todayStr) todayIncome += tx.amount;
        } else {
          totalExpenses += tx.amount;
          if (txDateStr == todayStr) todayExpenses += tx.amount;
        }
      }
    }

    final remainingBudget = monthlyBudget + totalIncome - totalExpenses;
    final monthlySavings = totalIncome - totalExpenses;
    final monthlySavingsRate =
        totalIncome > 0 ? (monthlySavings / totalIncome).clamp(0.0, 1.0) : 0.0;

    final taskRate = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    final habitRate = totalHabits > 0 ? completedHabits / totalHabits : 0.0;

    final todayProductivityScore =
        ((taskRate * 0.5 + habitRate * 0.5) * 100).round();
    final overallProductivityScore = todayProductivityScore;

    // Build Recent Activity Feed (top 10 latest events)
    final List<Map<String, dynamic>> activities = [];

    // Recent tasks
    for (final t in tasks) {
      activities.add({
        'type': 'task',
        'title': t.title,
        'subtitle': t.completed ? 'Task Completed' : 'Task Created (${t.category})',
        'timestamp': t.updatedAt,
        'isCompleted': t.completed,
      });
    }

    // Recent habit entries
    for (final e in entries.where((entry) => entry.completed)) {
      final habit = habits.firstWhere(
        (h) => h.id == e.habitId,
        orElse: () => habits.first,
      );
      try {
        final date = DateTime.parse(e.dateStr);
        activities.add({
          'type': 'habit',
          'title': habit.name,
          'subtitle': 'Habit Checked-in',
          'timestamp': date,
          'isCompleted': true,
        });
      } catch (_) {}
    }

    // Recent transactions
    for (final tx in transactions) {
      activities.add({
        'type': 'money',
        'title': '${tx.type}: \$${tx.amount.toStringAsFixed(2)}',
        'subtitle': '${tx.category} • ${tx.notes.isNotEmpty ? tx.notes : "Transaction"}',
        'timestamp': tx.date,
        'isIncome': tx.type == 'Income',
      });
    }

    activities.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    final recentActivities = activities.take(10).toList();

    return {
      'completedTasks': completedTasks,
      'totalTasks': totalTasks,
      'completedHabits': completedHabits,
      'totalHabits': totalHabits,
      'remainingBudget': remainingBudget,
      'totalBudget': monthlyBudget,
      'streakDays': maxStreak,
      'todayIncome': todayIncome,
      'todayExpenses': todayExpenses,
      'monthlySavings': monthlySavings,
      'monthlySavingsRate': monthlySavingsRate,
      'taskCompletionRate': (taskRate * 100).round(),
      'habitCompletionRate': (habitRate * 100).round(),
      'todayProductivityScore': todayProductivityScore,
      'overallProductivityScore': overallProductivityScore,
      'recentActivities': recentActivities,
    };
  }
}
