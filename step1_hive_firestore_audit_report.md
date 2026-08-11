# PROJECT ARC — STEP 1 AUDIT REPORT
## HIVE ↔ FIRESTORE ARCHITECTURE AUDIT REPORT

> **Document Version:** 1.0.0  
> **Execution Date:** August 10, 2026  
> **Target Project:** Project Arc (`c:\Learning some new stuff\App Development\arc`)  
> **Target Firebase Project:** `arc-productivity-shreyas`  
> **Audit Status:** 🟡 **STEP 1 AUDIT COMPLETE — ISSUES REQUIRE REVIEW**

---

## 1. EXECUTIVE SUMMARY

This audit presents a comprehensive inspection of the current **Hive ↔ Cloud Firestore** data architecture, synchronization mechanisms, startup/logout flows, multi-user isolation, and database access patterns for **Project Arc**. 

**Step 1 is a strict READ-ONLY audit.** Zero files, zero Hive data, zero Firestore documents, zero security rules, and zero authentication settings were modified during this audit.

### Key Audit Findings:
1. **Hive Box Scoping Defect (User Isolation Leak):** While `HiveService.getUserBox(baseBoxName, userId)` contains scoping logic (`${baseBoxName}_${userId}`), `HiveService.init()` only opens un-scoped base boxes (`tasks_box`, `habits_box`, etc.), and `HiveService.openUserBox` is **never called anywhere in the app**. Consequently, `getUserBox` always falls back to base boxes, causing **all users on a device to share the exact same local Hive boxes**. Cached data from a previous user (e.g. Shreyas) remains in Hive and is immediately visible upon logging in as another user (e.g. Aman) before cloud sync completes.
2. **Unthrottled Real-time Firestore Listeners:** `SyncService.startRealTimeSync()` establishes **6 active real-time stream listeners (`snapshots()`)** on startup for `tasks`, `habits`, `habitEntries`, `transactions`, `budgets`, and `settings/profile`.
3. **Eager Bulk Startup Reads:** `SyncService.pullInitialDataFromFirestore()` executes **7 full collection `.get()` queries** on every single app launch without checking rolling 24-hour sync limits or minimum time intervals.
4. **No Pre-Logout Synchronization:** `AuthService.logout()` invokes `FirebaseAuth.instance.signOut()` immediately without flushing pending local changes queued in Hive sync boxes (`tasks_sync_queue_box`, `habits_sync_queue_box`, `money_sync_queue_box`).
5. **No Direct Screen → Firestore Access:** Screens do not interact directly with `FirebaseFirestore.instance`. UI components exclusively read from Riverpod StateNotifiers which consume Repositories. However, Repositories execute eager direct writes to Firestore on every user mutation.

---

## 2. CURRENT ARCHITECTURE OVERVIEW

The current data flow architecture relies on a hybrid read/write pattern where local Hive storage and cloud Firestore operate in tandem, managed primarily by `SyncService` and feature Repositories.

```
                      +-----------------------------+
                      |   FIREBASE AUTHENTICATION   |
                      +--------------+--------------+
                                     |
                                     v
                          Authenticated UID
                                     |
    +--------------------------------+--------------------------------+
    |                                                                 |
    v                                                                 v
+-------------------------------+                  +-------------------------------+
|         SYNC SERVICE          |                  |         REPOSITORIES          |
| (Bulk Pull & Stream Listeners)|                  |  (Task, Habit, Money, Settings)|
+---------------+---------------+                  +---------------+---------------+
                |                                                  |
        Reads   |   Writes                                 Reads   |   Writes
        Cloud   v   Local                                  Local   v   Both
+-------------------------------+                  +-------------------------------+
|      FIRESTORE CLOUD DB       |                  |        HIVE LOCAL DB          |
| (/users/{uid}/{collection}/*) |                  | (Shared Base Boxes - Unscoped)|
+-------------------------------+                  +---------------+---------------+
                                                                   |
                                                                   v
                                                           +---------------+
                                                           |  APP SCREENS  |
                                                           +---------------+
```

---

## 3. HIVE ARCHITECTURE

### Initialization
Hive initialization is performed in `lib/main.dart` inside `main()` prior to `runApp()` by invoking `HiveService().init()`.

```dart
// lib/main.dart
await HiveService().init();
```

