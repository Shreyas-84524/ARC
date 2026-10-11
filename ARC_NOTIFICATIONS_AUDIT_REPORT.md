# ARC — Notifications Reliability Audit & Repair Report

**Date:** 2026-10-11  
**Project:** ARC (Activity, Routine & Capital)  
**Target:** Local Notification Reliability, Scheduling Architecture & Multi-User Isolation  
**Status:** Audit Completed & All Repairs Implemented and Verified  

---

## Executive Summary

An exhaustive audit of the ARC notification subsystem was conducted to address scheduling unreliability, timezone hardcoding, missing individual habit reminders, and cross-session notification leakage. 

### Key Repairs Completed:
1. **Dynamic Timezone Resolution:** Eliminated hardcoded `'Asia/Kolkata'` fallback in `NotificationService`. Implemented dynamic Olson location resolution with standard OS/Windows timezone mapping (e.g., `'India Standard Time'` $\to$ `'Asia/Kolkata'`, `'Eastern Standard Time'` $\to$ `'America/New_York'`) and UTC offset fallback matching.
2. **Individual Habit Reminders:** Implemented `scheduleHabitReminder(Habit)` with `DateTimeComponents.time` daily recurrence. Previously, `HabitsNotifier` only scheduled an evening summary alert, ignoring each habit's configured `reminderTime`.
3. **Deterministic Collision-Free ID Architecture:** Replaced ad-hoc hashing with mathematical disjoint ID partitions:
   - System/Recurring fixed alerts: $< 1,000,000$
   - Task 5-minute pre-alerts: $[10,000,000, 410,000,000)$
   - Task deadline alerts: $[410,000,000, 810,000,000)$
   - Habit individual reminders: $[1,000,000,000, 1,400,000,000)$
4. **Centralized Reconciliation Engine:** Added `reconcileScheduledNotifications({tasks, habits, hasTodayTx})` triggered on app launch, cold start, and user login via `SyncInitializer`.
5. **Multi-User Notification Isolation:** Added `cancelAllUserNotifications()` wired directly to `AuthService.logout()` and `SettingsScreen._handleLogout()`. User A's scheduled notifications are purged immediately upon logout, and User B's notifications are reconciled upon login.
6. **Web Runtime Safety:** Wrapped `Platform.isAndroid` / `Platform.isIOS` checks with `kIsWeb` to prevent runtime platform exceptions in browser builds.
7. **Quality Gates:** 100% test pass rate (210/210 tests passing), 0 static analysis issues (`flutter analyze` clean), and production web build compilation succeeded.

---

## Step 1 — Audit Existing Notification Architecture

### Subsystem Overview
The ARC notification system resides primarily in:
- `lib/core/notifications/notification_service.dart` (Core singleton and notification scheduler)
- `lib/providers/global_providers.dart` (`HabitsNotifier` & `TasksNotifier` reminder wiring)
- `lib/features/user_management/services/auth_service.dart` (Session lifecycle cleanup)
- `lib/features/settings/screens/settings_screen.dart` (User toggles & logout handler)
- `lib/main.dart` (Boot initialization and `SyncInitializer` startup reconciliation)

### Dependencies
- `flutter_local_notifications: ^18.0.1` — Native Android/iOS notification channel integration and exact alarm scheduling.
- `timezone: ^0.10.0` — Olson timezone database and `TZDateTime` calculations.
- `flutter_riverpod: ^2.6.1` — State management and reactive data hooks.

---

## Step 2 — Determine Notification Type

**Architecture Selected:** Pure Local Scheduled Notifications (`flutter_local_notifications` + `timezone`).

### Architectural Rationale:
- **Offline-First:** ARC is designed around Hive offline-first data stores. Task and habit reminders must fire reliably regardless of network connectivity, airplane mode, or server availability.
- **Privacy & Security:** ARC reminders contain user-sensitive activity and financial titles. Local scheduling requires zero transmission of personal task details to external servers or cloud messaging brokers.
- **Battery & Quota Efficiency:** Pure local exact alarms via Android AlarmManager and iOS `UNUserNotificationCenter` avoid background push data usage and push latency.

---

## Step 3 — Initialization Audit

- **Single Point of Initialization:** `NotificationService().initialize()` is called once during app bootstrap in `main()` before `runApp(ProviderScope(...))` executes.
- **Singleton Pattern:** Implemented via Dart factory constructor `NotificationService._internal()`, ensuring state coherence across all widgets, notifiers, and services.
- **Web Safety:** Guarded all `dart:io` `Platform` checks using `kIsWeb`. In web mode, unsupported plugin calls return safe defaults (`false` / `true`) without crashing.
- **Plugin Channels:**
  - `arc_reminders` — High-importance channel with sound and vibration for task deadlines and habits.
  - `arc_money` — Default-importance channel for evening budget and transaction reminders.

