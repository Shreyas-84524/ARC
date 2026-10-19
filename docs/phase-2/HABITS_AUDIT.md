# Phase 2 Habits and Dashboard Audit

## 1. Overview and Objectives

This audit provides an exhaustive analysis of the original Flutter application's implementation of the Habit Tracker and Productivity Dashboard in `C:\dev\ARC`. It documents exact data models, persistence structures, streak algorithms, date string semantics, user scoping rules, and architectural nuances required for 100% compatibility in ARC-Kotlin Phase 2.

---

## 2. Responsible Source Files in Flutter Codebase (`C:\dev\ARC`)

| Area | File Path | Primary Responsibility |
|---|---|---|
| **Habit Model** | `lib/features/habit_tracker/models/habit_model.dart` | Hive TypeId 1 model representing Habit definitions |
| **Habit Entry Model** | `lib/features/habit_tracker/models/habit_entry_model.dart` | Hive TypeId 2 model representing daily completion check-ins |
| **Habit Repository** | `lib/features/habit_tracker/repository/habit_repository.dart` | Hive Box access (`habits`, `habitEntries`, `habitsSyncQueue`), Firestore sync |
| **Habits Screen** | `lib/features/habit_tracker/screens/habits_screen.dart` | Habit list UI, daily analytics (Daily/Weekly/Monthly), completion buttons |
| **Habit Editor** | `lib/features/habit_tracker/widgets/habit_editor_sheet.dart` | ModalBottomSheet for habit creation and editing with preset colors & reminder times |
| **Streak Algorithms** | `lib/providers/global_providers.dart` (`getHabitMetrics`) | `currentStreak`, `longestStreak`, and `completionRate` calculation logic |
| **Dashboard Repository** | `lib/features/dashboard/repository/dashboard_repository.dart` | Aggregation of Tasks, Habits, Money metrics, and Productivity Score calculation |
| **Dashboard Screen** | `lib/features/dashboard/screens/dashboard_screen.dart` | Progress ring, score banner, today's habits row, today's tasks list, recent activities |

---

## 3. Data Schema & Persistence Contracts

### 3.1 Habit Entity (`habit_model.dart`, Hive TypeId: 1)
- `id`: `String` (UUID v4)
- `name`: `String` (Title of the habit)
- `category`: `String` (Default: "Other", options: "Health", "Fitness", "Learning", "Mindfulness", "Productivity", "Other")
- `colorValue`: `int` (ARGB color representation, e.g., `0xffccff00`, `0xffef4444`)
- `reminderTime`: `String?` (Format: `"HH:mm"`, e.g., `"08:00"`)
- `createdAt`: `DateTime` (ISO-8601 string)
- `updatedAt`: `DateTime` (ISO-8601 string)
- **Firestore Document Path:** `users/{userId}/habits/{habitId}`
- **Firestore Map:** `{'id': id, 'name': name, 'category': category, 'colorValue': colorValue, 'reminderTime': reminderTime, 'createdAt': isoString, 'updatedAt': isoString}`

### 3.2 HabitEntry Entity (`habit_entry_model.dart`, Hive TypeId: 2)
- `id`: `String` — **Composite Key Pattern:** `${habitId}_${dateStr}` (e.g., `uuid-123_2026-07-20`)
- `habitId`: `String` (UUID referencing parent Habit)
- `dateStr`: `String` (Calendar date formatted as `"yyyy-MM-dd"` in device local time)
- `completed`: `bool`
- **Firestore Document Path:** `users/{userId}/habitEntries/{entryId}`
- **Firestore Map:** `{'id': id, 'habitId': habitId, 'dateStr': dateStr, 'completed': completed}`

### 3.3 Semantics of `dateStr`
- The `dateStr` is generated using device local date: `DateFormat('yyyy-MM-dd').format(DateTime.now())`.
- It does **not** contain time or timezone offsets, preventing daylight-saving and UTC midnight shifts from distorting daily completion records.
- Deleting or unchecking an entry in Flutter executes `_entryBox.delete(entryId)` and Firestore `delete()`, rather than setting `completed = false`. In Kotlin Room, unchecking can either set `completed = false` or delete the entry. To remain strictly backward-compatible with queries filtering `completed == true`, we support both semantics seamlessly.

---

## 4. Streak Calculation Logic (`getHabitMetrics`)

The streak engine in `lib/providers/global_providers.dart` evaluates completion dates:

1. **Date Normalization:**
   Entries matching `habitId` with `completed == true` are converted to calendar dates `Date(year, month, day)` and sorted descending.
2. **Current Streak Evaluation:**
   - Evaluates `today` and `yesterday`:
   - If **neither** `today` nor `yesterday` is in the completed dates set, `currentStreak = 0`.
   - If `today` is completed, the streak count starts at `today` and counts consecutive backward days.
   - If `today` is *not* completed, but `yesterday` is completed, the streak remains active (pending today's check-in), counting backwards from `yesterday`.
3. **Longest Streak Evaluation:**
   - Completed dates are sorted chronologically ascending.
   - Consecutive days with difference == 1 increment the current run.
   - Gaps (difference > 1) record the run against the maximum and reset `currentRun = 1`.
4. **Completion Rate Calculation:**
   - `totalDays = today.difference(createdDate).inDays + 1` (minimum 1).
   - `completionRate = (completedDates.length / totalDays).clamp(0.0, 1.0)`.

---

## 5. Dashboard Productivity Score & Metrics

The Dashboard aggregates Tasks and Habits via `DashboardRepository`:

- **Task Rate:** `taskRate = (completedTodayTasks / totalTodayTasks).clamp(0.0, 1.0)`
- **Habit Rate:** `habitRate = (completedTodayHabits / totalHabits).clamp(0.0, 1.0)`
- **Task Score Component:** `taskScore = taskRate * 50.0`
- **Habit Score Component:** `habitScore = habitRate * 50.0`
- **Total Productivity Score:** `todayProductivityScore = (taskScore + habitScore).round().clamp(0, 100)` (0 to 100 integer)
- **Daily Streak:** Max `currentStreak` across all active habits.
- **Recent Activities Feed:** Top 10 items combining completed tasks, task creations, and habit check-ins, ordered by timestamp descending.

---

## 6. Known Limitations in Flutter Implementation

1. **Main-Thread Metric Recomputations:** `getHabitMetrics` was invoked synchronously in build methods (`habits_screen.dart:70`), recalculating historical streaks on every frame. In Kotlin, streak calculations will be computed in ViewModels on background coroutines (`Dispatchers.Default`).
2. **Hive Cascade Deletion:** In Flutter, habit deletion required iterating through all entry keys in Dart to delete orphaned entries. In Room, this will be handled automatically at the SQLite engine level using `onDelete = ForeignKey.CASCADE`.
3. **Multi-User Isolation:** Flutter user boxes relied on directory paths `habits_<uid>.hive`. In Room, strict SQL user isolation (`WHERE user_id = :userId`) prevents any cross-user data leakage.
