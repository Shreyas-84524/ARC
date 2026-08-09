# Project Arc — Step 2 Multi-User Data Foundation & Migration Preparation Report

> **Document Version:** 1.0.0  
> **Status:** Step 2 Completed  
> **Date:** August 10, 2026  
> **Target Future Users:** Shreyas, Aman, Rohit, Sachi, Yash  

---

## A. STEP 2 SUMMARY

Step 2 successfully prepared Project Arc's backend and local data architecture for multi-user isolation without introducing Firebase Authentication or changing existing user workflows.

Key achievements:
1. **User Identity Abstraction**: Created `UserProfile` model and `UserContext` class/provider allowing user identity (`userId`) to be injected into repository constructors and Riverpod state management without hardcoding `"Shreyas"`.
2. **User-Scoped Firestore Repositories**: Refactored `TaskRepository`, `HabitRepository`, `MoneyRepository`, `SettingsRepository`, and `SyncService` to support user-scoped Firestore collection paths (`users/{userId}/tasks`, `users/{userId}/habits`, `users/{userId}/habitEntries`, `users/{userId}/transactions`, `users/{userId}/budgets`, `users/{userId}/monthlySummaries`, `users/{userId}/settings/profile`) while seamlessly preserving legacy root collections when `userId == null`.
3. **Hive User Isolation Preparation**: Extended `HiveService` with `getUserBox<T>(baseBoxName, userId)` and `getUserBoxName(...)`, generating user-scoped Hive boxes (`*_box_{userId}`) while leaving legacy default boxes (`tasks_box`, `habits_box`, etc.) 100% active and untouched.
4. **Non-Destructive Migration Utility**: Implemented `DataMigrationService` to inspect legacy global data and execute a non-destructive copy & verify pipeline to target user namespaces (e.g. `Shreyas`). **The migration was NOT executed in Step 2.**
5. **Zero Data Loss & Zero Modification**: All existing production data in Cloud Firestore and Hive remains 100% intact and unedited.
6. **Full Test & Analyze Verification**: All **47 unit and widget tests pass cleanly** (`47/47`), and static analysis passes cleanly.

---

## B. FILES CREATED

1. `lib/features/user_management/models/user_profile.dart`:
   - Purpose: User profile model representing user identity (`id`, `username`, `displayName`, `email`, `createdAt`, `lastLoginAt`). Includes helper to map username to internal email (e.g. `shreyas@arc.app`).
2. `lib/features/user_management/models/user_context.dart`:
   - Purpose: Encapsulates active user identity context. Provides helper methods `firestoreCollectionPath(...)` and `firestoreSettingsDocPath()` for dynamic collection routing.
3. `lib/features/user_management/providers/user_context_provider.dart`:
   - Purpose: Riverpod `StateNotifierProvider` exposing active `UserContext`. Defaults to `UserContext.legacy` (`userId == null`), ensuring existing single-user app operation is preserved.
4. `lib/core/services/data_migration_service.dart`:
   - Purpose: Non-destructive migration utility to inspect legacy root Firestore/Hive records, copy them to target user namespaces (`users/{shreyasUid}/...`), verify document counts, and generate migration reports.
5. `step2_multi_user_foundation_report.md`:
   - Purpose: Mandatory Step 2 completion report detailing architectural foundation, data safety, and test results.

---

## C. FILES MODIFIED

1. `lib/core/services/hive_service.dart`:
   - Added `getUserBoxName(baseBoxName, userId)` and `getUserBox<T>(baseBoxName, userId)` methods to generate user-scoped box names (`*_box_{userId}`) while falling back to legacy boxes when `userId == null`.
2. `lib/features/task_manager/repository/task_repository.dart`:
   - Refactored constructor to accept optional `String? userId`. Uses user-scoped Firestore path (`users/{userId}/tasks`) and user-scoped Hive box (`tasks_box_{userId}`) when `userId` is present; falls back to `/tasks` and `tasks_box` when `userId` is null.
3. `lib/features/habit_tracker/repository/habit_repository.dart`:
   - Refactored constructor to accept optional `String? userId`. Uses user-scoped Firestore paths (`users/{userId}/habits` and `users/{userId}/habitEntries`) and user-scoped Hive boxes when `userId` is present.
4. `lib/features/money_tracker/repository/money_repository.dart`:
   - Refactored constructor to accept optional `String? userId`. Uses user-scoped Firestore paths (`users/{userId}/transactions`, `users/{userId}/budgets`, `users/{userId}/monthlySummaries`) and user-scoped Hive boxes when `userId` is present.
5. `lib/features/settings/repository/settings_repository.dart`:
   - Refactored constructor to accept optional `String? userId`. Uses user-scoped Firestore path (`users/{userId}/settings/profile`) and user-scoped Hive box when `userId` is present.
6. `lib/core/services/sync_service.dart`:
   - Refactored constructor to accept optional `String? userId`. Generates snapshot listeners dynamically for user-scoped collection paths when `userId` is present.