---

## Step 4 — Background & App Lifecycle Handling

- Scheduled notifications use native platform scheduling APIs:
  - **Android:** `AlarmManager.setExactAndAllowWhileIdle()` via `AndroidScheduleMode.exactAllowWhileIdle`. Notifications trigger even when the device enters low-power Doze mode.
  - **iOS:** `UNCalendarNotificationTrigger` managed natively by `UNUserNotificationCenter`.
- App foregrounding / backgrounding does not alter scheduled alarms.
- Cold start re-verification occurs during `SyncInitializer._startSyncProcess()`.

---

## Step 5 — Model & Data Audit

### 1. `Task` (`lib/features/task_manager/models/task_model.dart`)
- `dueDate` (`DateTime?`): Scheduled date.
- `dueTime` (`String?`): Time string in `HH:mm` format.
- `completed` (`bool`): Completion flag. When `true`, all pending reminders are cancelled.

### 2. `Habit` (`lib/features/habit_tracker/models/habit_model.dart`)
- `reminderTime` (`String?`): Daily reminder time in `HH:mm` format (or `null`).
- `archived` / `deleted`: Handled via repository deletion or model updates.

### 3. User Preferences (`lib/features/settings/screens/settings_screen.dart`)
- Master notifications switch (`settings_notifications_enabled`).
- Task reminders switch (`settings_task_reminders_enabled`).
- Habit reminders switch (`settings_habit_reminders_enabled`).
- Money reminders switch (`settings_money_reminders_enabled`).

---

## Step 6 — Timezone Handling

### Root Cause Identified:
Previously, `_ensureLocalTimezone()` caught `TimezoneDatabaseException` and unconditionally assigned `tz.getLocation('Asia/Kolkata')`. This caused users outside UTC+5:30 to receive reminders at incorrect local times.

### Solution Implemented:
```dart
void _ensureLocalTimezone() {
  try {
    final String currentTimeZone = tz.local.name;
    if (currentTimeZone.isNotEmpty && currentTimeZone != 'UTC') return;
  } catch (_) {}

  // 1. Check DateTime.now().timeZoneName directly in Olson database
  final localPlatformTz = DateTime.now().timeZoneName;
  if (tz.timeZoneDatabase.locations.containsKey(localPlatformTz)) {
    tz.setLocalLocation(tz.getLocation(localPlatformTz));
    return;
  }

  // 2. Canonical mapping of Windows / OS names to Olson identifiers
  const winToOlson = {
    'India Standard Time': 'Asia/Kolkata',
    'Eastern Standard Time': 'America/New_York',
    'Pacific Standard Time': 'America/Los_Angeles',
    'Central Standard Time': 'America/Chicago',
    'GMT Standard Time': 'Europe/London',
    'W. Europe Standard Time': 'Europe/Berlin',
    'Singapore Standard Time': 'Asia/Singapore',
    'Tokyo Standard Time': 'Asia/Tokyo',
  };
  if (winToOlson.containsKey(localPlatformTz)) {
    final mapped = winToOlson[localPlatformTz]!;
    if (tz.timeZoneDatabase.locations.containsKey(mapped)) {
      tz.setLocalLocation(tz.getLocation(mapped));
      return;
    }
  }

  // 3. Offset match fallback
  final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
  for (final entry in tz.timeZoneDatabase.locations.entries) {
    if (entry.value.currentTimeZone.offset == offsetMs) {
      tz.setLocalLocation(entry.value);
      return;
    }
  }

  tz.setLocalLocation(tz.getLocation('UTC'));
}
```

---

## Step 7 — Notification ID Strategy

To prevent collisions between task notifications, habit notifications, and fixed system alerts, IDs are partitioned into non-overlapping mathematical domains:

```
[0 ---------------- 999,999]        -> Fixed System Alerts (Evening Habits, Money Reminders)
[10,000,000 ------ 409,999,999]     -> Task 5-Minute Pre-Alerts
[410,000,000 ----- 809,999,999]     -> Task Deadline Alerts
[1,000,000,000 --- 1,399,999,999]   -> Habit Individual Reminders
```