Inside `HiveService.init()` ([hive_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/hive_service.dart#L26-L54)):
1. `Hive.initFlutter()` initializes local storage directory.
2. Registers TypeAdapters (Ids 0 to 3).
3. Opens 8 base Hive boxes synchronously.

### Registered Adapters & TypeIds
- **TypeID 0:** `TaskAdapter` for `Task` ([task_model.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/task_manager/models/task_model.dart#L6))
- **TypeID 1:** `HabitAdapter` for `Habit` ([habit_model.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/habit_tracker/models/habit_model.dart#L5))
- **TypeID 2:** `HabitEntryAdapter` for `HabitEntry` ([habit_entry_model.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/habit_tracker/models/habit_entry_model.dart#L5))
- **TypeID 3:** `TransactionAdapter` for `Transaction` ([transaction_model.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/money_tracker/models/transaction_model.dart#L5))

### Hive Services & Repositories
- `HiveService`: Singleton class managing box opening, base getters, and setting cache.
- `TaskRepository`, `HabitRepository`, `MoneyRepository`, `SettingsRepository`: Directly consume Hive boxes via `HiveService().getUserBox(...)`.

### Error Handling & Cleanup
- Initialization errors are caught and logged (`debugPrint`).
- Box getters throw `StateError` if Hive is uninitialized or box is not open.
- Hive boxes are **never closed** or cleared during logout or app teardown.

---

## 4. HIVE BOX INVENTORY

There are currently **8 active Hive boxes** initialized in `HiveService`:

| Box Name | Model Stored | Data Description | User Association | Read Ops | Write Ops | Delete Ops |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `tasks_box` | `Task` | Local task items | Shared (Fallback) | `TaskRepository.getTasks()`, `SyncService` | `TaskRepository.saveTask()`, `SyncService` | `TaskRepository.deleteTask()`, `SyncService` |
| `tasks_sync_queue_box` | `Map<String, dynamic>` | Pending task sync operations | Shared (Fallback) | `TaskRepository.syncPending()`, `SyncService` | `TaskRepository.saveTask()`, `deleteTask()` | `TaskRepository.syncPending()`, `saveTask()` |
| `habits_box` | `Habit` | Habit definitions | Shared (Fallback) | `HabitRepository.getHabits()`, `SyncService` | `HabitRepository.saveHabit()`, `SyncService` | `HabitRepository.deleteHabit()`, `SyncService` |
| `habit_entries_box` | `HabitEntry` | Daily habit check-ins | Shared (Fallback) | `HabitRepository.getEntries()`, `SyncService` | `HabitRepository.toggleEntry()`, `SyncService` | `HabitRepository.toggleEntry()`, `deleteHabit()` |
| `habits_sync_queue_box` | `Map<String, dynamic>` | Pending habit sync actions | Shared (Fallback) | `HabitRepository.syncPending()`, `SyncService` | `HabitRepository.saveHabit()`, `toggleEntry()` | `HabitRepository.syncPending()`, `saveHabit()` |
| `money_box` | `Transaction` | Income & expense logs | Shared (Fallback) | `MoneyRepository.getTransactions()`, `SyncService` | `MoneyRepository.saveTransaction()`, `SyncService` | `MoneyRepository.deleteTransaction()`, `SyncService` |
| `money_sync_queue_box` | `Map<String, dynamic>` | Pending transaction sync actions | Shared (Fallback) | `MoneyRepository.syncPending()`, `SyncService` | `MoneyRepository.saveTransaction()`, `saveMonthlyBudget()` | `MoneyRepository.syncPending()`, `saveTransaction()` |
| `settings_box` | Dynamic primitives / Maps | Theme mode, budgets, summaries, sync flags | Shared (Fallback) | `SettingsRepository.getSettings()`, `MoneyRepository` | `SettingsRepository.saveSettings()`, `SyncService` | `SettingsRepository.saveSettings()`, `SyncService` |

---

## 5. HIVE USER ISOLATION

### Audit Result: ❌ NO ACTUAL USER ISOLATION IN HIVE

In `HiveService` ([hive_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/hive_service.dart#L68-L95)):

```dart
static String getUserBoxName(String baseBoxName, String? userId) {
  if (userId == null || userId.isEmpty) return baseBoxName;
  return '${baseBoxName}_$userId';
}

Box<T> getUserBox<T>(String baseBoxName, String? userId) {
  final scopedName = getUserBoxName(baseBoxName, userId);
  if (!_initialized || !Hive.isBoxOpen(scopedName)) {
    if (Hive.isBoxOpen(baseBoxName)) {
      return Hive.box<T>(baseBoxName);
    }
    throw StateError('HiveService: box $scopedName is not open.');
  }
  return Hive.box<T>(scopedName);
}
```

### Analysis of the Isolation Bug:
1. `HiveService.init()` only opens base box names (`tasks_box`, `habits_box`, etc.). User-scoped box names (`tasks_box_u0xSvSMCm...`) are **never opened on startup**.
2. `HiveService.openUserBox()` is defined on line 76, but **0 calls to `openUserBox` exist in the codebase**.
3. When `getUserBox` is called with a valid `userId` (e.g. Aman's UID), `Hive.isBoxOpen('tasks_box_amanUID')` evaluates to `false`.
4. `getUserBox` executes its fallback branch: `return Hive.box<T>(baseBoxName);`.
5. Therefore, **all authenticated users access the exact same base boxes**.

### Specific Question Answer:
> **Can Shreyas's cached data accidentally remain visible after logging out and logging in as Aman?**

**YES.**  
**Why:**
- When Shreyas logs out, `AuthService.logout()` signs out of Firebase Auth but **does not clear or close Hive boxes**.
- When Aman logs in, `TasksNotifier` calls `_repository.getTasks()`. Because `getUserBox` falls back to `tasks_box`, it reads Shreyas's tasks from the global box and displays them to Aman immediately.
- Shreyas's tasks remain visible until Firestore data download completes and overwrites the box (or indefinitely if offline).

---

## 6. FIRESTORE ARCHITECTURE

Firestore integration operates under strict user-scoped paths enforced by deployed security rules:

### Deployed Security Rules Matrix
- `/users/{userId}/{document=**}` ➔ `allow read, write: if request.auth != null && request.auth.uid == userId;`
- Legacy root paths (`/tasks/*`, `/habits/*`, etc.) ➔ `allow read: if request.auth != null;` (Read-only reference backup).

---

## 7. FIRESTORE COLLECTION INVENTORY

The application uses **7 user-scoped subcollections** under `/users/{uid}/`:

| Firestore Path | Purpose | Model | Repository / Service | Read Ops | Write Ops | Delete Ops |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `/users/{uid}/tasks/{id}` | Task records | `Task` | `TaskRepository`, `SyncService` | Initial pull (`.get()`), Real-time stream (`.snapshots()`) | `saveTask()`, `syncPending()` | `deleteTask()`, `syncPending()` |
| `/users/{uid}/habits/{id}` | Habit definitions | `Habit` | `HabitRepository`, `SyncService` | Initial pull (`.get()`), Real-time stream (`.snapshots()`) | `saveHabit()`, `syncPending()` | `deleteHabit()`, `syncPending()` |
| `/users/{uid}/habitEntries/{id}` | Habit check-in entries | `HabitEntry` | `HabitRepository`, `SyncService` | Initial pull (`.get()`), Real-time stream (`.snapshots()`) | `toggleEntry()`, `syncPending()` | `toggleEntry()`, `syncPending()` |
| `/users/{uid}/transactions/{id}` | Financial logs | `Transaction` | `MoneyRepository`, `SyncService` | Initial pull (`.get()`), Real-time stream (`.snapshots()`) | `saveTransaction()`, `syncPending()` | `deleteTransaction()`, `syncPending()` |
| `/users/{uid}/budgets/{month}` | Monthly budget target | Number (`amount`) | `MoneyRepository`, `SyncService` | Initial pull (`.get()`), Real-time stream (`.snapshots()`) | `saveMonthlyBudget()`, `syncPending()` | `SyncService` (on stream removal) |
| `/users/{uid}/monthlySummaries/{month}`| Monthly totals summary | `MonthlySummary` | `MoneyRepository`, `SyncService` | Initial pull (`.get()`) | `saveMonthlySummary()`, `syncPending()` | N/A |
| `/users/{uid}/settings/profile` | Profile & settings | `SettingsModel` / `UserProfile` | `SettingsRepository`, `AuthService`, `SyncService` | Initial pull (`.get()`), Real-time stream (`.snapshots()`) | `saveSettings()`, `AuthService.loginWithUsername()` | N/A |

---

## 8. FIRESTORE READ INVENTORY

All Firestore reads in the project originate from **2 services**: `SyncService` and `DataMigrationService`.

| File | Class / Method | Firestore Path | Trigger | Frequency | Cached in Hive? |
| :--- | :--- | :--- | :--- | :--- | :---: |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L98) | `SyncService.pullInitialDataFromFirestore` | `/users/{uid}/tasks` | App Startup (`SyncInitializer`) | Every launch | Yes (`tasks_box`) |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L116) | `SyncService.pullInitialDataFromFirestore` | `/users/{uid}/habits` | App Startup (`SyncInitializer`) | Every launch | Yes (`habits_box`) |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L132) | `SyncService.pullInitialDataFromFirestore` | `/users/{uid}/habitEntries` | App Startup (`SyncInitializer`) | Every launch | Yes (`habit_entries_box`) |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L144) | `SyncService.pullInitialDataFromFirestore` | `/users/{uid}/transactions` | App Startup (`SyncInitializer`) | Every launch | Yes (`money_box`) |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L154) | `SyncService.pullInitialDataFromFirestore` | `/users/{uid}/budgets` | App Startup (`SyncInitializer`) | Every launch | Yes (`settings_box`) |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L165) | `SyncService.pullInitialDataFromFirestore` | `/users/{uid}/monthlySummaries` | App Startup (`SyncInitializer`) | Every launch | Yes (`settings_box`) |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L175) | `SyncService.pullInitialDataFromFirestore` | `/users/{uid}/settings/profile` | App Startup (`SyncInitializer`) | Every launch | Yes (`settings_box`) |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L205) | `SyncService.startRealTimeSync` | `/users/{uid}/tasks` | App Startup (`SyncInitializer`) | Continuous stream | Yes (`tasks_box`) |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L230) | `SyncService.startRealTimeSync` | `/users/{uid}/habits` | App Startup (`SyncInitializer`) | Continuous stream | Yes (`habits_box`) |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L256) | `SyncService.startRealTimeSync` | `/users/{uid}/habitEntries` | App Startup (`SyncInitializer`) | Continuous stream | Yes (`habit_entries_box`) |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L279) | `SyncService.startRealTimeSync` | `/users/{uid}/transactions` | App Startup (`SyncInitializer`) | Continuous stream | Yes (`money_box`) |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L303) | `SyncService.startRealTimeSync` | `/users/{uid}/budgets` | App Startup (`SyncInitializer`) | Continuous stream | Yes (`settings_box`) |
| [sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart#L323) | `SyncService.startRealTimeSync` | `/users/{uid}/settings/profile` | App Startup (`SyncInitializer`) | Continuous stream | Yes (`settings_box`) |

---

## 9. FIRESTORE WRITE INVENTORY

Every write to Firestore occurs when user action is taken in a screen or sheet:

| File | Function | Firestore Path | Trigger | Data Written | Is Hive Updated First? | Is Write Retried? | Failure Handled? |
| :--- | :--- | :--- | :--- | :--- | :---: | :---: | :---: |
| [task_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/task_manager/repository/task_repository.dart#L38) | `TaskRepository.saveTask()` | `/users/{uid}/tasks/{id}` | Task created/updated/toggled | `task.toMap()` | Yes | Yes (via Queue) | Yes (catch & queue) |
| [task_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/task_manager/repository/task_repository.dart#L58) | `TaskRepository.deleteTask()` | `/users/{uid}/tasks/{id}` | Task deleted | Delete action | Yes | Yes (via Queue) | Yes (catch & queue) |
| [habit_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/habit_tracker/repository/habit_repository.dart#L46) | `HabitRepository.saveHabit()` | `/users/{uid}/habits/{id}` | Habit created/updated | `habit.toMap()` | Yes | Yes (via Queue) | Yes (catch & queue) |
| [habit_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/habit_tracker/repository/habit_repository.dart#L69) | `HabitRepository.deleteHabit()` | `/users/{uid}/habits/{id}` | Habit deleted | Delete action | Yes | Yes (via Queue) | Yes (catch & queue) |
| [habit_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/habit_tracker/repository/habit_repository.dart#L92) | `HabitRepository.toggleEntry()` | `/users/{uid}/habitEntries/{id}`| Habit check-in toggled | `entry.toMap()` / Delete | Yes | Yes (via Queue) | Yes (catch & queue) |
| [money_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/money_tracker/repository/money_repository.dart#L61) | `MoneyRepository.saveMonthlyBudget()` | `/users/{uid}/budgets/{month}` | Budget set/updated | `{'amount': amount}` | Yes | Yes (via Queue) | Yes (catch & queue) |
| [money_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/money_tracker/repository/money_repository.dart#L78) | `MoneyRepository.saveTransaction()` | `/users/{uid}/transactions/{id}` | Transaction saved | `tx.toMap()` | Yes | Yes (via Queue) | Yes (catch & queue) |
| [money_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/money_tracker/repository/money_repository.dart#L93) | `MoneyRepository.deleteTransaction()`| `/users/{uid}/transactions/{id}` | Transaction deleted | Delete action | Yes | Yes (via Queue) | Yes (catch & queue) |
| [money_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/money_tracker/repository/money_repository.dart#L107) | `MoneyRepository.saveMonthlySummary()`| `/users/{uid}/monthlySummaries/{month}`| Transaction added/updated | `summary.toMap()` | Yes | Yes (via Queue) | Yes (catch & queue) |
| [settings_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/settings/repository/settings_repository.dart#L45) | `SettingsRepository.saveSettings()` | `/users/{uid}/settings/profile` | Theme/Setting changed | `settings.toMap()` | Yes | Yes (via Queue) | Yes (catch & queue) |
| [auth_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/user_management/services/auth_service.dart#L90) | `AuthService.loginWithUsername()` | `/users/{uid}/settings/profile` | User Login | `profile.toMap()` | No (Direct Auth) | No | Yes (log warning) |

---

## 10. DIRECT SCREEN → FIRESTORE CONNECTION AUDIT

### Categorization of Data Access:
- **Category A (Screen directly reads Firestore):** **0 occurrences**.
- **Category B (Screen indirectly reads Firestore through repository):** **0 occurrences** (Screens read from Repositories, which read from Hive local storage).
- **Category C (Repository reads Hive):** **100% of Screen UI Reads** (`TaskRepository.getTasks()`, `HabitRepository.getHabits()`, `MoneyRepository.getTransactions()`, `SettingsRepository.getSettings()`, `DashboardRepository.getDashboardData()`).
- **Category D (Repository reads Firestore):** **0 occurrences**.
- **Category E (Repository writes to Hive and Firestore):** **100% of Data Mutations** (Repositories write to local Hive box first, then immediately attempt cloud write to Firestore, queuing on network failure).
- **Category F (Unknown):** **0 occurrences**.

---

## 11. REPOSITORY MAP

| Repository | Local Data Source | Cloud Data Source | Reads Hive? | Reads Firestore? | Writes Hive? | Writes Firestore? | Syncs Both? | Uses `FirebaseAuth` UID? | Hardcoded UID? |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `TaskRepository` | `tasks_box` | `/users/{uid}/tasks` | Yes | No | Yes | Yes | Yes | Yes (via provider) | No |
| `HabitRepository` | `habits_box`, `habit_entries_box` | `/users/{uid}/habits`, `/users/{uid}/habitEntries` | Yes | No | Yes | Yes | Yes | Yes (via provider) | No |
| `MoneyRepository` | `money_box`, `settings_box` | `/users/{uid}/transactions`, `/users/{uid}/budgets`, `/users/{uid}/monthlySummaries` | Yes | No | Yes | Yes | Yes | Yes (via provider) | No |
| `SettingsRepository` | `settings_box` | `/users/{uid}/settings/profile` | Yes | No | Yes | Yes | Yes | Yes (via provider) | No |
| `DashboardRepository` | Reads Task, Habit, Money repos | None | Yes | No | No | No | No | N/A | No |

---

## 12. EXISTING SYNCHRONIZATION MECHANISMS

Arc currently has a basic sync implementation in `SyncService` and repo queue boxes:

- **Pending Action Queues:** `tasks_sync_queue_box`, `habits_sync_queue_box`, `money_sync_queue_box`, `settings_sync_queued`.
- **Conflict Handling:** Simple timestamp check (`remoteTask.updatedAt.isAfter(localTask.updatedAt)`).
- **Retry Logic:** Iterates over queue keys during `syncPending()`. Stops on network exception.
- **Missing Architecture Components:**
  - ❌ No rolling 24-hour sync frequency limits (e.g. max 2 full syncs per 24h).
  - ❌ No minimum interval check (e.g. 12-hour minimum wait between full syncs).
  - ❌ No pre-logout mandatory pending queue sync.
  - ❌ No stream listener lifecycle management tied to network state.

---

## 13. APP STARTUP FLOW

```
                          +-------------------------+
                          |       APP LAUNCH        |
                          +------------+------------+
                                       |
                                       v
                          +-------------------------+
                          | Firebase.initializeApp()|
                          +------------+------------+
                                       |
                                       v
                          +-------------------------+
                          |   HiveService.init()    |
                          |  (Opens Base Boxes)     |
                          +------------+------------+
                                       |
                                       v
                          +-------------------------+
                          | FirebaseAuth.instance   |
                          | (Restores User Session) |
                          +------------+------------+
                                       |
                                       v
                          +-------------------------+
                          |   SyncInitializer()     |
                          +------------+------------+
                                       |
                   +-------------------+-------------------+
                   |                                       |
                   v                                       v
   +-------------------------------+       +-------------------------------+
   | pullInitialDataFromFirestore()|       |    startRealTimeSync()        |
   | (7 Collection Bulk Reads)     |       | (6 Real-time Stream Listeners)|
   +---------------+---------------+       +---------------+---------------+
                   |                                       |
                   +-------------------+-------------------+
                                       |
                                       v
                          +-------------------------+
                          |    Dashboard Screen     |
                          +-------------------------+
```

---

## 14. CURRENT LOGOUT FLOW

```
                          +-------------------------+
                          |     SettingsScreen      |
                          |   (User Taps Logout)    |
                          +------------+------------+
                                       |
                                       v
                          +-------------------------+
                          |   Confirmation Dialog   |
                          +------------+------------+
                                       |
                                       v
                          +-------------------------+
                          |  _authService.logout()  |
                          | (FirebaseAuth.signOut())|
                          +------------+------------+
                                       |
                                       v
                          +-------------------------+
                          | resetToLegacy()         |
                          | (Provider Reset)        |
                          +------------+------------+
                                       |
                                       v
                          +-------------------------+
                          |    context.go('/login') |
                          +-------------------------+

  ❌ WARNING: Pending Hive sync queues are NOT flushed before signOut().
  ❌ WARNING: Local Hive boxes are NOT cleared or closed upon logout.
```

---

## 15. LOCAL CACHE BEHAVIOR

- **App Closed:** Hive flushes dirty pages to local storage files. Data retained.
- **App Restarted:** Base Hive boxes re-opened. State hydrated from local disk.
- **Offline Mode:** UI loads cleanly from Hive. Mutations are saved to Hive & queued in `*_sync_queue_box`.
- **User Logged Out:** Hive data remains untouched in global boxes.
- **Another User Logs In:** Hive returns previous user's local data from base boxes until Firestore sync responds.

---

## 16. DATA OWNERSHIP MATRIX

| Entity | Local Owner | Cloud Owner | Auth Owner | Current Sync Relationship |
| :--- | :--- | :--- | :--- | :--- |
| **Task** | Hive (`tasks_box`) | Firestore (`/users/{uid}/tasks`) | Firebase UID | Immediate write to both; Background listener sync |
| **Habit** | Hive (`habits_box`) | Firestore (`/users/{uid}/habits`) | Firebase UID | Immediate write to both; Background listener sync |
| **Habit Entry** | Hive (`habit_entries_box`) | Firestore (`/users/{uid}/habitEntries`) | Firebase UID | Immediate write to both; Background listener sync |
| **Transaction** | Hive (`money_box`) | Firestore (`/users/{uid}/transactions`) | Firebase UID | Immediate write to both; Background listener sync |
| **Budget** | Hive (`settings_box`) | Firestore (`/users/{uid}/budgets`) | Firebase UID | Immediate write to both; Background listener sync |
| **Monthly Summary**| Hive (`settings_box`) | Firestore (`/users/{uid}/monthlySummaries`) | Firebase UID | Immediate write to both; Manual/Triggered sync |
| **Settings** | Hive (`settings_box`) | Firestore (`/users/{uid}/settings/profile`) | Firebase UID | Immediate write to both; Background listener sync |

---

## 17. FIRESTORE USAGE HOTSPOTS

Based strictly on code inspection:
1. **App Startup Bulk Pull:** `pullInitialDataFromFirestore()` triggers **7 collection reads** every time the app launches, regardless of how recently sync ran.
2. **6 Active Real-time Listeners:** `startRealTimeSync()` creates listeners for `tasks`, `habits`, `habitEntries`, `transactions`, `budgets`, `settings`. Every document change on server fires a snapshot.
3. **Eager Per-Edit Writes:** Every single toggle, task creation, or setting edit fires an immediate network write to Firestore.

---

## 18. FIREBASE QUOTA RISK ASSESSMENT

### Qualitative Risk Rating: 🟠 **MEDIUM-HIGH RISK**

### Reasoning:
- While document volumes for an individual user are small (e.g. ~230 documents), executing 7 full collection `.get()` calls on every app startup combined with 6 active real-time listeners across multiple users will generate thousands of unnecessary read operations daily.
- Without rate-limiting or 24-hour sync throttling, frequent app launches or background re-attaches will rapidly consume free-tier quota limits.

---

## 19. MULTI-USER AUTHENTICATION INTEGRATION

- `FirebaseAuth.instance.currentUser` serves as the primary authentication identity.
- `UserContextNotifier` listens to `authStateChanges()` and broadcasts `UserContext(userId: uid, profile: profile)`.
- All Riverpod repository providers (`taskRepositoryProvider`, etc.) watch `userContextProvider` and instantiate repositories with `userId = userContext.userId`.
- Repositories correctly construct cloud Firestore paths (`/users/{uid}/...`).
- **Defect Area:** Repositories fail to open user-scoped Hive boxes, reverting to global base boxes.

---

## 20. CURRENT ARCHITECTURE VS DESIRED ARCHITECTURE

```
CURRENT ARCHITECTURE (HYBRID / UNTHROTTLED):
  App Startup ──► 7x Firestore .get() Reads ──► Overwrite Hive Base Boxes
  UI Edits ──► Write Local Hive ──► Eager Firestore .set() Write
  Background ──► 6x Active Real-time Snapshots Streams

PROPOSED FUTURE ARCHITECTURE (HIVE-FIRST / THROTTLED SYNC ENGINE):
                 FIREBASE AUTH
                      │
                      ▼
               AUTHENTICATED UID
                      │
                      ▼
                 SYNC ENGINE
                 (Throttled: Max 2 Syncs/24h, 12h Min Interval, Pre-logout Flush)
                 ↙         ↘
            FIRESTORE     HIVE
            Cloud Data   User-Isolated Local Data
                           │
                           ▼
                      APP SCREENS
```

---

## 21. RECOMMENDED CHANGES FOR STEP 2

1. **Fix Hive User Isolation:**
   - Update `HiveService` to dynamically open user-scoped boxes (`tasks_box_{uid}`) upon authentication before Repositories read local data.
   - Clear or close user-scoped boxes upon logout.
2. **Implement Sync Engine & Throttling:**
   - Create a dedicated `SyncManager` engine enforcing max 2 full syncs per 24 hours with a minimum 12-hour interval.
   - Store `last_full_sync_timestamp` in user-scoped settings.
3. **Implement Pre-Logout Sync:**
   - Modify `_handleLogout()` to trigger a mandatory `syncAllPending()` before calling `FirebaseAuth.signOut()`.
4. **Remove Continuous Real-time Stream Listeners:**
   - Replace active snapshot listeners with on-demand or periodic throttled sync.

---

## 22. FILES THAT WOULD NEED MODIFICATION LATER

The following files will need to be updated in subsequent implementation steps:
- [lib/core/services/hive_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/hive_service.dart)
- [lib/core/services/sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart)
- [lib/features/user_management/services/auth_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/user_management/services/auth_service.dart)
- [lib/features/settings/screens/settings_screen.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/settings/screens/settings_screen.dart)
- [lib/main.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/main.dart)
- [lib/providers/global_providers.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/providers/global_providers.dart)

---

## 23. RISKS

1. **User Data Bleed Risk:** Until Hive boxes are properly scoped per UID, logging into a different account on the same device presents a local privacy leak.
2. **Data Loss on Logout Risk:** Unsynced offline changes in queue boxes are lost or stranded if a user logs out without flushing pending queues.
3. **Quota Depletion Risk:** Real-time stream listeners running continuously consume unnecessary read operations.

---

## 24. FINAL AUDIT VERDICT

### 🟡 STEP 1 AUDIT COMPLETE — ISSUES REQUIRE REVIEW

---

## PART 21 — FILE MODIFICATION CHECK

```
Files modified during Step 1:
0

Firebase data modified:
0

Firestore documents modified:
0

Hive data modified:
0

Firebase Authentication modified:
0

Security Rules modified:
0
```

---

## END OF STEP 1 REPORT
