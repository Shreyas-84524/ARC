# Project Arc — Money Tracker: Income & Monthly Budget Separation Report

**Date:** 2026-08-11  
**Status:** ✅ Completed & Fully Verified  

---

## 1. Root Cause of Previous Behavior

Previously, in both `MoneyScreen` (`lib/features/money_tracker/screens/money_screen.dart` line 176) and `DashboardRepository` (`lib/features/dashboard/repository/dashboard_repository.dart` line 67), the remaining monthly spending budget was calculated using the formula:

$$\text{remainingBudget} = \text{monthlyBudget} + \text{totalIncome} - \text{totalExpenses}$$

This formula incorrectly added `totalIncome` directly into the remaining monthly spending budget, causing income transactions to automatically increase the configured monthly budget limit and remaining spending allocation.

---

## 2. Files Inspected

1. [money_screen.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/money_tracker/screens/money_screen.dart)
2. [dashboard_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/dashboard/repository/dashboard_repository.dart)
3. [money_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/money_tracker/repository/money_repository.dart)
4. [monthly_summary_model.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/money_tracker/models/monthly_summary_model.dart)
5. [global_providers.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/providers/global_providers.dart)
6. [transaction_editor_sheet.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/money_tracker/widgets/transaction_editor_sheet.dart)

---

## 3. Files Modified

1. [money_screen.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/money_tracker/screens/money_screen.dart)
2. [dashboard_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/dashboard/repository/dashboard_repository.dart)
3. [money_income_budget_separation_test.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/test/money_income_budget_separation_test.dart) *(New unit test file)*

---

## 4. Exact Logic Changed

- **In `money_screen.dart`**:
  - Changed:
    ```dart
    // BEFORE:
    final double remainingBudget = monthlyBudget + totalIncome - totalExpenses;
    
    // AFTER:
    final double remainingBudget = monthlyBudget - totalExpenses;
    ```
- **In `dashboard_repository.dart`**:
  - Changed:
    ```dart
    // BEFORE:
    final remainingBudget = monthlyBudget + totalIncome - totalExpenses;
    
    // AFTER:
    final remainingBudget = monthlyBudget - totalExpenses;
    ```

---

## 5. Confirmation: Income & Monthly Budget Separation

- **Monthly Budget** remains an independent value configured by the user (`monthlyBudget`).
- **Remaining Monthly Spending Budget** equals $\text{monthlyBudget} - \text{totalExpenses}$.
- Adding, editing, or deleting Income transactions has **ZERO** impact on `monthlyBudget` or `remainingBudget`.

---

## 6. Confirmation: Income Statistics & Cash-Flow

- Income/Credit transactions continue to function as expected:
  - Stored in Hive (`Transaction` box) & Firestore (`users/{uid}/transactions`).
  - Rendered in Transaction History.
  - Displayed in **Total Income** stat card (`_buildBudgetStat`).
  - Rendered in **Total Monthly Income** summary row in Analytics tab.
  - Included in **Savings ($\text{Income} - \text{Expense}$)** calculations.
  - Rendered in **Savings Rate** circular progress indicator.
  - Rendered in **Income vs Expense Compare** bar chart.

---

## 7. Confirmation: Donut Chart (Budget vs Expenses Only)

- Donut chart enforces $100\% = \text{Monthly Budget}$.
- Donut chart displays:
  - 🟢 Remaining Budget unspent ($\text{monthlyBudget} - \text{totalExpenses}$)
  - 🔴 Expense Categories
- Income is **NOT** included in the donut chart slices or percentages.

---

## 8. Hive Impact

- **Zero schema or storage changes**.
- Hive `_settingsBox` continues storing `budget_yyyy-MM` as a standalone float value.
- Hive `_txBox` continues storing all `Transaction` models.

---

## 9. Firestore Impact

- **Zero path or rules changes**.
- Firestore `users/{uid}/budgets/{yyyy-MM}` stores budget documents.
- Firestore `users/{uid}/transactions/{id}` stores transactions.

---

## 10. Data Preservation Verification

- Existing transactions, budgets, monthly summaries, and settings remain 100% intact.
- No destructive migrations or document deletions performed.

---

## 11. Test Results

### `flutter analyze`
```
Analyzing arc...
No issues found! (ran in 10.3s)
```

### `flutter test`
```
00:11 +96: All tests passed!
```
Includes tests for all 7 required test scenarios:
- **TEST 1**: Set budget ₹20,000 + Add ₹5,000 income $\rightarrow$ Budget remains ₹20,000, Remaining budget = ₹20,000.
- **TEST 2**: Budget ₹20,000 + Income ₹10,000 + Expense ₹5,000 $\rightarrow$ Remaining budget = ₹15,000 (20,000 - 5,000).
- **TEST 3**: Edit income from ₹10,000 to ₹15,000 $\rightarrow$ Budget remains ₹20,000, Remaining budget = ₹15,000.
- **TEST 4**: Delete income transaction $\rightarrow$ Budget remains ₹20,000, Remaining budget = ₹15,000.
- **TEST 5**: Spend full ₹20,000 budget $\rightarrow$ Remaining budget = ₹0 (100% used).
- **TEST 6**: Over-budget spending ₹22,000 $\rightarrow$ Remaining budget = -₹2,000 (Over-budget behavior preserved).
- **TEST 7**: Donut analytics calculation $\rightarrow$ Income ₹50,000 does not affect 90% budget used calculation.

### `flutter build apk --debug`
```
Building APK...
Running Gradle task 'assembleDebug'... 24.8s
✓ Built build\app\outputs\flutter-apk\app-debug.apk.
```

---

## 12. Remaining Warnings / Limitations

None. All constraints and requirements satisfied cleanly.
