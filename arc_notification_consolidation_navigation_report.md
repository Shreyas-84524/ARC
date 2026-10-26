# Project Arc — Local Notification Consolidation & Navigation Fix Report

**Date:** October 26, 2026  
**Environment:** Flutter 3.x / Dart 3.x, Riverpod 2.x, Hive Local Storage, Cloud Firestore, Cloudflare Workers Free, Brevo Free  
**Operating System:** Windows / Android  
**Test Suite:** `test/notification_consolidation_and_navigation_test.dart` (18 passing tests)  
**Status:** Complete & Production-Ready  

---

## 1. Executive Summary

In Project Arc, users previously reported receiving multiple simultaneous notifications at their configured daily reminder time. Specifically, users with $N$ pending habits received $N + 1$ overlapping notifications simultaneously: $N$ individual "Habit still pending" notifications plus an additional "Habit check-in" notification. Furthermore, tapping notification deep-links occasionally failed during cold start or resulted in unexpected app termination when tapping Android system back from the destination tab screen.

This phase resolved all issues through four foundational pillars:
1. **Consolidation of Habit Notifications:** Collapsed the per-habit `habitPending` reminder loop into exactly **ONE** consolidated daily Habit Check-in notification (`NotificationPolicy.dailyHabitCheckInId = 999999`) scheduled at `snapshot.settings.remTime` with title `"Habit check-in"` and body `"Don't forget to review today's habits."`. Individual habit deadline reminders (`habit.reminderTime`) remain preserved.
2. **Disjoint Notification ID Spaces & One-Time Migration:** Partitioned the 31-bit integer ID space into isolated ranges across Money (`888888`), Consolidated Habit Check-in (`999999`), Tasks (`10,000,000..799,999,999`), Individual Habit Times (`800,000,000..1,099,999,999`), Obsolete Legacy Loop (`1,100,000,000..1,399,999,999`), and Feedback Acknowledgements (`1,400,000,000..1,999,999,999`). A non-destructive migration cancels legacy obsolete schedules from Android's pending list on startup without touching other modules.
3. **Deep-Link Intent Preservation & Payload Whitelist:** Enforced a secure payload schema with an allowed destination whitelist (`/tasks`, `/habits`, `/money`, `/feedback/my-feedback`). Cold-start and logged-out notification taps preserve pending navigation intents until authentication resolves. Account switches immediately purge pending navigation intents and reset navigation to `/` to prevent cross-account data leakage.
4. **Back Navigation Resilience in `ShellScreen`:** Wrapped the root navigation scaffold in a `PopScope`. If the user is on any tab screen (`/habits`, `/money`, `/tasks`) opened via a notification or direct link, pressing system Back navigates gracefully back to the Dashboard (`/`). Only when already on the Dashboard does system Back exit the application.

---

## 2. Root Cause Analysis

### 2.1 Overlapping Habit Notifications
In `lib/core/notifications/notification_policy.dart`, the habit reconciliation algorithm in `_habitNotifications()` executed two simultaneous generation passes at the user's daily reminder time (`snapshot.settings.remTime`):
1. A loop over every incomplete habit in `snapshot.habits`:
   ```dart
   // LEGACY BUGGY LOOP:
   for (final habit in incompleteHabits) {
     specs.add(ArcNotificationSpec(
       id: _habitRemTimeId(habit.id),
       channel: ArcNotificationChannel.habits,
       type: ArcNotificationType.habitPending,
       title: 'Habit still pending',
       body: "Don't forget to complete ${habit.name} today.",
       scheduledAt: remTarget,
       ...
     ));
   }
   ```
2. A separate general check-in block:
   ```dart
   if (snapshot.habits.isNotEmpty && !allCompleted) {
     specs.add(ArcNotificationSpec(
       id: eveningHabitReminderId, // 999999
       channel: ArcNotificationChannel.habits,
       type: ArcNotificationType.habitEveningCheckIn,
       title: 'Habit check-in',
       body: "Don't forget to review today's habits.",
       scheduledAt: eveningTarget, // Defaulted to remTime
       ...
     ));
   }
   ```
