# Project Arc — Source Code & Architecture Guide

> **Version:** 1.0.0 (Production Release)  
> **Document Purpose:** Complete codebase documentation, folder structure, module responsibilities, widget hierarchy, and data flow.

---

## 1. Directory Structure

```
lib/
├── core/
│   ├── constants/       # App-wide constants (app_constants.dart)
│   ├── notifications/   # Local notification scheduling engine (notification_service.dart)
│   ├── services/        # Background Cloud Firestore synchronization (sync_service.dart)
│   ├── theme/          # Color tokens, typography, dark/light theme definitions (app_theme.dart)
│   └── widgets/        # Shared core UI widgets (top_bar.dart, empty_state.dart, skeleton_loader.dart)
├── features/
│   ├── dashboard/       # Dashboard screen, metrics aggregation, shell navigation (dashboard_screen.dart, shell_screen.dart, dashboard_repository.dart)
│   ├── task_manager/    # Task CRUD, filters, sorting, statistics, editor modal (tasks_screen.dart, task_model.dart, task_repository.dart, task_editor_sheet.dart)
│   ├── habit_tracker/   # Habit CRUD, matrix grid, streaks, goal analytics (habits_screen.dart, habit_model.dart, habit_entry_model.dart, habit_repository.dart, habit_editor_sheet.dart)
│   ├── money_tracker/   # Budget limits, transaction CRUD, monthly summaries, analytics (money_screen.dart, transaction_model.dart, monthly_summary_model.dart, money_repository.dart, transaction_editor_sheet.dart)
│   ├── search/          # Real-time multi-module search (global_search_screen.dart)
│   ├── notifications/   # In-app Notification Center (notification_center_screen.dart)
│   └── settings/        # App preferences, theme mode, storage diagnostics, backup (settings_screen.dart, settings_model.dart, settings_repository.dart)
├── providers/           # Central Riverpod provider definitions (global_providers.dart)
├── routes/              # GoRouter route declarations & navigation keys (app_router.dart)
└── main.dart            # Main entry point, Hive initialization & app bootstrapping
```

---

## 2. Module Responsibilities & Relationships

### Task Manager (`lib/features/task_manager/`)
- **Responsibilities**: Manages task items with priority (`Low`, `Medium`, `High`, `Much`), due dates, due times, categories, labels, and 3-tier notifications.
- **Data Model**: `Task` (Hive Type ID `1`).
- **Persistence**: Writes to Hive `tasks_box` instantly and queues mutations in `sync_queue_box`.

### Habit Tracker (`lib/features/habit_tracker/`)
- **Responsibilities**: Manages habit routines with goal types (`Daily`, `Weekly`, `Monthly`), 7-day matrix check-in grid, current/longest streak engine, and goal type pie chart analytics.
- **Data Models**: `Habit` (Hive Type ID `2`), `HabitEntry` (Hive Type ID `3`).
- **Persistence**: Writes to Hive `habits_box` and `habit_entries_box`.

### Money Tracker (`lib/features/money_tracker/`)
- **Responsibilities**: Manages income/expense transactions, monthly budget caps (`budget_yyyy-MM`), dynamic balance calculation (`Remaining = Budget + Income - Expenses`), monthly summary archiving, and 4 animated analytics charts.
- **Data Models**: `Transaction` (Hive Type ID `4`), `MonthlySummary` (Hive Type ID `5`).
- **Persistence**: Writes to Hive `transactions_box` and `settings_box`.

### Dashboard (`lib/features/dashboard/`)
- **Responsibilities**: Aggregates metrics from Task, Habit, and Money modules without embedding business logic. Displays Progress Ring, Productivity Score (0-100), Metric Cards, 10-Item Recent Activity Feed, and FAB Quick Actions.

---

## 3. Data Flow Architecture

```
[ User Action / UI ] 
        │
        ▼ (StateNotifier Action)
[ Riverpod StateNotifier ] 
        │
        ├──────────────────────────────────────┐
        ▼ (Instant Read/Write)                 ▼ (Background Queue)
[ Local Hive Encrypted Box ]          [ Hive sync_queue_box ]
        │                                      │
        ▼                                      ▼ (Batch Execution)
[ UI Rebuild via Riverpod ]           [ SyncService ──► Cloud Firestore ]
```
