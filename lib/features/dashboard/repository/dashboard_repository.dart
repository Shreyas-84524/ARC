import 'package:intl/intl.dart';
import 'package:arc/core/utilities/currency_formatter.dart';
import 'package:arc/features/dashboard/models/dashboard_data.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/providers/global_providers.dart' show getHabitMetrics;

class DashboardRepository {
  final TaskRepository _taskRepository;
  final HabitRepository _habitRepository;
  final MoneyRepository _moneyRepository;

  DashboardRepository({
    required TaskRepository taskRepository,
    required HabitRepository habitRepository,
    required MoneyRepository moneyRepository,
  }) : _taskRepository = taskRepository,
       _habitRepository = habitRepository,
       _moneyRepository = moneyRepository;

  DashboardData getDashboardSnapshot(String currentMonthStr, {DateTime? now}) {
    final tasks = _taskRepository.getTasks();
    final habits = _habitRepository.getHabits();
    final entries = _habitRepository.getEntries();
    final transactions = _moneyRepository.getTransactions();
    final monthlyBudget = _moneyRepository.getMonthlyBudget(currentMonthStr);
    final addIncomeToBudget = _moneyRepository.getAddIncomeToBudget();

    return calculate(
      tasks: tasks,
      habits: habits,
      entries: entries,
      transactions: transactions,
      monthlyBudget: monthlyBudget,
      addIncomeToBudget: addIncomeToBudget,
      currentMonth: currentMonthStr,
      now: now ?? DateTime.now(),
    );
  }

  Map<String, dynamic> getDashboardData(String currentMonthStr) {
    final data = getDashboardSnapshot(currentMonthStr);
    return {
      'completedTasks': data.completedTasks,
      'totalTasks': data.totalTasks,
      'completedHabits': data.completedHabits,
      'totalHabits': data.totalHabits,
      'remainingBudget': data.remainingBudget,
      'totalBudget': data.totalBudget,
      'streakDays': data.streakDays,
      'todayIncome': data.todayIncome,
      'todayExpenses': data.todayExpenses,
      'monthlySavings': data.monthlySavings,
      'monthlySavingsRate': data.monthlySavingsRate,
      'taskCompletionRate': data.taskCompletionRate,
      'habitCompletionRate': data.habitCompletionRate,
      'todayProductivityScore': data.todayProductivityScore,
      'overallProductivityScore': data.todayProductivityScore,
      'recentActivities': data.recentActivities
          .map(
            (activity) => {
              'type': activity.type.name,
              'title': activity.title,
              'subtitle': activity.subtitle,
              'timestamp': activity.timestamp,
              'isIncome': activity.isIncome,
            },
          )
          .toList(growable: false),
    };
  }