Because `eveningTarget` defaulted to `snapshot.settings.remTime`, a user with 5 habits received 6 notifications at 8:00 PM: 5 per-habit reminders and 1 habit check-in alert.

### 2.2 Deep-Link Premature Drops & Account Leaks
In `lib/core/notifications/notification_orchestrator.dart`, the previous listener on `userContextProvider` checked:
```dart
if (previous?.userId != next.userId) {
  ref.read(notificationControllerProvider.notifier).clearNavigationIntent();
}
```
During cold starts and login flows:
- `previous?.userId` is `null` (app is initializing or user is unauthenticated).
- `next.userId` becomes `'user_alice'` once authentication succeeds.
- Because `null != 'user_alice'`, the pending navigation intent was prematurely cleared right when the user authenticated!

### 2.3 ShellScreen Back Navigation App Exit
In `lib/features/dashboard/screens/shell_screen.dart`, tabs were hosted in a `Scaffold` without a `PopScope`. In GoRouter, navigating directly to `/habits`, `/money`, or `/tasks` replaces or sets the route location. Because there was no route below it in the root Navigator stack (`Navigator.canPop(context)` was `false`), pressing the Android system back button caused the Android Activity to finish, abruptly exiting the application.

---

## 3. Architecture & Module Design

### 3.1 Single Source of Scheduling Truth
Project Arc maintains a strict architectural invariant: **Feature screens and business repositories NEVER schedule local notifications directly.**
- Feature layers persist changes to Hive and sync with Cloud Firestore.
- Riverpod state providers reflect domain models (`tasksProvider`, `habitsProvider`, `moneyProvider`, `appSettingsProvider`).
- `NotificationOrchestrator` aggregates state into a clean `NotificationSnapshot` and queues reconciliation.
- `NotificationPolicy` builds a pure list of desired `ArcNotificationSpec` objects.
- `NotificationController` compares desired specs against `_gateway.pendingNotifications()`, executing minimal surgical `schedule()` and `cancel()` calls.

```mermaid
flowchart TD
    subgraph UI & Providers
        A[Tasks / Habits / Money Providers] --> B[NotificationOrchestrator]
        S[AppSettings / UserContext] --> B
    end

    subgraph Central Engine
        B -->|Snapshot| C[NotificationPolicy.build]
        C -->|Desired Specs| D[NotificationController]
        D -->|Query Pending| E[LocalNotificationGateway]
        D -->|Schedule / Cancel| E
    end

    subgraph OS Layer
        E --> F[flutter_local_notifications]
        F --> G[Android Notification Manager]
    end
```

---

## 4. Notification ID Space Allocation

To guarantee zero ID collisions across features and migrations, integer IDs (0 to $2^{31}-1$) are partitioned into disjoint, non-overlapping spaces:

| Subsystem | Range / Fixed ID | Constant Name | Description |
| :--- | :--- | :--- | :--- |
| **Money Manager** | `888888` | `moneyReminderId` | Single consolidated daily expense reminder. |
| **Habit Check-in** | `999999` | `dailyHabitCheckInId` | Single consolidated daily habit check-in. |
| **Task Pre-Deadline** | `10,000,000 .. 399,999,999` | `taskReminderMin` | 5-minute pre-deadline alert. Hash-based from task ID. |
| **Task Deadline** | `400,000,000 .. 799,999,999` | `taskDeadlineMin` | Exact deadline alert. Hash-based from task ID. |
| **Individual Habit Reminders** | `800,000,000 .. 1,099,999,999` | `habitReminderMin` | Preserved user-configured habit reminder times (`habit.reminderTime`). |
| **Legacy Obsolete Habit Reminders** | `1,100,000,000 .. 1,399,999,999` | `habitRemTimeMin` | Obsolete per-habit reminder loop. Target for migration cancellation. |
| **Feedback Acknowledgements** | `1,400,000,000 .. 1,999,999,999` | `feedbackNotificationMin` | Thank-you notifications for administrator-acknowledged feedback. |

