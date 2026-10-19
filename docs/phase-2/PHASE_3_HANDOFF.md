# Phase 3 Handoff Specification: Money Manager & Financial Intelligence

## 1. Handoff Summary

Phase 2 has successfully delivered ARC-Kotlin's Productivity Dashboard and Habit Tracker:
- **Base Branch for Phase 3:** `phase-2`
- **Target Branch for Phase 3:** `phase-3`
- **Remote:** `https://github.com/Shreyas-84524/ARC-Kotlin.git`
- **Verified Build Status:**
  - 100% clean compilation
  - 74 automated unit tests passing across 16 test suites
  - Android Lint: 0 errors
  - Debug APK: `app-debug.apk` (20.58 MB)
- **Active Workspace:** `C:\dev\ARC-Kotlin`
- **Read-Only Legacy Reference:** `C:\dev\ARC` (strictly unmodified)

---

## 2. Established Architecture & Patterns for Phase 3

Engineers continuing into Phase 3 should adhere strictly to the verified conventions:

### 2.1 Toolchain Conventions
- **AGP 9.4.1 Built-in Kotlin Support:** Do not apply the legacy `kotlin-android` Gradle plugin.
- **Room Database Entities in Java:** Authored in Java (`TransactionEntity.java`, `TransactionDao.java`) in `com.arc.arc.core.database` to interoperate cleanly with `annotationProcessor(libs.androidx.room.compiler)` under AGP's built-in Kotlin support.
- **Kotlin Extension Mappers:** Author `TransactionMappers.kt` bridging `TransactionEntity` to domain `TransactionModel`.
- **Database Migrations:** Never use `.fallbackToDestructiveMigration()`. Author `MIGRATION_2_3` in `ArcDatabase.java` and increment database version to 3.
- **Java 8+ Desugaring:** `isCoreLibraryDesugaringEnabled = true` is already configured in `app/build.gradle.kts`. Use `java.time.LocalDate` / `Instant` freely across minSdk 23+.

### 2.2 Design System Tokens & Components
Always reuse tokens from `com.arc.arc.core.designsystem.theme.ArcTheme`:
- **Colors:**
  - `ArcTheme.colors.background` (`#0D0D12`)
  - `ArcTheme.colors.surface` (`#16161F`)
  - `ArcTheme.colors.accent` (`#6366F1`)
  - `ArcTheme.colors.success` (`#10B981` — recommended for Income)
  - `ArcTheme.colors.error` (`#EF4444` — recommended for Expense)
  - `ArcTheme.colors.warning` (`#F59E0B` — recommended for Transfers/Warnings)
- **Components:** `ArcCard`, `ArcButton`, `ArcTextField`, `ArcDialog`, `ArcPriorityBadge`, `ArcLoadingState`, `ArcEmptyState`.

### 2.3 ViewModel & UDF Pattern
- Define a companion `ViewModelProvider.Factory` on ViewModels.
- Combine Room reactive flows via `combine(...)` and expose a single immutable `StateFlow<MoneyUiState>`.
- Keep mutations optimistic, wrapped in Room transactions via `database.runInTransaction { ... }`, with reversible snackbar undo actions where appropriate.

---

## 3. Phase 3 Scope & Detailed Objectives

### Objective A: Room Database Migration (v2 -> v3)
1. Inspect legacy `TransactionModel` verified in `TransactionContractTest.kt` (derived from `C:\dev\ARC/lib/models/transaction_model.dart`).
2. Create `TransactionEntity.java` with columns:
   - `id`, `userId`, `title`, `amount` (Double), `type` (Income/Expense/Transfer), `category`, `account` / `paymentMethod`, `date` (Long/ISO), `notes`, `isRecurring`, `createdAt`, `updatedAt`.
3. Create `TransactionDao.java` with reactive `Flow` queries:
   - `observeTransactions(String userId)`
   - `observeTransactionsByDateRange(String userId, long startDate, long endDate)`
   - `observeMonthlyTotals(String userId, long monthStart, long monthEnd)`
4. Author `MIGRATION_2_3` in `ArcDatabase.java` and export Room schema version 3.

### Objective B: Domain & Financial Analytics Engine
1. Implement `ITransactionRepository` and `OfflineFirstTransactionRepository`.
2. Implement `FinancialAnalyticsEngine`:
   - Calculate total balance, total monthly income, total monthly expense, and net cashflow.
   - Aggregate spending by category for visual pie/bar breakdown.
   - Compute budget threshold warnings (e.g. 80% / 100% of target budget).

### Objective C: Jetpack Compose Money UI
1. Replace `MoneyPlaceholderScreen.kt` with full `MoneyScreen.kt`.
2. Connect `MoneyRoute.kt` in `ArcNavHost.kt`.
3. Build key UI subcomponents:
   - **Financial Overview Banner:** Total balance, monthly cashflow metrics.
   - **Category Spending Breakdown:** Visual progress bars or distribution indicators.
   - **Transaction History List:** Filterable by type (All, Income, Expense) and searchable.
   - **TransactionEditorSheet:** ModalBottomSheet for recording income or expenses with category pickers, amount input, date pickers, and account types.

---

## 4. Verification Checkpoint for Phase 3

Before concluding Phase 3, confirm:
1. `TransactionContractTest` and new `TransactionsPersistenceTest` pass.
2. `MoneyModuleTest` validates all ViewModel state flows and financial math.
3. Android Lint reports 0 errors.
4. Schema version 3 is generated and committed.
5. Debug APK compiles and packages cleanly.