7. `lib/providers/global_providers.dart`:
   - Updated `settingsRepositoryProvider`, `taskRepositoryProvider`, `habitRepositoryProvider`, `moneyRepositoryProvider`, and `syncServiceProvider` to watch `userContextProvider` and inject `userContext.userId`.
8. Test Files (`test/individual_habit_analytics_test.dart`, `test/responsive_ui_test.dart`, `test/task_completion_test.dart`, `test/task_filter_test.dart`, `test/widget_test.dart`):
   - Added `String? get userId => null;` to all mock repository implementations to maintain clean interface compliance.

---

## D. FIRESTORE ARCHITECTURE

### Prepared User-Scoped Firestore Paths
When a user is authenticated (`userId` present), repository calls automatically route to:

```
users/{userId}/
   ├── settings/profile (Document: User preferences & settings)
   ├── tasks/{taskId} (Collection: Tasks)
   ├── habits/{habitId} (Collection: Habits)
   ├── habitEntries/{entryId} (Collection: Habit check-in logs)
   ├── transactions/{transactionId} (Collection: Money transactions)
   ├── budgets/{monthKey} (Collection: Monthly budget caps)
   └── monthlySummaries/{monthKey} (Collection: Monthly financial summaries)
```

### Legacy Fallback (Active in Step 2)
When `userId == null`, repositories automatically continue operating on legacy root collections (`/tasks`, `/habits`, `/habitEntries`, `/transactions`, `/budgets`, `/monthlySummaries`, `/settings/global`).

---

## E. HIVE ARCHITECTURE

### Prepared Local Storage User Isolation
- When `userId` is provided, `HiveService.getUserBox<T>(baseBoxName, userId)` targets user-isolated boxes:
  - `tasks_box_{userId}`
  - `tasks_sync_queue_box_{userId}`
  - `habits_box_{userId}`
  - `habit_entries_box_{userId}`
  - `habits_sync_queue_box_{userId}`
  - `money_box_{userId}`
  - `money_sync_queue_box_{userId}`
  - `settings_box_{userId}`
- When `userId == null`, `HiveService.getUserBox<T>(baseBoxName, null)` falls back to legacy default boxes (`tasks_box`, etc.).
- **User Logout/Switch Strategy**: In future steps, when User A logs out, `userContextProvider` resets, closing User A's boxes and opening User B's boxes, preventing cross-user cache contamination.

---

## F. USER IDENTITY ARCHITECTURE

Future Firebase UID flow into the system:

```
[ User Log In (Step 4) ]
           │
           ▼
[ Firebase Authentication (UID) ]
           │
           ▼
[ userContextProvider.setActiveUser(userId: authUser.uid, profile: profile) ]
           │
           ▼
[ Riverpod Notifies Repository Providers ]
           │
           ▼
[ Repositories & SyncService Instantiate with userId ]
           │
           ▼
[ Dynamic Routing to users/{uid}/* in Firestore & Hive ]
```

---

## G. MIGRATION PREPARATION

### Migration Process (Designed in `DataMigrationService`)
1. **Inspection**: Call `DataMigrationService().inspectLegacyData()` to verify record counts in legacy root collections.
2. **Non-Destructive Copy**: Call `migrateLegacyDataToUser(targetUserId: shreyasUid)` to copy all root documents to `/users/{shreyasUid}/*`.
3. **Verification**: Read target user subcollections and assert document count equality.
4. **Execution Status**: **NO MIGRATION WAS EXECUTED IN STEP 2.** Legacy root data remains 100% untouched.

---

## H. DATA SAFETY CONFIRMATION

- **Firestore data modified?**: **NO.**
- **Firestore data deleted?**: **NO.**
- **Hive data modified?**: **NO.**
- **Hive data deleted?**: **NO.**

---

## I. AUTHENTICATION STATUS

> **CONFIRMATION**: Firebase Authentication was NOT implemented in Step 2. No login screen, logout UI, or password handling was introduced.

---

## J. SECURITY RULES

`firestore.rules` was **NOT changed** in Step 2.

### Planned Security Rules for Step 4:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## K. TEST RESULTS

- **Static Analysis (`flutter analyze`)**:
  - **Result**: `0 errors, 0 warnings` (Clean static analysis pass!)
- **Unit & Widget Tests (`flutter test`)**:
  - **Result**: **47 / 47 tests passing!** (100% test suite success)

---

## L. RISKS / WARNINGS BEFORE STEP 3

1. **Hive Box Initialization**: In Step 3/4, when switching users dynamically, Hive boxes for the new user must be opened asynchronously before initializing StateNotifiers.
2. **Legacy Queue Items**: Any pending sync items in legacy queue boxes must be processed or copied during Shreyas migration so pending offline actions are not orphaned.

---

## M. STEP 3 REQUIREMENTS

Based on Step 2 completion, Step 3 must:
1. Prepare local multi-user session state switching mechanisms.
2. Provide local user profile storage and local user session persistence.
3. Test local user switching between `Shreyas`, `Aman`, `Rohit`, `Sachi`, `Yash` in local memory/storage without executing cloud migration or enabling Firebase Auth.