---

## 5. Habit Reminder Consolidation & Scheduling Logic

### 5.1 Elimination of Per-Habit Loops
The `habitPending` loop in `NotificationPolicy._habitNotifications()` has been completely removed.

### 5.2 Consolidated Daily Habit Reminder
`NotificationPolicy` now issues exactly **ONE** daily reminder spec for habits:
- **Condition:** Scheduled if `snapshot.settings.masterNotificationsEnabled == true`, `snapshot.settings.habitRemindersEnabled == true`, and `snapshot.habits.isNotEmpty`.
- **Target Time:** Configured in `snapshot.settings.remTime` (HH:mm format, defaulting to `20:00`).
- **Advancement on Completion:** If all habits for the day are already completed (`allCompleted == true`), the notification is automatically advanced to tomorrow at the configured reminder time. If habits remain incomplete and the reminder time has already passed today, it also advances to tomorrow.
- **Copy:**
  - **Title:** `"Habit check-in"`
  - **Body:** `"Don't forget to review today's habits."`
- **Identifier:** Fixed ID `999999` (`NotificationPolicy.dailyHabitCheckInId`).
- **Payload:** `ArcNotificationPayload(type: ArcNotificationType.habitEveningCheckIn, entityId: 'daily_habit_checkin', fingerprint: 'habits_daily')`.

### 5.3 Preservation of Other Modules
- **Money Manager:** Exactly one daily prompt at configured time (`ID: 888888`), Title: `"Update today's spending"`, Body: `"Don't forget to add today's expenses to Arc."`. Advances to tomorrow if an expense was recorded today.
- **Task Manager:** Independent alerts for active tasks with due dates/times (pre-deadline and deadline). Completed tasks or tasks without deadlines generate no specs.
- **Feedback Acknowledgements:** Deduplicated local notifications triggered when an administrator acknowledges user feedback, mapped to ID space `1,400,000,000..1,999,999,999`.

---

## 6. Migration of Obsolete Schedules

To ensure existing users updating the application do not have orphan per-habit notifications lingering in the Android `AlarmManager` or `NotificationManager`, `NotificationController.initialize()` executes `migrateObsoleteSchedules()`:

```dart
Future<int> migrateObsoleteSchedules({dynamic boxOverride}) async {
  // Check persisted migration flag in settings_box
  if (box != null && box.get('migrated_consolidated_habit_notifications_v1', defaultValue: false) == true) {
    return 0;
  }

  final pending = await _gateway.pendingNotifications();
  var migratedCount = 0;

  for (final request in pending) {
    final payload = ArcNotificationPayload.tryParse(request.payload);
    final isHabitPending = payload?.type == ArcNotificationType.habitPending;
    final isInHabitRemRange = request.id >= NotificationPolicy.habitRemTimeMin &&
        request.id < (NotificationPolicy.habitRemTimeMin + NotificationPolicy.habitRemTimeRange);

    if (isHabitPending || isInHabitRemRange) {
      await _gateway.cancel(request.id);
      migratedCount++;
    }
  }

  if (box != null) {
    await box.put('migrated_consolidated_habit_notifications_v1', true);
  }
  return migratedCount;
}
```

**Non-Destructive Guarantee:** Unlike `cancelAll()`, this method inspects each pending notification's ID and payload, cancelling *only* obsolete schedules in the `1,100,000,000..1,399,999,999` range. Active task deadlines and money reminders remain untouched.

---

## 7. Deep-Link Navigation & Destination Security

