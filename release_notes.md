# Project Arc — Release Notes v1.0.0

> **Version:** 1.0.0  
> **Build Number:** 1 (2026.07)  
> **Release Date:** July 22, 2026  
> **Platform Support:** Android 5.0+ (API Level 21+)  
> **Architecture:** Single-User Local-First Offline-First Architecture (Hive + Firestore Sync)

---

## 🚀 Key Features

### 1. Task Manager Module
- **Full CRUD & Scheduling**: Create, edit, complete, search, filter, and delete tasks with instant persistence.
- **Dynamic Sorting & Category Filtering**: Sort alphabetically or by due date; filter by categories (`Work`, `Personal`, `Health`, `Finance`, `Other`).
- **3-Tier Notification Alerts**: Automatic scheduling at 1 hour before, 30 minutes before, and at exact due time.
- **Task Statistics Strip**: Real-time summary displaying Total, Pending, Completed, Today, and Overdue tasks.
- **Undo Restoration**: Single-tap undo snackbar on accidental task deletions.

### 2. Habit Tracker Module
- **Flexible Goal Types**: Supports `Daily`, `Weekly`, and `Monthly` goal tracking.
- **Interactive 7-Day Matrix Grid**: Visual weekly habit grid with instant toggle check-in bubbles and haptic feedback.
- **Streaks & Progress Engine**: Real-time current streak, longest streak, and completion rate calculations.
- **Visual Analytics**: Interactive animated pie chart filtering breakdown by goal type.
- **Evening Reminders**: Automatic 8:00 PM check-in notification for uncompleted daily habits.

### 3. Money Tracker Module
- **Historical Monthly Budgets**: Store per-month budget limits (`budget_yyyy-MM`) preserved in Hive and Firestore.
- **Expanded Transaction CRUD**: Expanded Expense categories (`Food`, `Travel`, `Shopping`, `Fuel`, `Bills`, `Entertainment`, `Health`, `Education`, `Other`) and Income categories (`Salary`, `Freelancing`, `Investment`, `Gift`, `Other`).
- **Dynamic Balance Engine**: `Remaining Budget = Monthly Budget + Total Income - Total Expenses`.
- **Automated Monthly Summaries**: Save per-month financial snapshots into Hive and Firestore `monthlySummaries` collection.
- **Financial Analytics Suite**: 4 animated charts (Income vs Expense bar chart, Category spending pie chart, Savings rate ring, Monthly spending trend line chart).
- **Daily Reminders**: 8:00 PM check-in alert and 10:00 PM final reminder (auto-cancelled when today's transaction exists).

### 4. Integrated Dashboard
- **Unified Overview**: Today's Progress ring, Productivity Score banner (0-100 score), Remaining Budget, Daily Streaks, Today Expenses, and Monthly Savings.
- **10-Item Recent Activity Feed**: Unified chronological event feed across Tasks, Habits, and Money.
- **Quick Actions Speed Dial**: Floating Action Button menu giving one-tap access to Task, Habit, Transaction, and Budget forms.
- **Pull-to-Refresh**: Unified single-pass background sync via `SyncService`.

### 5. Global Application Services & Settings
- **Global Search**: Real-time search across Tasks, Habits, and Transactions.
- **Notification Center**: In-app feed displaying active, scheduled, and overdue alerts.
- **Appearance Settings**: Seamless OLED Dark Mode and Light Mode switching.
- **Data & Storage Diagnostics**: Firestore sync status, Hive storage size, Manual Sync Now button, Clear Cache, and Data Reset confirmation dialogs.

---

## 🛠 Major Stabilization & Bug Fixes

- **Hive Generic Box Casting**: Fixed generic type mismatch across 6 Hive boxes.
- **Android 12+ Broadcast Receiver Flags**: Added explicit `RECEIVER_NOT_EXPORTED` flags for Android 12+ API 31+ compliance.
- **Theme Picker Adaptability**: Fixed hardcoded dark mode colors in date/time pickers.
- **Notification Lifecycle Safety**: Wrapped timezone scheduling in try-catch guards to prevent initialization crashes in test or unexpected environments.

---

## 📄 Build Artifacts

- **Release APK**: `build/app/outputs/flutter-apk/app-release.apk` (55.0 MB)
- **Release AppBundle**: `build/app/outputs/bundle/release/app-release.aab` (44.5 MB)
