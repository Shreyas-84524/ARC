import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/models/monthly_summary_model.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/settings/models/settings_model.dart';
import 'package:arc/features/settings/repository/settings_repository.dart';
import 'package:arc/features/dashboard/repository/dashboard_repository.dart';
import 'package:arc/core/services/sync_service.dart';
import 'package:arc/core/notifications/notification_service.dart';

// Settings Repository Provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

// App Settings State Notifier Provider
final appSettingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsModel>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo);
});

class SettingsNotifier extends StateNotifier<SettingsModel> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository) : super(_repository.getSettings());

  Future<void> updateSettings(SettingsModel settings) async {
    state = settings;
    await _repository.saveSettings(settings);
  }

  Future<void> updateThemeMode(bool isDarkMode) async {
    final updated = state.copyWith(isDarkMode: isDarkMode);
    state = updated;
    await _repository.saveSettings(updated);
  }
}

// Theme Mode Provider (Reads from AppSettings)
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.isDarkMode ? ThemeMode.dark : ThemeMode.light;
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
    state = _repository.getTasks();
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
    final taskIndex = state.indexWhere((t) => t.id == id);
    if (taskIndex == -1) return;
    final task = state[taskIndex];

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

  if (query.isNotEmpty) {
    filtered = filtered.where((task) {
      final titleMatch = task.title.toLowerCase().contains(query);
      final descMatch = task.description.toLowerCase().contains(query);
      final labelMatch = task.labels.any((l) => l.toLowerCase().contains(query));
      return titleMatch || descMatch || labelMatch;
    }).toList();
  }

  if (category != null) {
    filtered = filtered.where((task) => task.category == category).toList();
  }

  if (priority != null) {
    filtered = filtered.where((task) => task.priority == priority).toList();
  }

  if (status == 'Pending') {
    filtered = filtered.where((task) => !task.completed).toList();
  } else if (status == 'Completed') {
    filtered = filtered.where((task) => task.completed).toList();
  }

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
      return pB.compareTo(pA);
    });
  } else if (sortBy == 'CreationDate') {
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  } else if (sortBy == 'Alphabetical') {
    filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  return filtered;
});

// Task Statistics Selector Provider
final taskStatisticsProvider = Provider<Map<String, dynamic>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final totalTasks = tasks.length;
  final completedTasks = tasks.where((t) => t.completed).length;
  final pendingTasks = totalTasks - completedTasks;
  final completionRate = totalTasks == 0 ? 0.0 : (completedTasks / totalTasks);

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

  final todayTasks = tasks.where((t) {
    if (t.dueDate == null) return false;
    return t.dueDate!.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
        t.dueDate!.isBefore(todayEnd.add(const Duration(seconds: 1)));
  }).length;

  final overdueTasks = tasks.where((t) {
    if (t.completed || t.dueDate == null) return false;
    return t.dueDate!.isBefore(todayStart);
  }).length;

  final upcomingTasks = tasks.where((t) {
    if (t.completed || t.dueDate == null) return false;
    return t.dueDate!.isAfter(todayEnd);
  }).length;

  return {
    'totalTasks': totalTasks,
    'completedTasks': completedTasks,
    'pendingTasks': pendingTasks,
    'completionPercentage': (completionRate * 100).round(),
    'todayTasks': todayTasks,
    'overdueTasks': overdueTasks,
    'upcomingTasks': upcomingTasks,
  };
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
final habitEntriesProvider =
    StateNotifierProvider<HabitEntriesNotifier, List<HabitEntry>>((ref) {
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
Map<String, dynamic> getHabitMetrics(
    String habitId, List<HabitEntry> entries, DateTime createdAt) {
  final habitEntries =
      entries.where((e) => e.habitId == habitId && e.completed).toList();

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
  final double rate = (completedDates.length / (totalDays <= 0 ? 1 : totalDays))
      .clamp(0.0, 1.0);

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
final monthlyBudgetProvider =
    StateNotifierProvider<MonthlyBudgetNotifier, double>((ref) {
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
    _syncSummary();
  }

  void _syncSummary() {
    final transactions = _repository.getTransactions();
    _saveSummaryHelper(_repository, _currentMonth, state, transactions);
  }
}

// Money Transactions State Notifier Provider
final moneyProvider =
    StateNotifierProvider<MoneyNotifier, List<Transaction>>((ref) {
  final repo = ref.watch(moneyRepositoryProvider);
  final month = ref.watch(currentMonthProvider);
  final budget = ref.watch(monthlyBudgetProvider);
  return MoneyNotifier(repo, month, budget);
});

class MoneyNotifier extends StateNotifier<List<Transaction>> {
  final MoneyRepository _repository;
  final String _currentMonth;
  final double _currentBudget;

  MoneyNotifier(this._repository, this._currentMonth, this._currentBudget)
      : super([]) {
    _loadTransactions();
  }

  void _loadTransactions() {
    state = _repository.getTransactions();
    _updateReminders();
    _syncSummary();
    syncTransactions();
  }

  Future<void> syncTransactions() async {
    await _repository.syncPending();
    state = _repository.getTransactions();
    _updateReminders();
    _syncSummary();
  }

  Future<void> addTransaction(Transaction tx) async {
    await _repository.saveTransaction(tx);
    state = _repository.getTransactions();
    _updateReminders();
    _syncSummary();
  }

  Future<void> updateTransaction(Transaction tx) async {
    await _repository.saveTransaction(tx);
    state = _repository.getTransactions();
    _updateReminders();
    _syncSummary();
  }

  Future<void> deleteTransaction(String id) async {
    await _repository.deleteTransaction(id);
    state = _repository.getTransactions();
    _updateReminders();
    _syncSummary();
  }

  void _updateReminders() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final hasTodayTx =
        state.any((tx) => DateFormat('yyyy-MM-dd').format(tx.date) == todayStr);
    NotificationService().scheduleDailyMoneyReminders(hasTodayTx: hasTodayTx);
  }

  void _syncSummary() {
    _saveSummaryHelper(_repository, _currentMonth, _currentBudget, state);
  }
}

void _saveSummaryHelper(MoneyRepository repository, String month, double budget, List<Transaction> transactions) {
  double income = 0.0;
  double expenses = 0.0;

  for (final tx in transactions) {
    final txMonth = DateFormat('yyyy-MM').format(tx.date);
    if (txMonth == month) {
      if (tx.type == 'Income') {
        income += tx.amount;
      } else {
        expenses += tx.amount;
      }
    }
  }

  final summary = MonthlySummary(
    month: month,
    monthlyBudget: budget,
    totalIncome: income,
    totalExpenses: expenses,
    savings: income - expenses,
    updatedAt: DateTime.now(),
  );

  repository.saveMonthlySummary(summary);
}

// Sync Service Provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final taskRepo = ref.watch(taskRepositoryProvider);
  final habitRepo = ref.watch(habitRepositoryProvider);
  final moneyRepo = ref.watch(moneyRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);

  return SyncService(
    taskRepository: taskRepo,
    habitRepository: habitRepo,
    moneyRepository: moneyRepo,
    settingsRepository: settingsRepo,
  );
});

// Dashboard Repository Provider
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    taskRepository: ref.watch(taskRepositoryProvider),
    habitRepository: ref.watch(habitRepositoryProvider),
    moneyRepository: ref.watch(moneyRepositoryProvider),
  );
});

// Dashboard State Provider
final dashboardProvider = Provider<Map<String, dynamic>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final currentMonth = ref.watch(currentMonthProvider);
  return repo.getDashboardData(currentMonth);
});
