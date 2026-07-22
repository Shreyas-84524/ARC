# Project Arc — Notification Infrastructure Specification

> **Version:** 1.0.0 (Production Release)  
> **Document Purpose:** Detailed specification of local notification flows, scheduling algorithms, Android channels, exact alarm permissions, and cancellation triggers.

---

## 1. Notification Channels

### Android Notification Channels
1. `arc_task_reminder_channel`:
   - **Name**: Task Reminders
   - **Description**: Precise alerts for scheduled task due times
   - **Importance**: High (`Importance.max`)
   - **Priority**: High (`Priority.high`)
2. `arc_habit_reminder_channel`:
   - **Name**: Habit Reminders
   - **Description**: Evening alerts to complete daily habit routines
   - **Importance**: Default (`Importance.default`)
3. `arc_money_reminder_channel`:
   - **Name**: Money Reminders
   - **Description**: Daily alerts to log expense transaction entries
   - **Importance**: High (`Importance.max`)

---

## 2. Scheduling & Cancellation Rules

### 1. Task Reminders (`scheduleTaskReminders`)
- Triggered whenever a task is created or updated with a valid `reminder` timestamp.
- **3-Tier Scheduling**:
  - `taskId.hashCode + 1`: 1 hour before due time.
  - `taskId.hashCode + 2`: 30 minutes before due time.
  - `taskId.hashCode + 3`: At exact due time.
- **Cancellation**: Calling `cancelTaskReminders(taskId)` cancels all 3 notification IDs.

### 2. Habit Evening Check-in (`scheduleEveningReminder`)
- Scheduled at **8:00 PM daily** if at least one daily habit is incomplete.
- Fixed Notification ID: `999999`.

### 3. Money Tracker Reminders (`scheduleDailyMoneyReminders`)
- **8:00 PM Daily Check-in Alert** (Notification ID `888888`): Reminds user to log today's transactions.
- **10:00 PM Final Reminder** (Notification ID `101010`): Follow-up alert.
- **Auto-Cancellation**: When user logs a transaction with today's date, `scheduleDailyMoneyReminders(hasTodayTx: true)` cancels notification ID `101010` automatically.
