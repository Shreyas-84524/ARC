# Project Arc — API Reference

> **Version:** 1.0.0 (Production Release)  
> **Document Purpose:** Complete reference documentation for Repositories, Services, Providers, Notifiers, Models, and Utility classes.

---

## 1. Repositories

### `TaskRepository`
Located in `lib/features/task_manager/repository/task_repository.dart`.
- `List<Task> getTasks()`: Returns list of all stored tasks from `tasks_box`.
- `Future<void> saveTask(Task task)`: Saves/updates task in Hive and queues a `upsert` sync task in `sync_queue_box`.
- `Future<void> deleteTask(String id)`: Deletes task from Hive and queues a `delete` sync task in `sync_queue_box`.
- `Future<void> syncPending()`: Flushes pending task queue items to Firestore using `SyncService`.

### `HabitRepository`
Located in `lib/features/habit_tracker/repository/habit_repository.dart`.
- `List<Habit> getHabits()`: Returns list of all habits from `habits_box`.
- `List<HabitEntry> getEntries()`: Returns list of all habit entries from `habit_entries_box`.
- `Future<void> saveHabit(Habit habit)`: Saves habit in Hive and queues Firestore sync.
- `Future<void> saveEntry(HabitEntry entry)`: Saves habit check-in entry in Hive and queues Firestore sync.
- `Future<void> deleteHabit(String id)`: Deletes habit and associated entries from Hive and queues Firestore sync deletion.

### `MoneyRepository`
Located in `lib/features/money_tracker/repository/money_repository.dart`.
- `List<Transaction> getTransactions()`: Returns transactions list from `transactions_box`.
- `double getMonthlyBudget(String monthKey)`: Reads monthly budget cap for `"yyyy-MM"` from `settings_box` (defaults to `0.0`).
- `Future<void> saveMonthlyBudget(String monthKey, double amount)`: Saves budget limit for target month in Hive and queues Firestore sync.
- `Future<void> saveTransaction(Transaction tx)`: Saves transaction in Hive and queues Firestore sync.
- `Future<void> deleteTransaction(String id)`: Deletes transaction from Hive and queues Firestore sync.
- `Future<void> saveMonthlySummary(MonthlySummary summary)`: Archives monthly financial snapshot in `settings_box` and Firestore `monthlySummaries` collection.

---

## 2. Services

### `SyncService`
Located in `lib/core/services/sync_service.dart`.
- `Future<void> syncAllPending()`: Executes single-pass batch synchronization of all queued mutations across Tasks, Habits, HabitEntries, Transactions, Budgets, and MonthlySummaries to Cloud Firestore.

### `NotificationService`
Located in `lib/core/notifications/notification_service.dart`.
- `Future<void> init()`: Initializes `flutter_local_notifications` plugin and timezone database.
- `Future<void> scheduleTaskReminders(Task task)`: Schedules 1h, 30m, and due-time notifications for task.
- `Future<void> cancelTaskReminders(String taskId)`: Cancels all scheduled alerts for target task.
- `Future<void> scheduleEveningReminder(int totalHabitsCount)`: Schedules 8:00 PM evening habit check-in alert.
- `Future<void> scheduleDailyMoneyReminders({bool hasTodayTx = false})`: Schedules 8:00 PM check-in and 10:00 PM final transaction reminder (cancels 10 PM alert if `hasTodayTx == true`).

---

## 3. Global Providers (`lib/providers/global_providers.dart`)

- `tasksProvider`: StateNotifierProvider returning `List<Task>`.
- `habitsProvider`: StateNotifierProvider returning `List<Habit>`.
- `habitEntriesProvider`: StateNotifierProvider returning `List<HabitEntry>`.
- `moneyProvider`: StateNotifierProvider returning `List<Transaction>`.
- `monthlyBudgetProvider`: StateNotifierProvider returning `double` (monthly budget for active month).
- `dashboardProvider`: Provider returning `Map<String, dynamic>` aggregated metrics.
- `themeModeProvider`: Provider returning `ThemeMode`.
- `syncServiceProvider`: Provider returning `SyncService`.