### Deterministic Hasher:
```dart
int _hashId(String id, int mod, int offset) {
  int hash = 5381;
  for (int i = 0; i < id.length; i++) {
    hash = ((hash << 5) + hash) + id.codeUnitAt(i);
    hash &= 0x7FFFFFFF; // keep positive 31-bit
  }
  return offset + (hash % mod);
}
```
- **Task 5m ID:** `_hashId(taskId, 400000000, 10000000)`
- **Task Deadline ID:** `_hashId(taskId, 400000000, 410000000)`
- **Habit Reminder ID:** `_hashId(habitId, 400000000, 1000000000)`

---

## Step 8 — Task Notification Lifecycle

1. **Schedule on Create/Update:** When a task is created or edited with a future `dueDate` and `dueTime`, `scheduleTaskReminders(task)`:
   - First cancels existing 5m and deadline notifications for `task.id` to prevent duplicates.
   - Computes exact `TZDateTime` for deadline and 5 minutes prior.
   - If `(deadline - 5m)` is in the future, schedules 5-minute pre-alert.
   - If deadline is in the future, schedules deadline alert.
2. **Cancellation on Complete:** When `task.completed == true`, `scheduleTaskReminders(task)` cancels all scheduled reminders and schedules nothing.
3. **Cancellation on Delete:** `cancelTaskReminders(taskId)` cancels both the 5m and deadline notification IDs immediately.

---

## Step 9 — Habit Notification Lifecycle

1. **Individual Daily Reminder:** If `habit.reminderTime` is provided (e.g., `'08:00'`), `scheduleHabitReminder(habit)` schedules a daily repeating notification using `DateTimeComponents.time`.
2. **Edit/Disable Reminder:** If `habit.reminderTime` is cleared, `cancelHabitReminder(habit.id)` is called.
3. **Delete Habit:** `cancelHabitReminder(habit.id)` is called immediately in `HabitsNotifier.deleteHabit()`.
4. **Summary Evening Alert:** Fixed ID `999999` scheduled at 8:00 PM alerting the user to remaining uncompleted habits for the day.

---

## Step 10 — Due Date & Recurring Reminder Logic

- **Parsing:** Time parsed via `parts[0]` (hours) and `parts[1]` (minutes).
- **Rollover Calculation:** If scheduled daily reminder time has already passed today, schedules for tomorrow's instance:
  ```dart
  if (scheduledDate.isBefore(now)) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }
  ```
- **DateTimeComponents:** Configured with `DateTimeComponents.time` so the native platform automatically repeats the alarm at that exact time daily without needing manual reschedule loops.

---

## Step 11 — Process Death & Cold Start Restoration

- Local notifications registered with the OS kernel AlarmManager and UNUserNotificationCenter remain active even when the application is terminated or killed by the OS.
- On cold start, `SyncInitializer` calls `NotificationService().reconcileScheduledNotifications()` with fresh data from user-scoped Hive boxes to ensure any changes synced offline or while backgrounded are reconciled.

---

## Step 12 — Device Restart & Boot Persistence

### Android Configuration:
- `android.permission.RECEIVE_BOOT_COMPLETED` is declared in `android/app/src/main/AndroidManifest.xml`.
- `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver` is registered with intent filters:
  - `android.intent.action.BOOT_COMPLETED`
  - `android.intent.action.MY_PACKAGE_REPLACED`
  - `android.intent.action.QUICKBOOT_POWERON`
- System alarms are restored automatically upon reboot by the plugin receiver.

---

## Step 13 — Notification Reconciliation Engine

Implemented `reconcileScheduledNotifications({List<Task>? tasks, List<Habit>? habits, bool? hasTodayTx})`:
- Iterates all tasks:
  - Completed or past due $\to$ Cancels reminders.
  - Active and future due $\to$ Schedules 5m and deadline reminders.
- Iterates all habits:
  - Has `reminderTime` $\to$ Schedules daily reminder.
  - No `reminderTime` $\to$ Cancels reminder.
- Reconciles money transaction reminders based on whether today has transactions.

---

## Step 14 & 15 — Auth Lifecycle & Multi-User Notification Isolation

### The Cross-User Leakage Vulnerability:
If User A logs out with pending reminders, OS alarms would fire on the device. If User B subsequently logged in, User B could see User A's private task or habit alerts.

### The Fix:
1. `NotificationService().cancelAllUserNotifications()` calls native `cancelAll()`.
2. Invoked during:
   - `AuthService.logout()`
   - `SettingsScreen._handleLogout()`
3. Upon User B's login, `SyncInitializer` re-runs `reconcileScheduledNotifications()` exclusively with User B's scoped tasks and habits.

---

## Step 16 — Settings & Preference Integration

