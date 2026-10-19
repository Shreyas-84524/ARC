# ARC-Kotlin Phase 5 — Global Search Engine Architecture & Privacy Safeguards

## 1. Overview and Design Objectives

The Global Search module provides a unified, cross-domain discovery engine across all productivity and financial records within ARC:
- **Tasks**: Title, description, category, and labels
- **Habits**: Name, category
- **Transactions**: Notes, category, amount, and transaction type (Income vs Expense)

### Mandatory Privacy Invariant: Zero-Vault Search Policy
In strict compliance with the **Zero-Cloud, Cryptographic Vault Isolation Invariant**:
1. **Secret Notes and Vault Metadata are NEVER indexed, queried, or displayed.**
2. `IGlobalSearchRepository` and `GlobalSearchRepository` do NOT inject, declare, or hold any reference to `ISecretNoteRepository`, `SecretNoteDao`, or `SecretNoteEntity`.
3. Even if a user's decrypted secret notes contain keywords matching the user's search query (e.g., "seed phrase", "crypto", "password"), the search engine has zero code paths to inspect or leak that data.

---

## 2. Architecture & Data Flow

```
                      +-----------------------------+
                      |   GlobalSearchScreen (M3)   |
                      +--------------+--------------+
                                     |
                          Query & Filter Events
                                     |
                                     v
                      +-----------------------------+
                      |    GlobalSearchViewModel    |
                      +--------------+--------------+
                                     |
               300ms Debounce + distinctUntilChanged()
                                     |
                                     v
                      +-----------------------------+
                      |   IGlobalSearchRepository   |
                      +--+-----------+-----------+--+
                         |           |           |
            +------------+     +-----+-----+     +------------+
            |                  |           |                  |
            v                  v           v                  v
    +---------------+  +---------------+  +-----------------+  +----------------------+
    | ITaskRepo     |  | IHabitRepo    |  | ITransactionRepo|  | [VAULT EXCLUDED]     |
    | (Tasks)       |  | (Habits)      |  | (Transactions)  |  | No Dao, No Queries  |
    +---------------+  +---------------+  +-----------------+  +----------------------+
```

### Components

1. **`IGlobalSearchRepository` & `GlobalSearchRepository`**:
   - `search(ownerUid: String, query: String): SearchResults`
   - Validates `ownerUid` and normalizes query (lowercase, trimmed).
   - In-memory matching against cached repositories for instant response and offline-first performance.
2. **`GlobalSearchViewModel`**:
   - Manages query debouncing (`300ms` for non-empty text, `0ms` for query clearing).
   - Reactive `StateFlow<GlobalSearchUiState>` combining query, active filter chip, raw results, and searching indicator.
   - Preserves raw match counts across entity categories when switching filter chips (`ALL`, `TASKS`, `HABITS`, `TRANSACTIONS`).
3. **`GlobalSearchScreen` (Jetpack Compose)**:
   - Full Material 3 search bar with back navigation and clear (`X`) button.
   - Filter chips row with dynamic badges showing hit counts.
   - Categorized result sections with dedicated cards and iconography matching ARC design tokens (`ArcTheme.colors`).
   - Dedicated empty states for empty search prompts and no-result queries.

---

## 3. Verification & Test Suite

The test suite in `com.arc.arc.search.GlobalSearchTest` validates:
1. **Multi-Entity Search**: Confirms simultaneous matching across tasks, habits, and transactions.
2. **Filter Chip Granularity**: Verifies filtering views to specific entity types while preserving global category counts.
3. **Privacy Invariant Enforcement**: Confirms that Secret Notes cannot be searched, found, or leaked even when search strings exactly match secret note titles and contents.
4. **User Data Isolation**: Proves that searching as User A never returns User B's entities, maintaining strict tenant separation.
5. **Debounce & Clear Lifecycle**: Verifies rapid query clearing and debounce stability.
