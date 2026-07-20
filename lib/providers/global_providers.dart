import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/core/notifications/notification_service.dart';

// Theme Mode Provider (Light vs Dark)
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.dark; // Default to dark mode as per design.md
});

// Task Repository Provider
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

// Tasks State Notifier Provider
final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return TasksNotifier(repository);
});

class TasksNotifier extends StateNotifier<List<Task>> {
  final TaskRepository _repository;

  TasksNotifier(this._repository) : super([]) {
    _loadTasks();
  }

  void _loadTasks() {
    state = _repository.getTasks();
    syncTasks();
  }

  Future<void> syncTasks() async {
    await _repository.syncPending();
    state = _repository.getTasks(); // Refresh state if any tasks synced
  }

  Future<void> addTask(Task task) async {
    await _repository.saveTask(task);
    await NotificationService().scheduleTaskReminders(task);
    state = _repository.getTasks();
  }

  Future<void> updateTask(Task task) async {
    await _repository.saveTask(task);
    await NotificationService().cancelTaskReminders(task.id);
    await NotificationService().scheduleTaskReminders(task);
    state = _repository.getTasks();
  }

  Future<void> toggleTask(String id) async {
    final task = state.firstWhere((t) => t.id == id);
    final updatedTask = task.copyWith(
      completed: !task.completed,
      updatedAt: DateTime.now(),
    );
    await _repository.saveTask(updatedTask);
    
    if (updatedTask.completed) {
      await NotificationService().cancelTaskReminders(task.id);
    } else {
      await NotificationService().scheduleTaskReminders(updatedTask);
    }
    
    state = _repository.getTasks();
  }

  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
    await NotificationService().cancelTaskReminders(id);
    state = _repository.getTasks();
  }
}

// Search Query Provider
final taskSearchQueryProvider = StateProvider<String>((ref) => '');

// Filter Category Provider (null means "All")
final taskCategoryFilterProvider = StateProvider<String?>((ref) => null);

// Filter Priority Provider (null means "All")
final taskPriorityFilterProvider = StateProvider<String?>((ref) => null);

// Filter Status Provider ('All', 'Pending', 'Completed')
final taskStatusFilterProvider = StateProvider<String>((ref) => 'All');

// Filter Date Provider ('All', 'Today', 'Upcoming')
final taskDateFilterProvider = StateProvider<String>((ref) => 'All');

// Sorting Provider ('DueDate', 'Priority', 'CreationDate')
final taskSortProvider = StateProvider<String>((ref) => 'DueDate');

// Filtered and Sorted Tasks Selector Provider
final filteredTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final query = ref.watch(taskSearchQueryProvider).toLowerCase();
  final category = ref.watch(taskCategoryFilterProvider);
  final priority = ref.watch(taskPriorityFilterProvider);
  final status = ref.watch(taskStatusFilterProvider);
  final dateFilter = ref.watch(taskDateFilterProvider);
  final sortBy = ref.watch(taskSortProvider);

  List<Task> filtered = List.from(tasks);

  // 1. Text Search Filter
  if (query.isNotEmpty) {
    filtered = filtered.where((task) {
      final titleMatch = task.title.toLowerCase().contains(query);
      final descMatch = task.description.toLowerCase().contains(query);
      final labelMatch = task.labels.any((l) => l.toLowerCase().contains(query));
      return titleMatch || descMatch || labelMatch;
    }).toList();
  }

  // 2. Category Filter
  if (category != null) {
    filtered = filtered.where((task) => task.category == category).toList();
  }

  // 3. Priority Filter
  if (priority != null) {
    filtered = filtered.where((task) => task.priority == priority).toList();
  }

  // 4. Status Filter
  if (status == 'Pending') {
    filtered = filtered.where((task) => !task.completed).toList();
  } else if (status == 'Completed') {
    filtered = filtered.where((task) => task.completed).toList();
  }

  // 5. Date Filter
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

  if (dateFilter == 'Today') {
    filtered = filtered.where((task) {
      if (task.dueDate == null) return false;
      return task.dueDate!.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
          task.dueDate!.isBefore(todayEnd.add(const Duration(seconds: 1)));
    }).toList();
  } else if (dateFilter == 'Upcoming') {
    filtered = filtered.where((task) {
      if (task.dueDate == null) return false;
      return task.dueDate!.isAfter(todayEnd);
    }).toList();
  }

  // 6. Sorting
  if (sortBy == 'DueDate') {
    filtered.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      final dateComparison = a.dueDate!.compareTo(b.dueDate!);
      if (dateComparison != 0) return dateComparison;
      if (a.dueTime == null && b.dueTime == null) return 0;
      if (a.dueTime == null) return 1;
      if (b.dueTime == null) return -1;
      return a.dueTime!.compareTo(b.dueTime!);
    });
  } else if (sortBy == 'Priority') {
    filtered.sort((a, b) {
      final pA = _priorityValue(a.priority);
      final pB = _priorityValue(b.priority);
      return pB.compareTo(pA); // High priority first
    });
  } else if (sortBy == 'CreationDate') {
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
  }

  return filtered;
});

int _priorityValue(String priority) {
  switch (priority) {
    case 'High':
      return 3;
    case 'Much':
      return 2;
    case 'Low':
    default:
      return 1;
  }
}

// Dashboard State Provider
final dashboardProvider = Provider<Map<String, dynamic>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final completedTasks = tasks.where((t) => t.completed).length;
  final totalTasks = tasks.length;

  return {
    'completedTasks': completedTasks,
    'totalTasks': totalTasks,
    'completedHabits': 2,
    'totalHabits': 4,
    'remainingBudget': 420.50,
    'totalBudget': 800.00,
    'streakDays': 8,
  };
});

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
