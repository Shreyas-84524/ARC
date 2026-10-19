# ARC-Kotlin Phase 5 — Notification Engine Architecture & Privacy Safeguards

## 1. Overview and Design Philosophy

The Native Notification Engine delivers timely, privacy-respecting deadline reminders, habit completion prompts, and financial expense tracking alerts across Android API 23 to 35+.

### Key Architectural Pillars
1. **Google Play Policy Compliance (No Exact Alarms)**:
   - Does NOT request or declare `USE_EXACT_ALARM` or `SCHEDULE_EXACT_ALARM`.
   - Utilizes `AlarmManager.setAndAllowWhileIdle(RTC_WAKEUP, ...)` with automatic inexact fallback to guarantee battery efficiency and zero permission friction.
2. **Strict Vault Isolation (Zero-Cloud Vault Invariant)**:
   - Secret Notes and Encrypted Vault items are strictly forbidden from notification scheduling.
   - `IArcNotificationManager` and `ArcNotificationManager` expose zero methods accepting note models or vault credentials.
   - `ArcReminderReceiver` actively intercepts and drops any broadcast intent targeting `destination == "vault"` or `destination == "secret_notes"`.
3. **Android 13+ (API 33+) Runtime Permission Guarding**:
   - Declares `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />`.
   - Validates notification permissions via `NotificationManagerCompat.areNotificationsEnabled()` before attempting notification dispatch.

---

## 2. Notification Channels

Native Android channels configured with user-accessible controls:

| Channel ID | Name | Importance | Description |
|---|---|---|---|
| `arc_tasks_channel` | Task Reminders | `DEFAULT` | Due date and upcoming 5-minute pre-deadline alerts |
| `arc_habits_channel` | Habit Reminders | `DEFAULT` | Scheduled habit times and evening check-in reminders |
| `arc_money_channel` | Money & Budget Alerts | `DEFAULT` | Daily prompts to record daily transactions |
| `arc_reminders_channel` | Project Arc Reminders | `DEFAULT` | Legacy channel for backward compatibility with Flutter |
| `arc_money_reminder_channel` | Money Reminders | `DEFAULT` | Legacy money channel for backward compatibility |

---

## 3. Disjoint Notification ID Namespaces

To prevent notification ID collisions across modules and entities, a deterministic 31-bit DJB2 positive integer hash is combined with partitioned ID spaces:

| Namespace | Minimum ID | Range | Maximum ID | Description |
|---|---|---|---|---|
| Task Pre-Deadline (5m) | 10,000,000 | 390,000,000 | 399,999,999 | 5 minutes before task due time |
| Task Deadline | 400,000,000 | 400,000,000 | 799,999,999 | At task deadline |
| Habit Deadline | 800,000,000 | 300,000,000 | 1,099,999,999 | At habit-specific reminder time |
| Habit Pending (`rem_time`) | 1,100,000,000 | 300,000,000 | 1,399,999,999 | At global `rem_time` if incomplete |
| Money Daily Reminder | 888,888 | Fixed | 888,888 | At configured `expenseReminderTime` |
| Evening Habit Check-in | 999,999 | Fixed | 999,999 | At configured `eveningCheckinTime` |

---

## 4. Multi-Entity Reconciliation Lifecycle

The `reconcile` method coordinates notification states whenever:
1. The app boots or cold starts.
2. The user switches account profiles (`ownerUid`).
3. Settings preferences are modified (master toggle, task reminders, habit reminders, expense reminders).
4. Tasks or Habits are added, completed, deleted, or rescheduled.
