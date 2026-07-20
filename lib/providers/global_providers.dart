import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Theme Mode Provider (Light vs Dark)
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.dark; // Default to dark mode as per design.md
});

// Dashboard State Provider (Placeholder)
final dashboardProvider = Provider<Map<String, dynamic>>((ref) {
  return {
    'completedTasks': 3,
    'totalTasks': 5,
    'completedHabits': 2,
    'totalHabits': 4,
    'remainingBudget': 420.50,
    'totalBudget': 800.00,
    'streakDays': 8,
  };
});

// Tasks State Provider (Placeholder)
final tasksProvider = StateNotifierProvider<TasksNotifier, List<Map<String, dynamic>>>((ref) {
  return TasksNotifier();
});

class TasksNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  TasksNotifier() : super([
    {'id': '1', 'title': 'Implement Folder Structure', 'dueDate': 'Today, 4:00 PM', 'priority': 'High', 'completed': false},
    {'id': '2', 'title': 'Register App with Firebase Console', 'dueDate': 'Today, 5:30 PM', 'priority': 'High', 'completed': false},
    {'id': '3', 'title': 'Configure Riverpod Providers', 'dueDate': 'Tomorrow, 10:00 AM', 'priority': 'Much', 'completed': false},
    {'id': '4', 'title': 'Build Notification Infrastructure', 'dueDate': 'Tomorrow, 2:00 PM', 'priority': 'Low', 'completed': false},
  ]);

  void addTask(Map<String, dynamic> task) {
    state = [...state, task];
  }

  void toggleTask(String id) {
    state = [
      for (final t in state)
        if (t['id'] == id)
          {...t, 'completed': !t['completed']}
        else
          t,
    ];
  }
}

// Habits State Provider (Placeholder)
final habitsProvider = StateNotifierProvider<HabitsNotifier, List<Map<String, dynamic>>>((ref) {
  return HabitsNotifier();
});

class HabitsNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  HabitsNotifier() : super([
    {'id': '1', 'name': 'Read 10 Pages', 'category': 'Study', 'streak': 5, 'completedToday': true},
    {'id': '2', 'name': 'Morning Meditation', 'category': 'Mind', 'streak': 8, 'completedToday': false},
    {'id': '3', 'name': 'Gym / Workout', 'category': 'Fitness', 'streak': 3, 'completedToday': true},
  ]);

  void toggleHabit(String id) {
    state = [
      for (final h in state)
        if (h['id'] == id)
          {...h, 'completedToday': !h['completedToday']}
        else
          h,
    ];
  }
}

// Money State Provider (Placeholder)
final moneyProvider = StateNotifierProvider<MoneyNotifier, List<Map<String, dynamic>>>((ref) {
  return MoneyNotifier();
});

class MoneyNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  MoneyNotifier() : super([
    {'id': '1', 'title': 'Salary Deposit', 'category': 'Salary', 'amount': 300.00, 'isIncome': true},
    {'id': '2', 'title': 'Grocery Shopping', 'category': 'Food', 'amount': -42.50, 'isIncome': false},
    {'id': '3', 'title': 'Gas Station', 'category': 'Fuel', 'amount': -35.00, 'isIncome': false},
    {'id': '4', 'title': 'Movie Tickets', 'category': 'Entertainment', 'amount': -24.00, 'isIncome': false},
  ]);

  void addTransaction(Map<String, dynamic> tx) {
    state = [tx, ...state];
  }
}

// Notifications Configuration State Provider (Placeholder)
final notificationsSettingsProvider = StateProvider<Map<String, bool>>((ref) {
  return {
    'taskReminders': true,
    'habitReminders': true,
    'moneyReminders': true,
  };
});

// Global Settings State Provider (Placeholder)
final settingsProvider = StateProvider<Map<String, dynamic>>((ref) {
  return {
    'userDisplayName': 'User',
    'syncOfflineCache': true,
    'backupEnabled': true,
  };
});
