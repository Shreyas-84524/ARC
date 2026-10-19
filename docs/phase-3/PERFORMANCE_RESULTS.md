# Performance Baseline & Profiling Results — Phase 3

## 1. Build and Packaging Metrics

| Metric | Phase 2 Baseline | Phase 3 Measurement | Delta / Assessment |
|---|---|---|---|
| **Debug APK Size** | 21.57 MB | 21.96 MB (21,963,821 bytes) | +390 KB (due to Room V3 DAOs, compose UI sheets, and regex patterns) |
| **Clean Build Time** | ~45s | 38s | Fast execution via Gradle daemon & parallel task processing |
| **Incremental Build Time** | ~12s | 9s | High build cache hit rate |
| **Total Test Execution Time** | ~18s (74 tests) | 22s (117 tests) | ~188ms per test suite on local JVM |

---

## 2. Memory & Query Optimization

### 2.1 Integer Arithmetic Efficiency
By strictly utilizing integer paise (`Long`) for all money calculations:
- Floating-point emulation overhead on low-end ARM processors is avoided.
- Memory consumption per transaction model remains lean (64-bit integer vs complex `BigDecimal`).
- Zero precision drift during high-frequency analytical recalculations.

### 2.2 Room SQLite Indexing
Database queries operate on dedicated SQLite indices:
- `index_transactions_ownerUid`: Ensures user isolation queries run in $O(\log N)$.
- `index_transactions_date`: Accelerates date range queries for monthly totals and analytics.
- `index_transactions_automationFingerprint`: Enables instantaneous $O(1)$ duplicate lookup during expense parsing.
- `index_budgets_ownerUid_month`: Unique composite index ensuring unique budget constraints per user per month.

### 2.3 Compose Recomposition Optimization
- `MoneyUiState` and `DashboardUiState` are immutable data classes.
- Transaction items in `LazyColumn` use stable unique keys: `key = { it.id }`.
- Analytical charts and cards compute values inside `FinancialAnalyticsEngine` outside Compose layout passes.
