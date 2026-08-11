# Project Arc — Targeted Startup Performance & Architecture Audit

**Date:** 2026-08-11  
**Audit Status:** STRICTLY AUDIT ONLY (No production code was modified)  
**Target File:** `startup_performance_audit_report.md`  

---

## 1. Executive Summary

This targeted performance and architectural audit investigates the root causes of slow application startup, UI blocking behavior, and the infinite loading screen (`"Syncing your data..."`) in Project Arc.

### Key Finding
The primary reason users experience a blocked UI or freeze on `"Syncing your data..."` is that **[lib/main.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/main.dart#L83-L154) (`SyncInitializer`) places Cloud Firestore synchronization directly on the critical UI startup path before authentication and without error recovery.**

When `syncService.isFirstInstallAndEmpty()` returns `true` (which occurs on fresh installs, unauthenticated launches, or cleared local storage), `SyncInitializer` replaces the application router (`GoRouter` / `ProjectArcApp`) with a blocking splash screen and awaits `syncManager.performFullSync()`. If a network delay, offline state, or Firestore permission exception occurs, the error is rethrown up the call stack. Because `_startSyncProcess()` lacks a `try-catch` block, execution terminates before reaching `setState(() { _isFirstInstallSyncing = false; })`, permanently locking the application on `"Syncing your data..."`.

---

## 2. Actual Startup Flow

```
main() [lib/main.dart]
  │ (Synchronous / Async prep)
  ├── WidgetsFlutterBinding.ensureInitialized()
  ├── tz.initializeTimeZones()
  ├── await Firebase.initializeApp()               [Async I/O - Native Firebase SDK]
  ├── await HiveService().init()                   [Async File I/O - Registers Adapters & opens global boxes]
  ├── await NotificationService().init()          [Async Local Platform Call]
  └── runApp(ProviderScope(child: SyncInitializer(child: ProjectArcApp())))
        │
        ▼
SyncInitializer.initState() [lib/main.dart]
  └── _startSyncProcess()
        │
        ├── ref.read(userContextProvider)          [Initializes UserContextNotifier]
        │     └── FirebaseAuth.instance.currentUser check & authStateChanges() listener
        │
        ├── if (userContext.isAuthenticated) await HiveService().ensureUserBoxesOpened(uid)
        │
        ├── syncService.isFirstInstallAndEmpty()   [Checks initial_sync_completed & local box length]
        │     │
        │     ├── [IF TRUE] → Fresh Install / Unauthenticated / Empty Local Boxes
        │     │     ├── setState(() { _isFirstInstallSyncing = true; })  <-- Renders "Syncing your data..."
        │     │     ├── await syncManager.performFullSync()              <-- CRITICAL BLOCKING FIRESTORE READ
        │     │     │     └── syncService.pullInitialDataFromFirestore()  <-- 7 Sequential Cloud Queries (10s timeout each)
        │     │     │           └── ON ERROR: rethrow (Skipped setState(false) → PERMANENT FREEZE)
        │     │     ├── syncService.startRealTimeSync()
        │     │     └── setState(() { _isFirstInstallSyncing = false; })
        │     │
        │     └── [IF FALSE] → Populated Hive / Previous Sync Complete
        │           ├── syncManager.performFullSync() (un-awaited background)
        │           └── syncService.startRealTimeSync()
        │
        ▼
SyncInitializer.build()
  ├── IF _isFirstInstallSyncing == true  → Returns MaterialApp with blocking "Syncing your data..." Scaffold
  └── IF _isFirstInstallSyncing == false → Returns widget.child (ProjectArcApp -> MaterialApp.router -> GoRouter)
```

---

## 3. Intended Startup Flow

```
APP LAUNCH
  ↓
Flutter & Firebase Initialization
  ↓
Hive Initialization & Box Readiness
  ↓
Check Firebase Authentication State (currentUser)
  ├── UNAUTHENTICATED → Mount GoRouter → Display LoginScreen (/login) IMMEDIATELY
  └── AUTHENTICATED
        ↓
     Retrieve User UID
        ↓
     Open User-Scoped Hive Boxes (tasks_box_{uid}, habits_box_{uid}, etc.)
        ↓
     Render Main Application IMMEDIATELY from Local Hive Data
        ↓
     Trigger Background SyncManager (Non-blocking)
        ↓
     Check 12-hour cooldown & 2-per-24h rolling limit
        ↓
     Synchronize Firestore data in background → Reactively update Hive → UI updates seamlessly
```

---

## 4. Complete Startup Call Graph

```
main() [lib/main.dart:14]
 ├── Firebase.initializeApp() [lib/main.dart:28]
 ├── HiveService.init() [lib/main.dart:38]
 │    ├── Hive.initFlutter()
 │    ├── Hive.registerAdapter(0..3)
 │    └── Hive.openBox(tasks_box, habits_box, money_box, settings_box, etc.)
 ├── NotificationService.init() [lib/main.dart:45]
 └── runApp(ProviderScope) [lib/main.dart:54]
       └── SyncInitializer [lib/main.dart:66]
            └── _startSyncProcess() [lib/main.dart:83]
                 ├── ref.read(userContextProvider) [lib/providers/global_providers.dart:83]
                 │    └── UserContextNotifier._initAuthListener() [user_context_provider.dart:18]
                 │         ├── FirebaseAuth.currentUser check
                 │         └── HiveService().ensureUserBoxesOpened(uid) [hive_service.dart:83]
                 ├── syncService.isFirstInstallAndEmpty() [sync_service.dart:65]
                 │    ├── HiveService().getUserBox(tasksBoxName, userId)
                 │    └── Checks taskBox.isEmpty && habitBox.isEmpty && moneyBox.isEmpty
                 ├── syncManager.performFullSync() [sync_manager.dart:57]
                 │    ├── canFullSync() [sync_manager.dart:26] (Bypassed if isFirstRunEmpty)
                 │    └── syncService.pullInitialDataFromFirestore() [sync_service.dart:91]
                 │         ├── _collectionRef('tasks').get().timeout(10s)
                 │         ├── _collectionRef('habits').get().timeout(10s)
                 │         ├── _collectionRef('habitEntries').get().timeout(10s)
                 │         ├── _collectionRef('transactions').get().timeout(10s)
                 │         ├── _collectionRef('budgets').get().timeout(10s)
                 │         ├── _collectionRef('monthlySummaries').get().timeout(10s)
                 │         ├── _settingsDocRef().get().timeout(10s)
                 │         ├── syncAllPending() [sync_service.dart:73]
                 │         └── put('initial_sync_completed', true)
                 └── syncService.startRealTimeSync() [sync_service.dart:199]
                      └── Listeners on 7 Firestore collections
```

---

## 5. Firestore Startup Read Audit

| Startup Operation | Source File & Function | Target Collection / Path | Query Type | Potential Docs Read | Blocks UI? | Auth Required? | Cooldown Checked? | Recommendation |
|---|---|---|---|---|---|---|---|---|
| Initial Task Sync | `sync_service.dart` `pullInitialDataFromFirestore()` | `users/{uid}/tasks` or `tasks` | `.get()` (Full collection) | 0 – 1,000+ | **YES** (if first run) | YES | **NO** (Bypassed on first run) | Move to background post-render |
| Initial Habit Sync | `sync_service.dart` `pullInitialDataFromFirestore()` | `users/{uid}/habits` or `habits` | `.get()` (Full collection) | 0 – 500+ | **YES** (if first run) | YES | **NO** (Bypassed on first run) | Move to background post-render |
| Initial Entry Sync | `sync_service.dart` `pullInitialDataFromFirestore()` | `users/{uid}/habitEntries` or `habitEntries` | `.get()` (Full collection) | 0 – 5,000+ | **YES** (if first run) | YES | **NO** (Bypassed on first run) | Move to background post-render |
| Initial Transaction Sync | `sync_service.dart` `pullInitialDataFromFirestore()` | `users/{uid}/transactions` or `transactions` | `.get()` (Full collection) | 0 – 5,000+ | **YES** (if first run) | YES | **NO** (Bypassed on first run) | Move to background post-render |
| Initial Budget Sync | `sync_service.dart` `pullInitialDataFromFirestore()` | `users/{uid}/budgets` or `budgets` | `.get()` (Full collection) | 0 – 120+ | **YES** (if first run) | YES | **NO** (Bypassed on first run) | Move to background post-render |
| Initial Summary Sync | `sync_service.dart` `pullInitialDataFromFirestore()` | `users/{uid}/monthlySummaries` or `monthlySummaries` | `.get()` (Full collection) | 0 – 120+ | **YES** (if first run) | YES | **NO** (Bypassed on first run) | Move to background post-render |
| Initial Settings Sync | `sync_service.dart` `pullInitialDataFromFirestore()` | `users/{uid}/settings/profile` or `settings/global` | `.get()` (Single doc) | 1 | **YES** (if first run) | YES | **NO** (Bypassed on first run) | Move to background post-render |
| Real-time Snapshots | `sync_service.dart` `startRealTimeSync()` | 7 collections | `.snapshots()` | Continuous | NO | YES | N/A | Attach in background after login |

---

## 6. Hive Startup Audit

### Availability Timeline
1. **Global Hive Initialization**: `HiveService().init()` runs synchronously during `main()` before `runApp()`. Adapters are registered and default fallback boxes (`tasks_box`, `habits_box`, `habit_entries_box`, `money_box`, `settings_box`, queue boxes) are opened.
2. **User-Scoped Boxes**: `ensureUserBoxesOpened(userId)` is called as soon as `FirebaseAuth.instance.currentUser` is resolved by `UserContextNotifier`. Boxes (`tasks_box_{uid}`, etc.) are opened on disk.
3. **Local Data Readiness**: Local Hive data is **immediately readable** from disk before any network request occurs.

### Answers to Audit Questions
* **When is Hive initialized?** At app startup in `main()` via `await HiveService().init()`.
* **When are user-scoped boxes opened?** On `UserContextNotifier` initialization when `currentUser` is present, or upon login completion.
* **Are boxes opened before or after authentication?** Default fallback boxes are opened before auth; user-scoped boxes are opened immediately after user identity resolution.
* **Is Hive data available before Firestore synchronization begins?** **YES.** Local Hive boxes are fully open and populated from disk prior to network calls.
* **Can the Main App render entirely from Hive?** **YES.** All 5 repositories (`TaskRepository`, `HabitRepository`, `MoneyRepository`, `SettingsRepository`, `DashboardRepository`) read exclusively from Hive (`_box.values.toList()`).
* **Are any screens unnecessarily waiting for Firestore?** **YES.** `SyncInitializer` blocks the entire app router on fresh installs/unauthenticated runs while awaiting Firestore queries.
* **Are there any repositories that directly read Firestore instead of Hive during startup?** **NO.** Repositories only write to Firestore on mutation or flush pending queues. Reads are 100% Hive-first.

---

## 7. Authentication Order Audit

### Sequence of Operations
```
FirebaseAuth.instance.currentUser
        ↓
Retrieve User UID (or null if unauthenticated)
        ↓
UserContextNotifier (state = UserContext(userId: uid))
        ↓
HiveService.ensureUserBoxesOpened(uid)
        ↓
[PROBLEM AREA] SyncInitializer attempts Firestore sync regardless of auth status
```

### Critical Flaw Identified
In `SyncInitializer._startSyncProcess()` ([lib/main.dart:83-116](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/main.dart#L83-L116)):
When an **unauthenticated user** launches the app for the first time:
1. `UserContext.userId` is `null`.
2. `syncService.isFirstInstallAndEmpty()` queries legacy/null user boxes. Since they are empty on fresh install, it returns `true`.
3. `SyncInitializer` sets `_isFirstInstallSyncing = true`.
4. It invokes `syncManager.performFullSync()`.
5. `pullInitialDataFromFirestore()` attempts to read root Firestore collections (`tasks`, `habits`, etc.) using `_collectionRef('tasks')` (which falls back to root collection when `_userId` is `null`).
6. Cloud Firestore rejects unauthenticated reads or times out, throwing an exception.
7. **Risk**: Unauthenticated users are trapped on `"Syncing your data..."` before ever seeing the Login Screen.

---

## 8. SyncManager Audit

### Cooldown Protection Analysis
`SyncManager.canFullSync()` enforces:
1. **12-hour minimum interval** between full syncs.
2. **Maximum 2 full syncs** in a 24-hour rolling window.

### Bypass Vulnerability
In `SyncManager.performFullSync()` ([lib/core/services/sync_manager.dart:67](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_manager.dart#L67)):
```dart
final isFirstRunEmpty = syncService.isFirstInstallAndEmpty();

if (!isFirstRunEmpty && !forceManual && !canFullSync(now: currentTime)) {
  // Blocked by cooldown
  await flushPendingChanges(syncService);
  return;
}
```
**Finding**: When `isFirstRunEmpty` is `true`, `canFullSync()` is **completely bypassed**. Any launch where `initial_sync_completed` is `false` or local boxes are empty will trigger an un-cooldowned full Firestore read.

### Call Graph & Bypass Pathways

```
[STARTUP]
  │
  ▼
SyncInitializer._startSyncProcess() [lib/main.dart]
  │
  ├──► isFirstInstallAndEmpty() == true
  │      │
  │      ▼
  │   SyncManager.performFullSync()
  │      │  (BYPASSES canFullSync() because isFirstRunEmpty == true!)
  │      ▼
  │   SyncService.pullInitialDataFromFirestore()  <-- BLOCKS UI
  │
  └──► isFirstInstallAndEmpty() == false
         │
         ▼
      SyncManager.performFullSync() (un-awaited background execution)
         │  (Checks canFullSync() -> 12h & 2-per-24h rules apply)
         ▼
      SyncService.pullInitialDataFromFirestore()
```

---

## 9. Synchronization Blocking Analysis

| Operation | Awaited by Startup? | Blocks UI? | Requires Network? | Reads Firestore? | Timeout Defined? | Exception Behavior |
|---|---|---|---|---|---|---|
| `performFullSync()` | **YES** (if first run) | **YES** | YES | YES | 10s per query | Rethrows error |
| `pullInitialDataFromFirestore()` | **YES** (if first run) | **YES** | YES | YES (7 queries) | 10s per query | Rethrows error |
| `syncAllPending()` | **YES** (during pull) | **YES** | YES | NO (Writes only) | None | Catches & logs notice |
| `startRealTimeSync()` | NO | NO | YES | YES (Listeners) | None | Suppresses errors |
| `stopRealTimeSync()` | NO | NO | NO | NO | None | Clean cancellation |
| Snapshot Listeners | NO | NO | YES | YES | None | Background handling |

---

## 10. Real-Time Listener Audit

### Listener Inventory
`SyncService.startRealTimeSync()` initializes **7 active snapshot listeners**:
1. `tasks` collection snapshot stream
2. `habits` collection snapshot stream
3. `habitEntries` collection snapshot stream
4. `transactions` collection snapshot stream
5. `budgets` collection snapshot stream
6. `monthlySummaries` collection snapshot stream
7. `settings` document snapshot stream

### Audit Findings
* **Creation Point**: Attached during `_startSyncProcess()` in `SyncInitializer`.
* **User Scoping**: Correctly scoped to `users/{uid}/{collection}` when `_userId` is populated.
* **UI Impact**: Non-blocking. Updates local Hive boxes reactively when remote changes occur.
* **Idle Reads**: Firestore charges document read operations whenever documents change remotely.

---

## 11. Startup Failure Analysis

### Control Flow Failure Mechanics
In `SyncInitializer._startSyncProcess()` ([lib/main.dart:83-116](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/main.dart#L83-L116)):

```dart
if (syncService.isFirstInstallAndEmpty()) {
  setState(() {
    _isFirstInstallSyncing = true;
  });
  // 1. If performFullSync throws an exception (offline, timeout, permission error):
  await syncManager.performFullSync(syncService: syncService, onRefreshState: refreshAllNotifiers);
  
  // 2. THIS CODE IS NEVER REACHED WHEN AN EXCEPTION IS THROWN:
  syncService.startRealTimeSync(onRefreshState: refreshAllNotifiers);
  if (mounted) {
    setState(() {
      _isFirstInstallSyncing = false; // <-- SKIPPED!
    });
  }
}
```

### Scenario Test Matrix
* **No Internet / Offline**: `pullInitialDataFromFirestore` throws timeout/socket exception $ightarrow$ `rethrow` $ightarrow$ `_isFirstInstallSyncing` stays `true` forever.
* **Slow Internet**: 7 sequential queries with 10-second timeouts can block the splash screen for up to **70 seconds**.
* **Firestore Permission Error**: Unauthenticated user triggers permission error $ightarrow$ `rethrow` $ightarrow$ App frozen on splash screen before reaching Login.
* **First Installation**: Automatically triggers blocking sync path.

---

## 12. Startup Performance Timeline

| Scenario | Local Hive Read | Network Required? | Blocking UI Time | Background Operations |
|---|---|---|---|---|
| **A. Fresh Installation** | Immediate (Empty) | YES | **7s – 70s+ (or FREEZE if error)** | Pull 7 collections, attach listeners |
| **B. Existing User (Populated Hive)** | Immediate | NO | **0 ms** (Instant UI render) | Non-blocking background sync (if allowed by 12h cooldown) |
| **C. Existing User (Empty Hive)** | Immediate (Empty) | YES | **7s – 70s+ (or FREEZE if error)** | Pull 7 collections, attach listeners |
| **D. Offline Launch (Populated Hive)** | Immediate | NO | **0 ms** | Sync skipped gracefully |
| **E. Offline Launch (Fresh Install)** | Immediate (Empty) | YES (Times out) | **PERMANENT FREEZE** | Exception rethrown, blocks login |
| **F. Launch on 12h Cooldown** | Immediate | NO | **0 ms** | Full sync skipped; queue flush only |

---

## 13. Duplicate Initialization Findings

1. **`HiveService.ensureUserBoxesOpened()`**:
   Called in **5 separate places**:
   - `main.dart` line 86
   - `user_context_provider.dart` line 50 (`_setFromFirebaseUser`)
   - `user_context_provider.dart` line 66 (`setActiveUser`)
   - `auth_service.dart` line 80 (`loginWithUsername`)
   - `HiveService` internally
   *Impact*: Low performance overhead (Hive checks `isBoxOpen`), but creates unnecessary redundant call chains during startup.

2. **Repository Provider Instantiation**:
   `global_providers.dart` re-instantiates repositories when `userContextProvider` changes, causing Hive boxes to be re-acquired.

---

## 14. Legacy Startup Logic Findings

* **`SyncService.isFirstInstallAndEmpty()`**: Evaluates legacy null-user boxes (`getUserBox(name, null)`), which can cause unauthenticated sessions to execute root Firestore collection queries (`tasks`, `habits`, `transactions`).
* **Root Collection Fallback**: `_collectionRef()` in `sync_service.dart` falls back to root collection `tasks` when `_userId == null`. Root collection reads fail under multi-user security rules.

---

## 15. Performance Bottleneck Matrix

| Priority | Problem | File | Function | Root Cause | User Impact | Block Startup? | Recommended Direction |
|---|---|---|---|---|---|---|---|
| 🔴 **CRITICAL** | Missing `try-catch` in `SyncInitializer` | `lib/main.dart` | `_startSyncProcess()` | Unhandled rethrow from `performFullSync()` skips `setState(false)` | Permanent freeze on `"Syncing your data..."` | **YES** | Wrap sync call in `try-finally` to ensure `_isFirstInstallSyncing = false` always executes. |
| 🔴 **CRITICAL** | Unauthenticated Initial Sync Attempt | `lib/main.dart` & `sync_service.dart` | `isFirstInstallAndEmpty()` | Evaluates `true` for unauthenticated users, querying root Firestore | Unauthenticated users trapped before Login Screen | **YES** | Require `userContext.isAuthenticated` before triggering first-install sync. |
| 🟠 **HIGH** | Sequential 7-Collection Firestore Pull | `sync_service.dart` | `pullInitialDataFromFirestore()` | 7 await calls run sequentially (10s timeout each = up to 70s delay) | Excessive wait time on fresh install | **YES** | Run queries in parallel via `Future.wait()`, or move pull to background post-login. |
| 🟡 **MEDIUM** | `canFullSync()` Cooldown Bypass | `sync_manager.dart` | `performFullSync()` | `isFirstRunEmpty` bypasses 12-hour cooldown check unconditionally | Unnecessary network requests on empty box edge cases | NO | Validate auth & user state before bypassing cooldown. |
| 🟢 **LOW** | Redundant `ensureUserBoxesOpened` Calls | `user_context_provider.dart` & `main.dart` | `_startSyncProcess()` | Called across multiple layers during startup | Minor redundant Hive box state checks | NO | Centralize box opening in `UserContextNotifier`. |

---

## 16. Answer to the Most Important Question

### Question:
> *"If the application followed the intended Hive-first architecture correctly, should a user ever have to wait for Firestore before seeing the Login screen or Main App?"*

### Answer:
**NO. ABSOLUTELY NOT.**

Under a true Hive-first architecture, local Hive storage is initialized synchronously on disk before the app UI mounts. The application can render the Login Screen (if unauthenticated) or the Main App (from local Hive boxes) in **0 milliseconds**. Cloud Firestore synchronization should run entirely in the background without blocking the UI router.

### What currently prevents that ideal workflow:
`SyncInitializer` in `lib/main.dart` explicitly intercepts the startup tree and conditionally replaces `ProjectArcApp` with a blocking full-screen Scaffold while awaiting network Firestore queries.

---

## 17. Recommended Target Architecture

```
APP LAUNCH
   │
   ├── Flutter & Firebase Core initialization
   ├── Hive initialization & box opening
   └── Mount MaterialApp.router (GoRouter) IMMEDIATELY  <-- ZERO UI BLOCKING
         │
         ├── UNAUTHENTICATED → Display LoginScreen (/login)
         │
         └── AUTHENTICATED
               │
               ├── Render Main App (/dashboard) IMMEDIATELY from Hive
               │
               └── Trigger Background SyncManager (Non-blocking)
                     │
                     ├── Check 12h Cooldown & 24h Rolling Limit
                     │
                     └── If allowed → Pull Firestore changes in background → Reactively update Hive
```

---

## 18. Exact Files That Would Need Modification in a Future Implementation Phase

1. [lib/main.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/main.dart) — Modify `SyncInitializer` to be non-blocking and add error handling.
2. [lib/core/services/sync_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_service.dart) — Add authentication check to `isFirstInstallAndEmpty()` and parallelize Firestore pulls.
3. [lib/core/services/sync_manager.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/sync_manager.dart) — Ensure cooldown checks apply safely across authenticated states.

---

## 19. Priority Order for Future Fixes

1. **Priority 1 (Critical Safety Fix)**: Add `try-finally` block to `_startSyncProcess()` in `lib/main.dart` to guarantee `_isFirstInstallSyncing = false` is always called, eliminating the infinite loading freeze.
2. **Priority 2 (Authentication Scoping)**: Ensure `isFirstInstallAndEmpty()` and initial sync only run when `userContext.isAuthenticated == true`. Unauthenticated users must immediately reach `/login`.
3. **Priority 3 (UI Unblocking)**: Remove blocking Scaffold from `SyncInitializer` so the app renders immediately from Hive data while sync runs in the background.
4. **Priority 4 (Network Optimization)**: Parallelize Firestore collection queries in `pullInitialDataFromFirestore()` using `Future.wait()`.

---

## 20. Final Verdict

### CURRENT STARTUP STATUS
🔴 **CRITICAL PERFORMANCE ISSUE**

### PRIMARY BOTTLENECK
`SyncInitializer` in `lib/main.dart` awaits `syncManager.performFullSync()` on the critical UI rendering path without error handling. Any network timeout, offline state, or Firestore permission exception rethrows out of `_startSyncProcess()`, skipping `setState(() { _isFirstInstallSyncing = false; })` and permanently trapping the user on the `"Syncing your data..."` dark screen.

### SECONDARY BOTTLENECKS
1. `isFirstInstallAndEmpty()` triggers initial sync attempts for unauthenticated users, attempting to read root Firestore collections before login.
2. `pullInitialDataFromFirestore()` executes 7 sequential Firestore queries with 10-second timeouts each (up to 70 seconds delay on slow connections).
3. `isFirstRunEmpty` bypasses `SyncManager.canFullSync()` 12-hour cooldown protection.

### FIRESTORE STARTUP IMPACT
Firestore is **currently blocking startup**. On fresh installs or unauthenticated sessions, the app halts UI rendering until Firestore collection reads complete or time out.

### HIVE STARTUP IMPACT
Hive is initialized correctly and local data is available immediately from disk, but its instant rendering capability is **currently bypassed** on initial runs by `SyncInitializer`.

### AUTHENTICATION STARTUP IMPACT
Authentication state is checked, but `SyncInitializer` attempts Firestore reads **before verifying if the user is logged in**, violating user isolation and triggering permission errors for unauthenticated users.

### RECOMMENDED NEXT STEP
Approve a targeted implementation phase to:
1. Add error handling (`try-finally`) to `SyncInitializer._startSyncProcess()` in `lib/main.dart`.
2. Restrict initial sync execution to authenticated users only (`userContext.isAuthenticated`).
3. Make initial synchronization non-blocking so the app renders immediately from Hive.
