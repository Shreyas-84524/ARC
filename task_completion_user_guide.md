# Task Completion Workflow — User Guide & Reference (Project Arc)

Welcome to the **Task Completion Workflow User Guide** for **Project Arc**. This guide provides step-by-step instructions on how to manage, complete, and track tasks in Project Arc, along with technical details regarding background synchronization and daily automated cleanup.

---

## 1. How to Create a Task

1. Open **Project Arc** and tap the **Task Manager** tab in the bottom navigation bar (or tap the **+** Floating Action Button on the Dashboard).
2. Tap the **+** button in the bottom right corner to open the **Create Task** sheet.
3. Enter the task **Title** (required) and optional **Description**.
4. Select a **Category** (e.g. *Work*, *Personal*, *Study*, *Finance*, *Health*, *Other*).
5. Set an optional **Due Date** and **Due Time**.
6. Tap **Save Task** to create the task.

---

## 2. How to Assign Priority

When creating or editing a task, choose one of the three priority levels:

- 🔴 **High Priority**: Red indicator. Reserved for urgent, high-impact tasks.
- 🟠 **Much Priority**: Orange indicator. Used for important tasks with upcoming deadlines.
- 🟡 **Low Priority**: Yellow indicator. Default level for routine or low-urgency tasks.

The priority color border is always visible on the task card before reading the task title.

---

## 3. How to Assign Reminders

Reminders are generated automatically whenever a task has a **Due Date** and **Due Time**:

- **1 Hour Before**: A local notification alerts you 60 minutes before the due time.
- **30 Minutes Before**: A second reminder alerts you 30 minutes before due time.
- **At Due Time**: A final reminder triggers at the exact due time.

> **Note**: Reminders operate offline via `flutter_local_notifications` and do not require active internet access.

---

## 4. How to Mark a Task as Completed

You can complete a task in two convenient ways:

1. **Tap the Circular Checkbox**: Tap the circular priority dot on the left side of any task card in the Task Manager or Dashboard.
2. **Swipe Right**: On the Task Manager screen, swipe right on any task card to reveal the green check action, then release or tap the check icon.

**Feedback**:
- A light haptic pulse (`HapticFeedback.lightImpact()`) confirms completion.
- The checkbox fills with the task's priority color and displays a white checkmark.
- Active reminders for the task are automatically canceled.

---

## 5. How to Mark a Completed Task as Incomplete

If you accidentally complete a task or need to reopen it:

1. **Tap the Checked Checkbox**: Tapping the checked circular checkbox unchecks the task.
2. **Swipe Right**: Swipe right on the completed task card to reveal the undo/rotate action (`rotateCcw`).

**Behavior**:
- The checkbox clears.
- The strike-through styling is removed.
- If the task has a future due time, local reminders are automatically rescheduled.

---

## 6. How Completed Tasks Appear in the UI

When a task is marked completed:

- **Checkbox**: Fills with priority color and displays a white check icon (`✓`).
- **Title & Description**: Styled with a clean strike-through line (`lineThrough`) and dimmed text color.
- **Card Opacity**: The entire task card smoothly fades to **0.6 opacity** via a 200ms animation.
- **Preserved Metadata**: Priority color borders, due date tags, due time tags, categories, and labels remain fully visible.

---

## 7. What Happens in Firebase After Completing a Task

When connected to the internet, marking a task as completed updates the Firestore document in the `tasks` collection instantly:

- `completed`: Set to `true`.
- `completedAt`: Set to the ISO-8601 timestamp of completion (e.g. `"2026-07-22T21:30:00.000Z"`).
- `updatedAt`: Set to the current ISO-8601 timestamp.

When unchecked:
- `completed`: Set to `false`.
- `completedAt`: Set to `null`.
- `updatedAt`: Set to the current timestamp.

---

## 8. What Happens If the Phone Is Offline

Project Arc is built with an **offline-first architecture**:

1. **Instant Local Update**: Toggling or creating a task updates the local Hive database immediately, so the UI updates with zero latency.
2. **Sync Queue**: If network connectivity is unavailable, the update or deletion is safely added to Hive's `tasksSyncQueueBox`.
3. **Automatic Cloud Sync**: As soon as internet connectivity returns, the background sync engine (`syncPending()`) uploads all queued changes to Firebase Cloud Firestore automatically.

---

## 9. What Happens Automatically at 11:59 PM

Every evening at **11:59 PM local device time**:

1. **Automated Identification**: The system scans for all tasks where `completed == true`.
2. **Permanent Deletion**:
   - Completed tasks are permanently removed from the local Hive cache.
   - Completed tasks are deleted from Firebase Cloud Firestore.
3. **Safety Rules**:
   - **Incomplete tasks** (`completed == false`) are **never deleted**.
   - **Future scheduled tasks** that are incomplete remain untouched.
   - **Duplicate Protection**: The cleanup records the date (`yyyy-MM-dd`) so it executes exactly once per day.
   - If offline at 11:59 PM, completed tasks are removed locally and deletion requests are queued to sync to Firestore when internet returns.

After 11:59 PM cleanup, completed tasks automatically disappear from your Today's Tasks list, giving you a fresh, clean dashboard for the next day.

---

## 10. How Dashboard Statistics Update

Dashboard metrics update **reactively and instantly** upon task completion, unchecking, or deletion:

- **Today's Progress**: Recalculates overall completion percentage across tasks and habits.
- **Completed Tasks**: Count increases immediately when checking a task, decreases when unchecking.
- **Pending Tasks**: Count decreases immediately when checking a task, increases when unchecking.
- **Productivity Score**: Re-evaluates daily score (0–100) dynamically based on completion rate and priority weights.

---

## 11. Expected Behavior & Summary Table

| Action | Local Hive | Firebase Firestore | Local Notifications | Dashboard Stats |
|---|---|---|---|---|
| **Mark Complete** | `completed = true` | `completed = true`, `completedAt = timestamp` | Canceled | Updates instantly |
| **Mark Incomplete** | `completed = false` | `completed = false`, `completedAt = null` | Rescheduled | Updates instantly |
| **11:59 PM Cleanup** | Deleted | Document Deleted | Cleaned up | Resets for new day |
| **Offline Mode** | Updated locally | Queued in Hive sync box | Operates normally | Updates instantly |