  static DashboardData calculate({
    required List<Task> tasks,
    required List<Habit> habits,
    required List<HabitEntry> entries,
    required List<Transaction> transactions,
    required double monthlyBudget,
    bool addIncomeToBudget = false,
    required String currentMonth,
    required DateTime now,
  }) {
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final validHabitIds = habits.map((habit) => habit.id).toSet();
    final completedHabits = entries
        .where(
          (entry) =>
              entry.dateStr == todayStr &&
              entry.completed &&
              validHabitIds.contains(entry.habitId),
        )
        .map((entry) => entry.habitId)
        .toSet()
        .length;

    var maxStreak = 0;
    for (final habit in habits) {
      final metrics = getHabitMetrics(habit.id, entries, habit.createdAt);
      final streak = (metrics['currentStreak'] as int?) ?? 0;
      if (streak > maxStreak) maxStreak = streak;
    }

    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    double todayIncome = 0.0;
    double todayExpenses = 0.0;

    for (final tx in transactions) {
      final txMonthStr = DateFormat('yyyy-MM').format(tx.date);
      final txDateStr = DateFormat('yyyy-MM-dd').format(tx.date);

      if (txMonthStr == currentMonth) {
        if (tx.type == 'Income') {
          totalIncome += tx.amount;
          if (txDateStr == todayStr) todayIncome += tx.amount;
        } else {
          totalExpenses += tx.amount;
          if (txDateStr == todayStr) todayExpenses += tx.amount;
        }
      }
    }

    final effectiveBudget =
        addIncomeToBudget ? (monthlyBudget + totalIncome) : monthlyBudget;
    final remainingBudget = effectiveBudget - totalExpenses;
    final monthlySavings = totalIncome - totalExpenses;
    final monthlySavingsRate = totalIncome > 0
        ? (monthlySavings / totalIncome).clamp(0.0, 1.0)
        : 0.0;

    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final todayTasks = tasks.where((t) {
      if (t.dueDate == null) return true;
      return t.dueDate!.isAfter(
            todayStart.subtract(const Duration(seconds: 1)),
          ) &&
          t.dueDate!.isBefore(todayEnd.add(const Duration(seconds: 1)));
    }).toList();

    final upcomingDeadlines =
        tasks
            .where(
              (task) =>
                  !task.completed &&
                  task.dueDate != null &&
                  task.dueDate!.isAfter(todayEnd),
            )
            .toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    final completedTodayTasks = todayTasks.where((t) => t.completed).length;

    final double taskRate = todayTasks.isNotEmpty
        ? (completedTodayTasks / todayTasks.length).clamp(0.0, 1.0)
        : 0.0;
    final double habitRate = habits.isNotEmpty
        ? (completedHabits / habits.length).clamp(0.0, 1.0)
        : 0.0;

    final double taskScore = taskRate * 50.0;
    final double habitScore = habitRate * 50.0;

    final int todayProductivityScore = (taskScore + habitScore)
        .clamp(0.0, 100.0)
        .round();
    final activities = <DashboardActivity>[];

    // Recent tasks
    for (final t in tasks) {
      activities.add(
        DashboardActivity(
          type: DashboardActivityType.task,
          title: t.title,
          subtitle: t.completed
              ? 'Task Completed'
              : 'Task Created (${t.category})',
          timestamp: t.updatedAt,
        ),
      );
    }

    final habitsById = {for (final habit in habits) habit.id: habit};
    for (final entry in entries.where((item) => item.completed)) {
      final habit = habitsById[entry.habitId];
      final date = DateTime.tryParse(entry.dateStr);
      if (habit == null || date == null) continue;
      activities.add(
        DashboardActivity(
          type: DashboardActivityType.habit,
          title: habit.name,
          subtitle: 'Habit Checked-in',
          timestamp: date,
        ),
      );
    }

    // Recent transactions
    for (final tx in transactions) {
      activities.add(
        DashboardActivity(
          type: DashboardActivityType.money,
          title: '${tx.type}: ${CurrencyFormatter.format(tx.amount)}',
          subtitle:
              '${tx.category} • ${tx.notes.isNotEmpty ? tx.notes : "Transaction"}',
          timestamp: tx.date,
          isIncome: tx.type == 'Income',
        ),
      );
    }

    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final recentActivities = activities.take(10).toList();

    return DashboardData(
      completedTasks: tasks.where((task) => task.completed).length,
      totalTasks: tasks.length,
      completedHabits: completedHabits,
      totalHabits: habits.length,
      remainingBudget: remainingBudget,
      totalBudget: effectiveBudget,
      streakDays: maxStreak,
      todayIncome: todayIncome,
      todayExpenses: todayExpenses,
      monthlySavings: monthlySavings,
      monthlySavingsRate: monthlySavingsRate,
      taskCompletionRate: (taskRate * 100).round(),
      habitCompletionRate: (habitRate * 100).round(),
      todayProductivityScore: todayProductivityScore,
      todayTasks: List.unmodifiable(todayTasks),
      upcomingDeadlines: List.unmodifiable(upcomingDeadlines),
      recentActivities: List.unmodifiable(recentActivities),
    );
  }
}
