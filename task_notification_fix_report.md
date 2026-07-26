# Task Notification Fix Report

**Date:** July 26, 2026  
**Project:** Project Arc  
**Status:** Completed & Verified  

---

## 1. Root Cause Analysis

Before this fix, task notifications were unreliable due to several underlying issues:
1. **Uninitialized Timezone Location**: `tz.initializeTimeZones()` was called, but `tz.local` was not configured with the device's local timezone location (`DateTime.now().timeZoneName`), causing UTC offset shifts for scheduled notifications.
2. **Missing Notification Channel Registration**: Notification channels (`arc_tasks_channel`, `arc_habits_reminder_channel`, `arc_money_reminder_channel`) were referenced in `AndroidNotificationDetails`, but were never explicitly created using `createNotificationChannel` with high importance (`Importance.max`) and sound/vibration enabled.
3. **Incomplete Stage Scheduling**: Tasks were previously scheduled with 1-hour and 30-minute intervals rather than the required 5-minute pre-alert and exact deadline alert.
4. **Android 12+/13+ Permissions**: Android 13+ runtime POST_NOTIFICATIONS and Android 12+ Exact Alarms permissions were not explicitly handled during plugin setup.
5. **App Restart Persistence**: Scheduled task notifications were not restored across app reboots/restarts.

---

## 2. Files Modified

1. **`lib/core/notifications/notification_service.dart`**
   - Configured device timezone location initialization (`tz.setLocalLocation`).
   - Created Android High Importance Notification Channels (`arc_tasks_channel`, `arc_habits_reminder_channel`, `arc_money_reminder_channel`).
   - Implemented 2-stage task notification scheduling (Notification 1: 5 minutes before deadline; Notification 2: Exact deadline).
   - Formatted priority badges (`🔴 High Priority`, `🟠 Must Priority`, `🟡 Low Priority`).
   - Added permission request handlers and `showPermissionDeniedDialog` for user settings guidance.
   - Added structured debug logging for all scheduling and cancellation events.

2. **`lib/providers/global_providers.dart`**
   - Updated `TasksNotifier` to automatically reschedule active incomplete task reminders on startup (`_rescheduleActiveTaskReminders`).

---

## 3. Notification Architecture & Two-Stage Scheduling Flow

Every task with a due date and due time automatically schedules **two distinct notifications**:

```
Task Created / Updated
          │
          ├──> Hash Task UUID ──> Base ID = getStableHash(task.id)
          │
          ├──> Notification 1 (5 Minutes Before)
          │    ├── ID: (Base ID * 2) + 0
          │    ├── Title: ⏰ Task Reminder
          │    └── Body:
          │          Only 5 minutes left!
          │          Complete your task before the deadline.
          │          
          │          Task: {Task Name}
          │          Priority: {🔴 High | 🟠 Must | 🟡 Low} Priority
          │          Due: {Time}
          │
          └──> Notification 2 (Deadline Reached)
               ├── ID: (Base ID * 2) + 1
               ├── Title: 🚨 Task Deadline Reached
               └── Body:
                     The deadline for this task has been reached.
                     Please complete it as soon as possible.
                     
                     Task: {Task Name}
                     Priority: {🔴 High | 🟠 Must | 🟡 Low} Priority
                     Deadline: {Time}
```

---

## 4. Priority Visualization

Every notification clearly displays the task's priority badge inside the notification body:
- **High Priority**: `🔴 High Priority`
- **Must Priority**: `🟠 Must Priority`
- **Low Priority**: `🟡 Low Priority`

---

## 5. Cancellation & Smart Logic

- **Task Completed**: Calling `toggleTask` or marking a task complete immediately invokes `cancelTaskReminders(taskId)`, canceling both Notification 1 and Notification 2.
- **Task Edited**: Updating a task deadline cancels existing reminders for `taskId` and schedules new reminders for the new time.
- **Task Deleted**: Deleting a task invokes `cancelTaskReminders(taskId)`, removing all scheduled notifications.
- **No Duplicates**: Previous notification IDs are explicitly canceled prior to scheduling new ones.

---

## 6. Timezone Handling & Android Persistence

- **Timezone**: Initializes `tz.initializeTimeZones()` and sets local location via `tz.setLocalLocation(tz.getLocation(timeZoneName))`. All schedules use `tz.TZDateTime.from(targetTime, tz.local)`.
- **Boot Persistence**: Android manifest includes `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `POST_NOTIFICATIONS`, `ScheduledNotificationReceiver`, and `ScheduledNotificationBootReceiver`.
- **App Restart**: `TasksNotifier._rescheduleActiveTaskReminders()` restores all active task notifications when the app launches.

---

## 7. Permission Handling

- `requestPermissions()` requests both `POST_NOTIFICATIONS` (Android 13+) and `SCHEDULE_EXACT_ALARM` (Android 12+).
- `showPermissionDeniedDialog(context)` presents a friendly explanation and button to prompt permissions if disabled.

---

## 8. Debug Logging

Structured logs are printed to console for diagnostic traceability:
- `NotificationService: Scheduled 5m reminder (ID: {id}, TaskID: {taskId}, Title: "{title}") for {time}`
- `NotificationService: Scheduled Deadline reminder (ID: {id}, TaskID: {taskId}, Title: "{title}") for {time}`
- `NotificationService: Canceled reminders for Task ID: {taskId}`

---

## 9. Testing Results

- **`flutter analyze`**:
  `No issues found! (ran in 6.3s)`
- **`flutter test`**:
  `00:02 +7: All tests passed!`
- **Scenarios Verified**:
  - Task due in 10 minutes (schedules 5m alert & 0m deadline alert).
  - Task due in 5 minutes (schedules 0m deadline alert).
  - Task deadline edit (cancels previous, schedules new).
  - Task deletion (cancels both).
  - Task completion (cancels both).
  - App restart & background execution (restores active task reminders).

---

## 10. Remaining Known Limitations

- On OEM Android ROMs with aggressive battery optimization (e.g. Xiaomi MIUI / Samsung One UI "Deep Sleeping Apps"), the user may need to grant "Unrestricted Battery" usage for exact alarm delivery when the device is locked for prolonged periods.
