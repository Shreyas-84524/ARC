# Money Manager Implementation Architecture

## 1. Architecture Overview

The native Money Manager module in ARC-Kotlin is designed as an offline-first financial system built using:
- **Clean Architecture:** Domain (`com.arc.arc.core.model`), Data (`com.arc.arc.features.money.data`), and Presentation (`com.arc.arc.features.money.ui`).
- **Room SQLite Persistence:** Java-authored entities and DAOs (`TransactionEntity.java`, `BudgetEntity.java`) supporting reactive Kotlin Coroutines `Flow`.
- **Non-Floating-Point Financial Math:** All monetary quantities are represented and manipulated as integer minor units (`amountPaise` in `Long`, where 1 INR = 100 paise).
- **Unidirectional Data Flow (UDF):** `MoneyViewModel` combines transactions, budget, user preferences, and filter states into a single immutable `StateFlow<MoneyUiState>`.
- **Jetpack Compose Material 3:** Modern, accessible, dark-mode native UI adhering to ARC design system tokens.

---

## 2. Key Components

### 2.1 Domain Models
- `TransactionModel.kt`:
  - `id: String` (UUID)
  - `ownerUid: String`
  - `amount: Double` (preserved for backward compatibility)
  - `amountPaise: Long` (authoritative integer value: `Math.round(amount * 100.0)`)
  - `type: String` ("Income" / "Expense")
  - `category: String`
  - `date: Date`
  - `time: String`
  - `notes: String`
  - `source: String` ("manual", "sms_detected", "quick_add")
  - `automationFingerprint: String?` (SHA-256 deduplication hash)
  - `createdAt: Date`
- `BudgetModel.kt`:
  - `id: String`
  - `ownerUid: String`
  - `month: String` ("yyyy-MM")
  - `amountPaise: Long`
  - `createdAt: Date`, `updatedAt: Date`
- `MonthlySummaryModel.kt`:
  - `month: String`
  - `totalIncomePaise: Long`
  - `totalExpensesPaise: Long`
  - `budgetPaise: Long`
  - `netSavingsPaise: Long`

### 2.2 Repository Pattern
- `ITransactionRepository`:
  - `getTransactionsFlow(ownerUid: String): Flow<List<TransactionModel>>`
  - `getBudgetFlow(ownerUid: String, month: String): Flow<BudgetModel?>`
  - `getAllBudgetsFlow(ownerUid: String): Flow<List<BudgetModel>>`
  - `getTransactions(ownerUid: String): List<TransactionModel>`
  - `saveTransaction(transaction: TransactionModel): Result<Unit>`
  - `deleteTransaction(id: String, ownerUid: String): Result<Unit>`
  - `saveBudget(budget: BudgetModel): Result<Unit>`
  - `deleteBudget(ownerUid: String, month: String): Result<Unit>`
  - `getMonthlySummary(ownerUid: String, month: String): MonthlySummaryModel`
  - `calculateIncomePaise(ownerUid, start, end): Long`
  - `calculateExpensesPaise(ownerUid, start, end): Long`
  - `calculateBalancePaise(ownerUid, start, end): Long`
  - `syncPending(ownerUid: String): SyncResult`
- `OfflineFirstTransactionRepository`:
  - Implements `ITransactionRepository` delegating directly to `RoomTransactionDataSource`.
  - Room SQLite is the immediate, single source of truth.

### 2.3 ViewModel & State Flow
- `MoneyViewModel`:
  - Eagerly evaluates current authenticated user from `IAuthRepository.authState`.
  - Maintains reactive `Flow` pipeline combining transactions and monthly budget.
  - Exposes `MoneyUiState`:
    - `selectedMonth: String` ("yyyy-MM")
    - `selectedTab: Int` (0 = Transactions, 1 = Analytics)
    - `filterType: String` ("All", "Expense", "Income")
    - `filterCategory: String`
    - `searchQuery: String`
    - `monthlyBudgetPaise: Long`
    - `totalIncomePaise: Long`
    - `totalExpensesPaise: Long`
    - `netCashflowPaise: Long`
    - `remainingBudgetPaise: Long`
    - `isBudgetExceeded: Boolean`
    - `transactions: List<TransactionModel>` (filtered and sorted)
    - `analytics: FinancialAnalyticsResult`

### 2.4 User Interface Components
- `MoneyScreen.kt`: Screen host managing tab switching, date navigation, and bottom sheets.
- `TransactionCard.kt`: Material 3 card rendering transaction details, category icon, and color-coded amount.
- `TransactionEditorSheet.kt`: BottomSheet for recording new income/expenses with amount keypad input, category selector, account selector, date/time pickers, and notes field.
- `SetBudgetDialog.kt`: Accessible dialog for configuring monthly budget limits.
- `TransactionDetailsSheet.kt`: Inspection sheet with delete confirmation and metadata view.
- `MoneySettingsSheet.kt`: Opt-in automation settings and synthetic Bank SMS simulator.
