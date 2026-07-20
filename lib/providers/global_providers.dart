import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
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

// Habit Repository Provider
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository();
});

// Habits State Provider
final habitsProvider = StateNotifierProvider<HabitsNotifier, List<Habit>>((ref) {
  final repo = ref.watch(habitRepositoryProvider);
  return HabitsNotifier(repo);
});

class HabitsNotifier extends StateNotifier<List<Habit>> {
  final HabitRepository _repository;

  HabitsNotifier(this._repository) : super([]) {
    _loadHabits();
  }

  void _loadHabits() {
    state = _repository.getHabits();
    _updateReminder();
    syncHabits();
  }

  Future<void> syncHabits() async {
    await _repository.syncPending();
    state = _repository.getHabits();
    _updateReminder();
  }

  Future<void> addHabit(Habit habit) async {
    await _repository.saveHabit(habit);
    state = _repository.getHabits();
    _updateReminder();
  }

  Future<void> updateHabit(Habit habit) async {
    await _repository.saveHabit(habit);
    state = _repository.getHabits();
    _updateReminder();
  }

  Future<void> deleteHabit(String id) async {
    await _repository.deleteHabit(id);
    state = _repository.getHabits();
    _updateReminder();
  }

  void _updateReminder() {
    final habits = _repository.getHabits();
    final entries = _repository.getEntries();
    
    final dailyHabits = habits.where((h) => h.goalType == 'Daily').toList();
    if (dailyHabits.isEmpty) {
      NotificationService().cancelEveningReminder();
      return;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int incompleteCount = 0;
    for (final habit in dailyHabits) {
      final completed = entries.any(
        (e) => e.habitId == habit.id && e.dateStr == todayStr && e.completed,
      );
      if (!completed) {
        incompleteCount++;
      }
    }

    NotificationService().scheduleEveningReminder(incompleteCount);
  }
}

// Habit Entries State Provider
final habitEntriesProvider = StateNotifierProvider<HabitEntriesNotifier, List<HabitEntry>>((ref) {
  final repo = ref.watch(habitRepositoryProvider);
  return HabitEntriesNotifier(repo);
});

class HabitEntriesNotifier extends StateNotifier<List<HabitEntry>> {
  final HabitRepository _repository;

  HabitEntriesNotifier(this._repository) : super([]) {
    _loadEntries();
  }

  void _loadEntries() {
    state = _repository.getEntries();
    _updateReminder();
  }

  Future<void> toggleEntry(String habitId, String dateStr, bool completed) async {
    await _repository.toggleEntry(habitId, dateStr, completed);
    state = _repository.getEntries();
    _updateReminder();
  }