### 7.1 Payload Whitelist & Validation
`ArcNotificationPayload` includes validation against an explicit destination whitelist:
```dart
static const Set<String> allowedBaseDestinations = {
  '/tasks',
  '/habits',
  '/money',
  '/feedback/my-feedback',
};
```
Any payload with an unrecognized or malformed route is rejected and safely cleared without executing navigation.

### 7.2 Category to Route Mapping

| Notification Type | Category | Destination Route | Behavior on Tap |
| :--- | :--- | :--- | :--- |
| `habitEveningCheckIn` | `habits` | `/habits` | Opens Habit Tracker screen. |
| `habitReminder` | `habits` | `/habits` | Opens Habit Tracker screen. |
| `moneyDaily` | `money` | `/money` | Opens Money Manager screen. |
| `taskReminder` | `tasks` | `/tasks?taskId=$entityId` | Opens Tasks screen; automatically opens task editor for `$entityId`. |
| `taskDeadline` | `tasks` | `/tasks?taskId=$entityId` | Opens Tasks screen; automatically opens task editor for `$entityId`. |
| `feedbackAcknowledged` | `feedback` | `/feedback/my-feedback` | Opens My Feedback history screen. |

---

## 8. Cold-Start, Lifecycle & Account-Switching Resilience

In `NotificationOrchestrator`, navigation handling is completely synchronized with application lifecycle and authentication state:

```dart
ref.listen(userContextProvider, (previous, next) {
  final wasSwitch = previous?.userId != null &&
      next.userId != null &&
      previous!.userId != next.userId;
  final wasLogout =
      (previous?.isAuthenticated == true) && !next.isAuthenticated;

  if (wasSwitch || wasLogout) {
    if (!next.isAuthenticated) {
      ref.read(notificationControllerProvider.notifier).handleLogout();
    }
    // Purge pending intent and return to Dashboard on account switch/logout
    ref.read(notificationControllerProvider.notifier).clearNavigationIntent();
    ref.read(routerProvider).go('/');
    _queueReconciliation('user_changed');
  } else if (previous?.userId != next.userId) {
    // Cold start auth resolution or login from unauthenticated state:
    // Preserve pending navigation intent and reconcile schedules for new user
    _queueReconciliation('user_changed');
  }
  _tryHandleNavigation(next, ref.read(notificationControllerProvider));
});
```

### 8.1 Cold Start Launch
1. User taps notification while Arc is terminated.
2. `_plugin.getNotificationAppLaunchDetails()` retrieves the launch response and feeds `_tapController`.
3. `NotificationController` sets `state.navigationIntent`.
4. While `UserContext.isInitializing == true`, `_tryHandleNavigation` defers navigation.
5. As soon as `UserContext` resolves with `isAuthenticated == true`, `_tryHandleNavigation` executes navigation to the destination.

### 8.2 Logged-Out User
1. User taps notification while logged out.
2. Intent is retained in `NotificationController`.
3. User completes login.
4. On transition from unauthenticated to authenticated, the intent is executed and then cleared.

### 8.3 Account Switch Protection
1. User Alice taps or receives a notification.
2. Active user switches to Bob (`previous.userId != next.userId` where both are non-null).
3. `NotificationOrchestrator` immediately clears `navigationIntent` and redirects GoRouter to `/`.
4. Alice's private feedback or tasks are never shown to Bob.

---

## 9. Back Navigation Resilience in ShellScreen

To prevent the Android activity from exiting when system Back is pressed on a tab opened via notification, `ShellScreen` wraps its layout in a `PopScope`:

```dart
final String currentPath = location ?? GoRouterState.of(context).uri.path;
final int currentIndex = _indexFromLocation(currentPath);

return PopScope(
  canPop: currentIndex == 0,
  onPopInvokedWithResult: (didPop, result) {
    if (didPop) return;
    if (currentIndex != 0) {
      context.go('/');
    }
  },
  child: Scaffold(
    body: child,
    bottomNavigationBar: Container(...),
  ),
);
```

