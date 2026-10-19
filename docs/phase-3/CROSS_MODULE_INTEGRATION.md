# Cross-Module Financial & Dashboard Integration

## 1. Overview

Phase 3 establishes full cross-module integration between the **Money Manager**, the **Productivity Dashboard**, and the existing **Tasks** and **Habits** engines. Financial metrics are surfaced directly on the home dashboard, and financial transactions appear in the centralized activity feed alongside task completions and habit check-ins.

---

## 2. Integration Architecture

### 2.1 Reactive State Aggregation in DashboardViewModel
`DashboardViewModel` combines five independent reactive data streams using Kotlin Coroutines `combine`:

```kotlin
combine(
    taskRepository.getTasksFlow(userId),
    habitRepository.getHabitsFlow(userId),
    habitRepository.getEntriesFlow(userId),
    transactionsFlow,
    budgetFlow,
) { tasks, habits, entries, transactions, budget ->
    // 1. Task metrics & completion
    // 2. Habit streaks & today check-ins
    // 3. Monthly expenses & budget calculations
    // 4. Productivity score (0–100)
    // 5. Upcoming deadlines
    // 6. Chronologically sorted recent activity feed
}
```

### 2.2 Financial State in DashboardUiState
```kotlin
data class DashboardUiState(
    // ... Productivity fields ...
    val monthlyBudgetPaise: Long = 0L,
    val monthlyExpensesPaise: Long = 0L,
    val remainingBudgetPaise: Long = 0L,
    // ... Lists & status ...
)
```

### 2.3 Financial Dashboard Card
`DashboardScreen` renders a prominent `FinancialDashboardCard` between the task checklist and upcoming deadlines:
- **Spent this month:** Formatted in INR via `CurrencyFormatter.formatPaise(monthlyExpensesPaise)`.
- **Remaining budget:** Color-coded in `ArcTheme.colors.success` (when within budget) or `ArcTheme.colors.danger` (when over budget).
- **Linear Progress Bar:** Visualizes budget consumption percentage.
- **One-tap Navigation:** Clicking anywhere on the card or the "View" action triggers `onNavigateToMoney()`, seamlessly selecting `ArcNavTab.MONEY` in `MainShellScreen`.

### 2.4 Unified Activity Feed
`DashboardActivityItem` supports three distinct domain event types:
- `DashboardActivityType.TASK`: Checkbox icon (`#1890FF`).
- `DashboardActivityType.HABIT`: Flame icon (`#F97316`).
- `DashboardActivityType.TRANSACTION`: Currency wallet icon (`#10B981`).

All events are merged into a single list and sorted in reverse chronological order:
`activities.sortByDescending { it.timestamp }`

---

## 3. End-to-End Test Verification

Validated by `OfflineFinancialIntegrationTest.kt` across 5 test suites:
1. `crossModule_whenFinancialDataPresent_dashboardAggregatesExpensesAndBudgetAccurately()`
2. `crossModule_whenOverBudget_dashboardCalculatesNegativeRemainingBudget()`
3. `crossModule_activityFeedCombinesTasksHabitsAndTransactionsInChronologicalOrder()`
4. `multiUserIsolation_financesRemainStrictlyIsolatedAcrossUsers()`
5. `transactionDeletion_immediatelyUpdatesDashboardTotals()`
