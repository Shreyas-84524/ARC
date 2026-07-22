# Project Arc — Riverpod State Management Specification

> **Version:** 1.0.0 (Production Release)  
> **Document Purpose:** Complete specification of Riverpod provider trees, StateNotifier lifecycles, provider dependency graphs, selectors, and state rebuild optimizations.

---

## 1. Provider Tree & Architecture

All providers are declared centrally in `lib/providers/global_providers.dart` for clean dependency tracking and zero cyclic references.

```
                  ┌───────────────────────────────┐
                  │   settingsRepositoryProvider  │
                  └──────────────┬────────────────┘
                                 │
                                 ▼
                  ┌───────────────────────────────┐
                  │      appSettingsProvider      │
                  └──────────────┬────────────────┘
                                 │
                                 ▼
                  ┌───────────────────────────────┐
                  │       themeModeProvider       │
                  └───────────────────────────────┘

 ┌─────────────────────┐ ┌──────────────────────┐ ┌─────────────────────┐
 │taskRepositoryProvider│ │habitRepositoryProvider│ │moneyRepositoryProvider│
 └──────────┬──────────┘ └──────────┬───────────┘ └──────────┬──────────┘
            │                       │                        │
            ▼                       ▼                        ▼
 ┌─────────────────────┐ ┌──────────────────────┐ ┌─────────────────────┐
 │    tasksProvider    │ │    habitsProvider    │ │    moneyProvider    │
 └─────────────────────┘ └──────────────────────┘ └──────────┬──────────┘
                                                             │
                                                             ▼
                                                  ┌─────────────────────┐
                                                  │monthlyBudgetProvider│
                                                  └──────────┬──────────┘
                                                             │
                                                             ▼
                                                  ┌─────────────────────┐
                                                  │  dashboardProvider  │
                                                  └─────────────────────┘
```

---

## 2. Key Providers & Functions

### `tasksProvider`
- **Type**: `StateNotifierProvider<TasksNotifier, List<Task>>`
- **Responsibilities**: Reads tasks list from `TaskRepository`, exposes `addTask()`, `updateTask()`, `toggleTask()`, `deleteTask()`, and `syncTasks()`.

### `habitsProvider`
- **Type**: `StateNotifierProvider<HabitsNotifier, List<Habit>>`
- **Responsibilities**: Reads habits list from `HabitRepository`, exposes `addHabit()`, `updateHabit()`, `deleteHabit()`, and `syncHabits()`.

### `habitEntriesProvider`
- **Type**: `StateNotifierProvider<HabitEntriesNotifier, List<HabitEntry>>`
- **Responsibilities**: Manages habit entry check-in state, exposes `toggleEntry()`.

### `moneyProvider`
- **Type**: `StateNotifierProvider<MoneyNotifier, List<Transaction>>`
- **Responsibilities**: Reads transactions from `MoneyRepository`, exposes `addTransaction()`, `updateTransaction()`, `deleteTransaction()`, and automatically updates `MonthlySummary` and daily money reminders.

### `dashboardProvider`
- **Type**: `Provider<Map<String, dynamic>>`
- **Responsibilities**: Aggregates metrics from Task, Habit, and Money repositories for the main Dashboard screen.