### Navigation State Machine

```mermaid
stateDiagram-v2
    [*] --> Dashboard: Launch or Navigate
    Dashboard --> Habits: Notification Tap (/habits)
    Dashboard --> Money: Notification Tap (/money)
    Dashboard --> Tasks: Notification Tap (/tasks)

    Habits --> Dashboard: System Back (PopScope: canPop=false, go('/'))
    Money --> Dashboard: System Back (PopScope: canPop=false, go('/'))
    Tasks --> Dashboard: System Back (PopScope: canPop=false, go('/'))

    Dashboard --> [*]: System Back (PopScope: canPop=true -> App Exit)
```

- **From Habits (`/habits`):** `currentIndex == 2` $\rightarrow$ `canPop: false`. System Back intercepts pop and calls `context.go('/')`. App stays open, user arrives at Dashboard.
- **From Money (`/money`):** `currentIndex == 3` $\rightarrow$ `canPop: false`. System Back intercepts pop and calls `context.go('/')`.
- **From Tasks (`/tasks`):** `currentIndex == 1` $\rightarrow$ `canPop: false`. System Back intercepts pop and calls `context.go('/')`.
- **From Dashboard (`/`):** `currentIndex == 0` $\rightarrow$ `canPop: true`. System Back closes the application normally.

---

## 10. Verification & Test Suite Results

A comprehensive automated test suite (`test/notification_consolidation_and_navigation_test.dart`) was created covering all 18 requirements specified in the project mandate.

```
flutter test test/notification_consolidation_and_navigation_test.dart
00:01 +18: All tests passed!
```

### Requirement Verification Matrix

| # | Requirement Verified | Status | Test Name |
| :---: | :--- | :---: | :--- |
| **1** | Only ONE consolidated Habit reminder is scheduled when habits are pending | **PASSED** | `Requirement 1: Three pending habits produce exactly ONE consolidated Habit check-in notification` |
| **2** | Habit reminder scheduling is idempotent across multiple reconciliations | **PASSED** | `Requirement 2: Habit reminder scheduling is idempotent across repeated reconciliations` |
| **3** | App restarts do not duplicate notifications | **PASSED** | `Requirement 3: Restarting Arc does not duplicate notifications` |
| **4** | Changing the daily reminder time replaces the previous schedule with new time | **PASSED** | `Requirement 4: Changing the reminder time replaces previous schedule with new time` |
| **5** | Disabling habit reminders cancels the habit notification and preserves others | **PASSED** | `Requirement 5: Disabling habit reminders cancels the habit notification while preserving others` |
| **6** | Obsolete per-habit reminders are cancelled during migration | **PASSED** | `Requirement 6: Obsolete per-habit reminders are cancelled while unrelated notifications are preserved` |
| **7** | Money Manager reminder schedules daily and advances if transaction recorded today | **PASSED** | `Requirement 7: Money reminder schedules daily and advances if transaction recorded today` |
| **8** | Multiple legitimate tasks receive independent non-colliding deadline alerts | **PASSED** | `Requirement 8: Multiple legitimate tasks receive independent non-colliding deadline alerts` |
| **9** | Duplicate alerts for the same task and deadline are prevented | **PASSED** | `Requirement 9: Duplicate alerts for the same task and deadline are prevented` |
| **10** | Tapping Habit notification navigates directly to Habit Tracker (`/habits`) | **PASSED** | `Requirement 10: Tapping habit notification navigates directly to Habit Tracker (/habits)` |
| **11** | Tapping Money notification navigates directly to Money Manager (`/money`) | **PASSED** | `Requirement 11: Tapping money notification navigates directly to Money Manager (/money)` |
| **12** | Tapping Task notification navigates to Tasks screen (`/tasks?taskId=...`) | **PASSED** | `Requirement 12: Tapping task notification navigates to Tasks screen (/tasks)` |
| **13** | Tapping Feedback notification navigates to My Feedback (`/feedback/my-feedback`) | **PASSED** | `Requirement 13: Tapping feedback notification navigates to My Feedback (/feedback/my-feedback)` |
| **14** | Notification navigation functions correctly in foreground and app resume | **PASSED** | `Requirement 14: Notification navigation functions correctly in foreground and app resume` |
| **15** | Cold-start launch defers navigation until auth session resolves, then navigates | **PASSED** | `Requirement 15: Cold-start launch defers navigation until auth session resolves, then navigates` |
| **16** | Logged-out users preserve pending intent and navigate after login | **PASSED** | `Requirement 16: Logged-out user preserves pending intent and navigates after login` |
| **17** | Switching accounts clears pending navigation intent to prevent data exposure | **PASSED** | `Requirement 17: Switching accounts clears pending navigation intent to prevent cross-account exposure` |
| **18** | System back on tab screen opened via notification falls back to Dashboard | **PASSED** | `Requirement 18: System back on tab screen opened via notification falls back to Dashboard rather than exiting` |

