# Financial Intelligence Engine & Budget Analytics

## 1. Overview

The `FinancialAnalyticsEngine` (`com.arc.arc.features.money.engine.FinancialAnalyticsEngine`) is a deterministic financial intelligence engine that operates exclusively on integer minor units (`Long` paise). It analyzes raw transactional flows and generates actionable budgeting insights, spending projections, velocity tracking, and financial health scores.

---

## 2. Core Metrics & Mathematical Formulations

### 2.1 Net Cashflow & Savings Rate
$$\text{NetCashflowPaise} = \text{TotalIncomePaise} - \text{TotalExpensesPaise}$$

$$\text{SavingsRatePercentage} = \begin{cases} \left( \frac{\text{NetCashflowPaise}}{\text{TotalIncomePaise}} \right) \times 100.0 & \text{if } \text{TotalIncomePaise} > 0 \\ 0.0 & \text{otherwise} \end{cases}$$

### 2.2 Burn Rate (Daily Spending Velocity)
Computes the daily average expenditure for the current month:
$$\text{ElapsedDays} = \min(\text{CurrentDayOfMonth}, \text{DaysInMonth})$$
$$\text{DailyBurnRatePaise} = \frac{\text{TotalExpensesPaise}}{\max(1, \text{ElapsedDays})}$$

### 2.3 Projected Month-End Spend
Extrapolates total expenditure through the end of the month based on the observed daily burn rate:
$$\text{RemainingDaysInMonth} = \max(0, \text{DaysInMonth} - \text{ElapsedDays})$$
$$\text{ProjectedMonthEndSpendPaise} = \text{TotalExpensesPaise} + (\text{DailyBurnRatePaise} \times \text{RemainingDaysInMonth})$$

### 2.4 Budget Pace Classification
Evaluates whether current spending trajectories risk exceeding the allocated budget:
```kotlin
enum class BudgetPace {
    ON_TRACK,   // Projected spend <= budget
    AT_RISK,    // Projected spend > budget, but current spend <= budget
    EXCEEDED,   // Current spend > budget
    NO_BUDGET,  // No monthly budget defined
}
```

### 2.5 Category Contribution Breakdown
Aggregates expenses by category, sorting categories by expenditure descending and computing relative percentages:
$$\text{CategoryPercentage} = \left( \frac{\text{CategoryExpensesPaise}}{\text{TotalExpensesPaise}} \right) \times 100.0$$

### 2.6 Day-of-Week Spending Heatmap
Groups expenses by day of the week (Monday through Sunday) to highlight peak spending days:
$$\text{DaySpendPaise}[day] = \sum_{\text{tx} \in \text{DayTransactions}} \text{tx.amountPaise}$$

### 2.7 Month-over-Month Comparison
Compares the current month's expenses against the preceding calendar month:
$$\text{DifferencePaise} = \text{CurrentMonthExpensesPaise} - \text{PreviousMonthExpensesPaise}$$
$$\text{PercentageChange} = \left( \frac{\text{DifferencePaise}}{\text{PreviousMonthExpensesPaise}} \right) \times 100.0$$

### 2.8 Comprehensive Financial Health Rating
Synthesizes cashflow, savings rate, budget pace, and spend ratio into a deterministic four-tier rating:

```kotlin
enum class FinancialHealthRating {
    EXCELLENT,  // Positive cashflow, savings >= 20%, budget ON_TRACK
    GOOD,       // Positive cashflow, budget ON_TRACK, savings > 0%
    MODERATE,   // Budget AT_RISK or savings rate near 0%
    CRITICAL,   // Negative cashflow, budget EXCEEDED
}
```

---

## 3. Test Coverage & Validation

The engine is validated by `FinancialAnalyticsTest.kt` across 7 test suites:
1. `calculateCashflow_positiveAndNegativeCashflow_computesAccurateTotals()`
2. `burnRateAndProjectedSpend_extrapolatesCorrectMonthEndValues()`
3. `budgetPace_evaluatesOnTrackAtRiskAndExceededAccurately()`
4. `categoryBreakdown_aggregatesAndSortsContributions()`
5. `dayOfWeekTrends_accuratelyMapsExpensesToDays()`
6. `monthOverMonth_computesAccuratePercentageVariance()`
7. `financialHealthRating_synthesizesCompositeScoreCorrectly()`
