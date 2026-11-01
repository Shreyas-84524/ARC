import 'package:flutter/foundation.dart';

import 'package:arc/features/task_manager/models/task_model.dart';

enum DashboardActivityType { task, habit, money }

@immutable
class DashboardActivity {
  final DashboardActivityType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final bool isIncome;

  const DashboardActivity({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.isIncome = false,
  });
}

@immutable
class DashboardData {
  final int completedTasks;
  final int totalTasks;
  final int completedHabits;
  final int totalHabits;
  final double remainingBudget;
  final double totalBudget;
  final int streakDays;
  final double todayIncome;
  final double todayExpenses;
  final double monthlySavings;
  final double monthlySavingsRate;
  final int taskCompletionRate;
  final int habitCompletionRate;
  final int todayProductivityScore;
  final List<Task> todayTasks;
  final List<Task> upcomingDeadlines;
  final List<DashboardActivity> recentActivities;

  const DashboardData({
    required this.completedTasks,
    required this.totalTasks,
    required this.completedHabits,
    required this.totalHabits,
    required this.remainingBudget,
    required this.totalBudget,
    required this.streakDays,
    required this.todayIncome,
    required this.todayExpenses,
    required this.monthlySavings,
    required this.monthlySavingsRate,
    required this.taskCompletionRate,
    required this.habitCompletionRate,
    required this.todayProductivityScore,
    required this.todayTasks,
    required this.upcomingDeadlines,
    required this.recentActivities,
  });

  double get progress => (todayProductivityScore / 100).clamp(0, 1);
}