  void _updateReminder() {
    final habits = _repository.getHabits();
    final entries = _repository.getEntries();
    
    final dailyHabits = habits.where((h) => h.goalType == 'Daily').toList();
    if (dailyHabits.isEmpty) {
      NotificationService().cancelEveningReminder();
      return;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int incompleteCount = 0;
    for (final habit in dailyHabits) {
      final completed = entries.any(
        (e) => e.habitId == habit.id && e.dateStr == todayStr && e.completed,
      );
      if (!completed) {
        incompleteCount++;
      }
    }

    NotificationService().scheduleEveningReminder(incompleteCount);
  }
}

// Helper to calculate habit metrics
Map<String, dynamic> getHabitMetrics(String habitId, List<HabitEntry> entries, DateTime createdAt) {
  final habitEntries = entries
      .where((e) => e.habitId == habitId && e.completed)
      .toList();
      
  final completedDates = habitEntries
      .map((e) {
        try {
          return DateTime.parse(e.dateStr);
        } catch (_) {
          return null;
        }
      })
      .whereType<DateTime>()
      .map((d) => DateTime(d.year, d.month, d.day))
      .toList();

  completedDates.sort((a, b) => b.compareTo(a));

  if (completedDates.isEmpty) {
    return {
      'currentStreak': 0,
      'longestStreak': 0,
      'completionRate': 0.0,
    };
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  int currentStreak = 0;
  DateTime checkDate = today;

  if (!completedDates.contains(today) && !completedDates.contains(yesterday)) {
    currentStreak = 0;
  } else {
    checkDate = completedDates.contains(today) ? today : yesterday;
    while (completedDates.contains(checkDate)) {
      currentStreak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
  }

  final chronological = List<DateTime>.from(completedDates)..sort();
  int longestStreak = 0;
  int currentRun = 0;
  DateTime? prevDate;

  for (final date in chronological) {
    if (prevDate == null) {
      currentRun = 1;
    } else {
      final diff = date.difference(prevDate).inDays;
      if (diff == 1) {
        currentRun++;
      } else if (diff > 1) {
        if (currentRun > longestStreak) {
          longestStreak = currentRun;
        }
        currentRun = 1;
      }
    }
    prevDate = date;
  }
  if (currentRun > longestStreak) {
    longestStreak = currentRun;
  }

  final createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final totalDays = today.difference(createdDate).inDays + 1;
  final double rate = (completedDates.length / totalDays).clamp(0.0, 1.0);

  return {
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'completionRate': rate,
  };
}

// Money Repository Provider
final moneyRepositoryProvider = Provider<MoneyRepository>((ref) {
  return MoneyRepository();
});

// Current Month Helper Provider ("yyyy-MM")
final currentMonthProvider = Provider<String>((ref) {
  return DateFormat('yyyy-MM').format(DateTime.now());
});

// Monthly Budget State Notifier Provider
final monthlyBudgetProvider = StateNotifierProvider<MonthlyBudgetNotifier, double>((ref) {
  final repo = ref.watch(moneyRepositoryProvider);
  final month = ref.watch(currentMonthProvider);
  return MonthlyBudgetNotifier(repo, month);
});

class MonthlyBudgetNotifier extends StateNotifier<double> {
  final MoneyRepository _repository;
  final String _currentMonth;

  MonthlyBudgetNotifier(this._repository, this._currentMonth) : super(0.0) {
    _loadBudget();
  }

  void _loadBudget() {
    state = _repository.getMonthlyBudget(_currentMonth);
  }

  Future<void> setBudget(double amount) async {
    await _repository.saveMonthlyBudget(_currentMonth, amount);
    state = _repository.getMonthlyBudget(_currentMonth);
  }
}

// Money Transactions State Notifier Provider
final moneyProvider = StateNotifierProvider<MoneyNotifier, List<Transaction>>((ref) {
  final repo = ref.watch(moneyRepositoryProvider);
  return MoneyNotifier(repo);
});

class MoneyNotifier extends StateNotifier<List<Transaction>> {
  final MoneyRepository _repository;

  MoneyNotifier(this._repository) : super([]) {
    _loadTransactions();
  }

  void _loadTransactions() {
    state = _repository.getTransactions();
    syncTransactions();
  }

  Future<void> syncTransactions() async {
    await _repository.syncPending();
    state = _repository.getTransactions();
  }

  Future<void> addTransaction(Transaction tx) async {
    await _repository.saveTransaction(tx);
    state = _repository.getTransactions();
  }

  Future<void> updateTransaction(Transaction tx) async {
    await _repository.saveTransaction(tx);
    state = _repository.getTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await _repository.deleteTransaction(id);
    state = _repository.getTransactions();
  }
}

// Dashboard State Provider
final dashboardProvider = Provider<Map<String, dynamic>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final completedTasks = tasks.where((t) => t.completed).length;
  final totalTasks = tasks.length;

  final habits = ref.watch(habitsProvider);
  final entries = ref.watch(habitEntriesProvider);

  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final completedHabits = entries.where((e) => e.dateStr == todayStr && e.completed).length;
  final totalHabits = habits.length;

  int maxStreak = 0;
  for (final h in habits) {
    final metrics = getHabitMetrics(h.id, entries, h.createdAt);
    final streak = metrics['currentStreak'] as int;
    if (streak > maxStreak) {
      maxStreak = streak;
    }
  }

  // Dynamic Money calculations
  final transactions = ref.watch(moneyProvider);
  final currentMonth = ref.watch(currentMonthProvider);
  final monthlyBudget = ref.watch(monthlyBudgetProvider);

  double totalIncome = 0.0;
  double totalExpenses = 0.0;

  for (final tx in transactions) {
    final txMonthStr = DateFormat('yyyy-MM').format(tx.date);
    if (txMonthStr == currentMonth) {
      if (tx.type == 'Income') {
        totalIncome += tx.amount;
      } else {
        totalExpenses += tx.amount;
      }
    }
  }

  final remainingBudget = monthlyBudget + totalIncome - totalExpenses;

  return {
    'completedTasks': completedTasks,
    'totalTasks': totalTasks,
    'completedHabits': completedHabits,
    'totalHabits': totalHabits,
    'remainingBudget': remainingBudget,
    'totalBudget': monthlyBudget,
    'streakDays': maxStreak,
  };
});

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