### Regression Test Suite Results
- `test/central_notification_test.dart`: **4/4 PASSED**
- `test/feedback_history_and_navigation_test.dart`: **15/15 PASSED**
- `test/feedback_acknowledgement_service_test.dart`: **7/7 PASSED**
- `dart analyze lib/ test/notification_consolidation_and_navigation_test.dart`: **0 errors, 0 warnings**

---

## 11. Physical-Device Verification Statement

### Statement of Automated Verification & Hardware Readiness
> **Verification Status:** Automated test verification covering all 18 requirements has been executed and confirmed passing. The implementation is verified across simulated lifecycle states (cold-start initialization, app resume, foreground tap events, auth gating, account switching, and Android system pop route events). The application code, notification channels, Android manifest permissions, and routing infrastructure are fully prepared and ready for real physical Android hardware testing.

### Recommended Physical Device Verification Steps
1. Install debug APK on an Android 13+ device (`flutter run -d <device_id>`).
2. Accept the notification permission prompt (`POST_NOTIFICATIONS`).
3. Set the daily reminder time in **Settings $\rightarrow$ Preferences** to 2 minutes in the future.
4. Verify in the Android system notification shade that exactly **ONE** notification arrives (`"Habit check-in"`).
5. Tap the notification and verify Arc opens and displays the Habit Tracker screen (`/habits`).
6. Press the hardware/gesture Back button and confirm Arc returns smoothly to Dashboard (`/`), rather than closing.
7. Press the Back button once more from Dashboard to verify Arc minimizes/exits normally.

---

## 12. Remaining Limitations & Edge Cases

1. **Android OEM Battery Optimizations:** Certain aggressive manufacturer battery killers (e.g. Xiaomi MIUI, Huawei EMUI, Samsung "Deep Sleeping Apps") may delay inexact alarms. `NotificationService` uses `zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle` when permitted to minimize OEM throttling.
2. **Device Reboot Rescheduling:** On Android, scheduled alarms are cleared when a device powers off. Project Arc registers `RECEIVE_BOOT_COMPLETED` in `AndroidManifest.xml` and reconciles all active schedules when the app is launched post-boot.
3. **Focus / Pomodoro Notifications:** Arc does not currently implement a Pomodoro or Focus module. The notification engine has reserved ID ranges and channels should this feature be introduced in future phases.

---

## 13. Human Intervention Requirements

No manual human intervention is required for backend services, database migrations, or infrastructure:
- **No Cloud Functions required:** Handled entirely via local scheduling and client reconciliation.
- **No FCM / Paid Services required:** Operates exclusively under the free tier of `flutter_local_notifications` and Android `AlarmManager`.
- **Database & Hive Backward Compatibility:** Existing user Hive boxes and Firestore rules remain intact. Migration of obsolete notifications runs automatically in the background on the first app launch.