In `SettingsScreen`:
- Master Notifications switch toggles all reminder scheduling.
- Separate toggles for Tasks, Habits, and Capital (Money) updates.
- Real-time permission status query (`areNotificationsEnabled()`) displayed to the user (`Notifications: Enabled` / `Notifications: Disabled`).
- Turning off a category immediately invokes corresponding cancellation APIs (`cancelMoneyReminders()`, `cancelTaskReminders()`, etc.).

---

## Step 17 — Foreground Notification Behavior

Configured in `DarwinInitializationSettings` (iOS) and Android Notification Channels:
- `defaultPresentAlert: true`
- `defaultPresentBadge: true`
- `defaultPresentSound: true`
- `importance: Importance.max` / `priority: Priority.high`
Notifications display head-up banners and alert sounds even when ARC is active in the foreground.

---

## Step 18 & 19 — Tap Handling, Deep Linking & Payload Format

Standardized JSON payload for every scheduled notification:
```json
{
  "type": "task" | "habit" | "money",
  "id": "<entity-id>",
  "timestamp": 1775892600000
}
```
`onNotificationTap` parses the JSON payload and triggers routing via `onNotificationTapCallback`:
- `type: "task"` $\to$ Navigate to Tasks screen (`/tasks`).
- `type: "habit"` $\to$ Navigate to Habits screen (`/habits`).
- `type: "money"` $\to$ Navigate to Capital screen (`/money`).

---

## Step 20 — Permission Handling

Implemented `requestPermissions()`:
- **Android 13+ (API 33+):** Requests `POST_NOTIFICATIONS` via `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission()`.
- **Android 12+ (API 31+):** Requests exact alarm permission via `requestExactAlarmsPermission()`.
- **iOS:** Requests alert, badge, and sound permissions via `requestPermissions()`.
- Helper `areNotificationsEnabled()` safely reports current system permission state.

---

## Step 21 — Android Configuration & Manifest Audit

Permissions in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
```
All required permissions for exact alarms and boot restoration are correctly configured.

---

## Step 22 — iOS Configuration Audit

In `NotificationService`:
```dart
const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
  requestAlertPermission: true,
  requestBadgePermission: true,
  requestSoundPermission: true,
  defaultPresentAlert: true,
  defaultPresentBadge: true,
  defaultPresentSound: true,
);
```
Supports background and foreground display with complete APNs user permission handling.

---

## Step 23 & 24 — Defensive Logging & Diagnostics

All scheduling, cancellation, and reconciliation calls log structured messages prefixed with `NotificationService:`:
- Scheduled ID, timestamp, and ISO mode.
- Canceled ID and target entity ID.
- Reconciliation progress and summary.
- Web runtime detection notes.

---

## Step 25 — Unit & Integration Test Suite

A dedicated test suite was built in `test/notification_reliability_audit_repair_test.dart` containing 15 test cases verifying:
1. Fixed system notification IDs strictly $< 1,000,000$.
2. Task and Habit IDs strictly disjoint and mathematically separated across all inputs.
3. Timezone resolution sets valid Olson location without throwing.
4. Active future task schedules 5m pre-alert and deadline alert.
5. Completed task cancels reminders and does not schedule new ones.
6. Deleting task explicitly cancels all task reminders.
7. Editing task cancels previous reminders to prevent duplicates.
8. Habit with `reminderTime` schedules daily recurring reminder with `DateTimeComponents.time`.
9. Habit without `reminderTime` cancels scheduled habit reminder.
10. Deleting habit explicitly cancels reminder.
11. Full reconciliation cancels completed/past items and schedules active items.
12. Logout cancels all notifications (`cancelAllUserNotifications()`).
13. Multi-user switch clears User A's notifications and reconciles only User B's notifications.
14. Permission request and enabled check methods complete safely.

---

## Step 26 — Verification Checklist

| Verification Item | Status | Result |
| :--- | :---: | :--- |
| `flutter analyze` | PASS | **No issues found! (0 warnings, 0 errors)** |
| `flutter test test/notification_reliability_audit_repair_test.dart` | PASS | **15/15 tests passed** |
| Full Test Suite (`flutter test`) | PASS | **210/210 tests passed (100%)** |
| Web Release Compilation (`flutter build web`) | PASS | **Succeeded (`√ Built build\web`)** |
| User Isolation on Logout | PASS | **Verified via unit tests and auth hooks** |
| Exact Alarms & Timezone Integrity | PASS | **Verified with dynamic Olson lookup** |

---

## Step 27 — Final Notification Audit Conclusion

The ARC notification subsystem has been successfully diagnosed, repaired, and hardened. Local notifications now function reliably across process restarts, device reboots, and multi-user sessions, while strictly preserving ARC's offline-first architecture, Hive storage isolation, and existing visual identity.
