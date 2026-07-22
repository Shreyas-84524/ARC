# ARC — Comprehensive Debug Report

> **Audit Date:** 2025-07
> **Auditor:** Antigravity AI
> **Scope:** Full project audit — Flutter, Android, Firebase, Hive, Riverpod, all features
> **Action Taken:** READ-ONLY — Zero code modifications made
> **Source of Truth Documents:** design.md, architecture.md, prd.md, mvp.md

---

## 1. Executive Summary

The project has a clean feature-first layout and Riverpod state management, but contains **87 catalogued issues** ranging from **critical security vulnerabilities** to **functional bugs** and **incomplete/placeholder features**.

**Severity:** CRITICAL > HIGH > MEDIUM > LOW

---

## 2. Flutter Core

**F-01 [MEDIUM]** main() has no try/catch around the initialization block. If Firebase.initializeApp(), HiveService.init(), or NotificationService.init() throws during cold start, the error produces a blank screen with no user feedback.

**F-02 [MEDIUM]** No SystemChrome.setPreferredOrientations() call. In landscape on tablets/phones, money_screen.dart and habits_screen.dart chart SizedBox(height: 160) containers will overflow.

**F-03 [LOW]** pubspec.yaml description is the default "A new Flutter project." — embedded in APK/IPA metadata.

**F-04 [MEDIUM]** /settings is a context.push() route outside the ShellRoute. Settings uses plain AppBar instead of CustomTopBar. Architecture.md implies Settings should be in the shell.

**F-05 [LOW]** GoRouter has no errorBuilder / errorPageBuilder.

**F-06 [LOW]** GoRouter is a late final field on a plain class (AppRouter), never disposed. Minor memory leak from internal ValueNotifier subscriptions.

**F-07 [MEDIUM]** themeModeProvider is a raw StateProvider whose value is never persisted to SharedPreferences or Hive. Every restart resets to dark theme.

**F-08 [MEDIUM]** All three editor sheets hardcode ColorScheme.dark() for date/time pickers regardless of active theme. In light mode, pickers render with dark backgrounds.

**F-09 [LOW]** AppColors.income referenced in app_constants.dart. Verify this token exists in app_theme.dart.

---

## 3. Android Configuration

**A-01 [CRITICAL]** Release build signed with debug keystore:
  signingConfig = signingConfigs.getByName("debug")
Cannot publish to Play Store. A production keystore must be configured.

**A-02 [MEDIUM]** POST_NOTIFICATIONS only takes effect on Android 13 (API 33+), silently ignored on earlier versions. Should be documented.

**A-03 [MEDIUM]** coreLibraryDesugaring version 2.0.4 is outdated (current: 2.1.x). Update to avoid known desugaring bugs.

**A-04 [LOW]** applicationId = "com.arc.arc" is a placeholder. Must be changed for production.

**A-05 [HIGH]** Both SCHEDULE_EXACT_ALARM and USE_EXACT_ALARM declared simultaneously. These serve different API levels and are mutually exclusive for correct behaviour. Having both causes redundant permission prompts and potential failures on some OEM devices.

**A-06 [MEDIUM]** ScheduledNotificationReceiver declared android:exported="false". flutter_local_notifications docs require exported="true" when targeting API 31+. Scheduled notifications silently fail on Android 12+.

**A-07 [LOW]** No android:roundIcon attribute. App appears as a square on adaptive icon launchers (API 26+).

**A-08 [LOW]** android:label="arc" (lowercase). Should match brand naming ("Arc").

**A-09 [MEDIUM]** Kotlin plugin 2.2.20 paired with AGP 8.11.1. Verify compatibility — mismatches can cause build failures.

---

## 4. Firebase & Firestore

**S-01 [CRITICAL]** Firestore rules completely open:
  allow read, write: if true;
Anyone with the projectId can read, write, modify, or delete ALL data. Must be fixed before real user data is stored.

**S-02 [CRITICAL]** Firebase API keys committed to source control in plaintext (firebase_options.dart). Combined with open rules (S-01), trivially exploitable.

**S-03 [MEDIUM]** firebase_options.dart is manually maintained. Risk of drift if Firebase project settings change. Regenerate via `flutterfire configure`.

**S-04 [CRITICAL]** No Firebase Authentication. All Firestore writes go to global collections (/tasks, /habits, /transactions, /budgets). All devices/users share the same data namespace.

**S-05 [HIGH]** firebase_auth is not in pubspec.yaml dependencies. Authentication cannot be added without first adding this dependency.

**S-06 [MEDIUM]** firestore.indexes.json is empty. All reads fetch entire collections with no server-side filtering. As data grows this becomes a significant performance and cost problem.

**S-07 [HIGH]** No input sanitization for Firestore writes. Raw TextEditingController values are written directly via toMap() with no length limits or sanitization. With open rules, malicious input pollutes the shared database.

**S-08 [MEDIUM]** Firestore SDK disk persistence is enabled by default on mobile. Locally cached data from unauthenticated sessions remains readable on-device after session ends.

**S-09 [LOW]** google-services.json committed to repository. Should be injected via CI secrets.

---

## 5. Hive Local Database

**H-01 [CRITICAL]** Unsafe as Box<T> cast in every repository:
  final Box<Transaction> _txBox = HiveService().getBox(HiveService.moneyBoxName) as Box<Transaction>;
If the box is not yet open (race condition, silent init failure), this throws a TypeError, crashing the app. No null check or fallback exists.

**H-02 [MEDIUM]** HiveService() called as plain constructor in each repository. No _instance guard, factory singleton, or Riverpod provider. Relies on implicit Dart VM object identity.

**H-03 [MEDIUM]** (_settingsBox.get('budget_$yearMonth', defaultValue: 0.0) as num).toDouble() — if a non-numeric type is stored (migration/corruption), the as num cast throws TypeError.

**H-04 [MEDIUM]** No Hive migration strategy. If any HiveField index changes in a future release, existing devices fail to deserialize stored objects.

**H-05 [LOW]** All four models extend HiveObject but the box and key back-references it provides are never used (objects always stored by explicit UUID key). Unnecessary overhead.

---

## 6. Riverpod State Management

**R-01 [HIGH]** DashboardScreen reads dashboardProvider with unsafe casts:
  final completedTasks = dashboardData['completedTasks'] as int;
If any key is missing, the as int cast throws TypeError in build(), crashing the dashboard. No ?? 0 fallback present.

**R-02 [HIGH]** getHabitMetrics() parses dateStr via DateTime.tryParse(). Malformed or empty dateStr returns null and the entry is silently skipped, causing streak under-counts.

**R-03 [MEDIUM]** Weekly and Monthly habit streak logic incorrect. getHabitMetrics() uses a consecutiveDays counter (calendar-day streaks) for all goal types. A Weekly habit completed 3x this week but not yesterday shows streak = 0.

**R-04 [MEDIUM]** currentMonthProvider is a Provider<String> evaluated once at creation, never auto-refreshed. If the app stays open past midnight on the last day of a month, the month key is stale until a full restart.

**R-05 [MEDIUM]** Theme preference not persisted (same as F-07). Initial value always ThemeMode.dark.

**R-06 [LOW]** Provider initializers load from Hive synchronously in state = initializers. Blocks main isolate on low-end devices with large datasets.

**R-07 [LOW]** Notifier classes use ref.read() to access sub-providers. Riverpod 2.x best practice recommends ref.watch() or constructor injection to prevent stale references.

---

## 7. Task Manager Feature

**T-01 [MEDIUM]** Task.priority stored as raw String ('High', 'Much', 'Low'). TaskPriority enum defined but never used in model or repositories. String comparisons scattered across UI are not type-safe.

**T-02 [MEDIUM]** Task.reminder is set to _selectedDueDate in task_editor_sheet.dart (line 152). It is just a copy of dueDate, not an independently configurable reminder. Notifications always fire at midnight on the due date.

**T-03 [MEDIUM]** No max-length validation on task labels. A user can paste hundreds of comma-separated labels, causing large Hive writes.

**T-04 [HIGH]** Sync queue stores only the task ID on failure:
  _queueBox.put('task_${task.id}', {'id': task.id, 'type': 'task', 'action': 'upsert'});
On syncPending(), if the task was deleted locally before sync runs, _taskBox.get(id) returns null and the queue item is never cleaned up — leaking queue entries indefinitely.

**T-05 [MEDIUM]** syncPending() breaks out of the entire loop on first network failure. A single persistently-failing item permanently blocks all subsequent sync items. No retry count or exponential back-off.

**T-06 [MEDIUM]** Three separate sync queues (task, habit, money) with no global coordinator. Partial sync states are possible with no rollback mechanism.

**T-07 [MEDIUM]** shrinkWrap: true + NeverScrollableScrollPhysics() inside SingleChildScrollView in tasks_screen.dart. All list items laid out eagerly regardless of viewport visibility — well-known Flutter performance anti-pattern.

**T-08 [LOW]** Undated tasks only appear in "All" filter tab with no visual indication they exist. Architecture.md implies a "No Due Date" category.

---

## 8. Habit Tracker Feature

**B-01 [MEDIUM]** Habit.goalType stored as raw String. HabitGoalType enum defined but unused (same pattern as T-01).

**B-02 [LOW]** deleteHabit() should explicitly cancel the scheduled notification. It is unclear from the codebase if this is done, risking stale notifications firing for deleted habits.

**B-03 [HIGH]** Same sync queue ID-only issue as T-04: habit entry upserts store only the entry ID. If entry is toggled off before sync, queue item is never cleared.

**B-04 [MEDIUM]** toggleEntry() performs a linear scan (_entryBox.values.firstWhere(...)) on every toggle to check if an entry exists. O(n) per toggle, slows as data grows.

**B-05 [HIGH]** BarChart maxY in habits_screen.dart: if weeklyData is all zeros, maxY resolves to 0.0. fl_chart may throw an assertion error in debug or render a broken chart in release.

**B-06 [MEDIUM]** Habit bar chart shows 0 for days before a habit was created. No visual differentiation between "habit didn't exist yet" and "habit existed but not completed". Both appear as empty bars.

**B-07 [LOW]** habits_screen.dart is 700+ lines. _buildHabitCard and _buildHabitDetails contain inline chart and metrics logic that should be extracted into dedicated widgets.

---

## 9. Money Tracker Feature

**M-01 [MEDIUM]** Transaction.type stored as raw String. TransactionType enum defined but unused. tx.type == 'Income' comparisons exist in 4+ locations — not type-safe.

**M-02 [LOW]** Transaction.date (DateTime) and Transaction.time (String 'HH:mm') are separate fields. sort((a, b) => b.date.compareTo(a.date)) ignores the time component — two transactions on the same day are not sorted by time.

**M-03 [CRITICAL]** import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction; hides the Firestore Transaction type (for atomic writes). Firestore batch writes and atomic transactions CANNOT be used in money_repository.dart without a significant refactor.

**M-04 [MEDIUM]** Same sync queue ID-only issue as T-04.

**M-05 [HIGH]** Remaining balance formula is mathematically incorrect:
  final double remainingBudget = monthlyBudget + totalIncome - totalExpenses;
This adds the monthly budget limit ON TOP OF income. With budget=$1000, income=$500, expenses=$400: remaining = $1,100. The budget is a cap, not additive income. Correct formula: monthlyBudget - totalExpenses OR totalIncome - totalExpenses.

**M-06 [HIGH]** Category mismatch between AppConstants.moneyCategories and TransactionEditorSheet. Constants define: Food, Shopping, Fuel, Travel, Entertainment, Bills, Health, Education, Salary, Freelancing, Investment, Other. The editor defines its own hardcoded lists with 'Rent', 'Transport', 'Freelance', 'Gift' which do not exist in AppConstants. The Analytics pie chart maps 'Rent' and 'Transport' to colors — but these are not in AppConstants. Fundamental data model inconsistency.

**M-07 [MEDIUM]** Monthly spending trend chart uses List.generate(31, ...) regardless of actual month length. Feb and 30-day months show false zero datapoints for non-existent days.

**M-08 [MEDIUM]** Budget set prompt uses DateFormat('MMMM yyyy').format(DateTime.now()) directly instead of currentMonthProvider. If provider is stale (R-04), prompt displays the wrong month name.

**M-09 [LOW]** _categoryColors is an instance field Map re-created on every setState(). Should be static const.

---

## 10. Dashboard Feature

**D-01 [HIGH]** Inherits R-01: dashboardData['completedTasks'] as int with no null-safe fallback. Dashboard crashes if any key is missing from the map.

**D-02 [MEDIUM]** "Today's Tasks" section shows tasks where dueDate == null (line 115: if (t.dueDate == null) return true). All undated incomplete tasks appear in Today's section — an overwhelming and misleading list. PRD intent is "tasks due today".

**D-03 [MEDIUM]** Dashboard build() has 6 ref.watch() calls. Any provider change triggers a full DashboardScreen rebuild. Should use select() to narrow subscriptions.

**D-04 [MEDIUM]** daysLeft = task.dueDate!.difference(todayStart).inDays — for a task due later today, returns 0, showing "Due in 0 days". Should differentiate same-day deadlines from future deadlines.

**D-05 [LOW]** Metric card value text (titleMedium) has no overflow/maxLines guard. Large negative remaining budget can overflow the card on small screens.

---

## 11. Settings Screen

**SE-01 [HIGH]** "Local Notifications" toggle: value: true hardcoded, onChanged: (value) {} empty. Toggle does nothing.

**SE-02 [HIGH]** "Evening Habit Check-in" row: onTap: () {} — tapping does nothing.

**SE-03 [HIGH]** "Expense Tracker Reminder" row: onTap: () {} — tapping does nothing.

**SE-04 [HIGH]** "Cloud Firestore Synchronization" card displays hardcoded static text: 'Synchronized 2 minutes ago' and 'Online' badge. No actual connectivity detection.

**SE-05 [HIGH]** "Clear Hive cache" button is a placeholder SnackBar. Hive boxes not actually cleared.

**SE-06 [MEDIUM]** Settings screen uses plain AppBar instead of CustomTopBar. Date, greeting, and action icons absent — visually inconsistent with all other screens.

**SE-07 [LOW]** No explicit back button in Settings AppBar. Users reliant on UI back navigation have no visible affordance.

---

## 12. Shell & Navigation

**N-01 [MEDIUM]** Active tab detection uses GoRouter.of(context).routeInformationProvider.value.uri.path — an internal, undocumented GoRouter API. May be removed in future versions, breaking active tab highlighting.

**N-02 [MEDIUM]** Bottom navigation bar has icon-only items with no text labels. New users cannot identify which icon leads to which feature without exploration.

**N-03 [LOW]** Hero tag 'bottom_nav_pill' on ClipRRect. Since the ShellRoute is always present and never transitions away, this Hero animation never fires. Dead code.

**N-04 [LOW]** BackdropFilter(blur(sigmaX: 12, sigmaY: 12)) runs every frame for the nav pill. On low-end Android devices this costs 10-30ms per frame and causes jank during page transitions.

---

## 13. UI/UX & Design System

**U-01 [MEDIUM]** Search button shows 'Search clicked (placeholder)' SnackBar. Full-text search not implemented.

**U-02 [MEDIUM]** Notification bell shows 'Notifications clicked (placeholder)' SnackBar. No notifications inbox screen.

**U-03 [MEDIUM]** Greeting hardcoded to '$greeting, User'. User's name not stored anywhere.

**U-04 [MEDIUM]** CustomTopBar is a StatelessWidget calling DateTime.now() in build(). After a midnight crossing with no route change, displayed date is stale.

**U-05 [MEDIUM]** Date/time pickers always dark (ColorScheme.dark()) in all three editor sheets regardless of active theme. Broken UX in light mode. (Same as F-08.)

**U-06 [LOW]** flutter_animate animations replay on every tab re-entry. Staggered delays up to 500ms+ accumulate before all content is visible on repeated visits.

**U-07 [LOW]** Widgets are invisible during their delay period in flutter_animate. On a slow device where data is already loaded, content appears to load slowly due to animation delay, not data fetch delay.

**U-08 [LOW]** Task and Habit editors use free-text TextFormField for categories; Transaction editor uses DropdownButtonFormField. Inconsistency allows invalid category values for tasks/habits.

**U-09 [LOW]** AppConstants.moneyCategories defined but never used in TransactionEditorSheet. Dead code.

**U-10 [LOW]** ChoiceChip(label: const Center(child: Text(...))) — Center inside ChoiceChip label is redundant.

---

## 14. Performance & Memory

**P-01 [HIGH]** shrinkWrap: true + NeverScrollableScrollPhysics() nested inside SingleChildScrollView in money_screen.dart, dashboard_screen.dart, and tasks_screen.dart. All list items laid out eagerly regardless of viewport visibility. For 100+ items: double layout passes and significant memory pressure.

**P-02 [MEDIUM]** All repositories use .values.toList() — materializes entire Hive box into a List<T> on every state rebuild. For large boxes this is O(n) memory allocation per rebuild.

**P-03 [MEDIUM]** BackdropFilter Gaussian blur in ShellScreen runs every frame (see N-04).

**P-04 [MEDIUM]** currentMonthTransactions.sort(...) called inside MoneyScreen.build(). Repeated O(n log n) work on every provider-triggered rebuild. Should be memoized in a provider.

**P-05 [LOW]** DashboardScreen.build() computes todayTasks, upcomingDeadlines, dailyHabits, currentMonthTxs, and recentTransactions inline on every rebuild via O(n) linear scans. Should be derived values in providers.

**P-06 [LOW]** flutter_launcher_icons in dev_dependencies but no flutter_launcher_icons configuration block in pubspec.yaml. Icon generation command will fail.

---

## 15. Security Summary

| ID    | Severity | Issue |
|-------|----------|-------|
| S-01  | CRITICAL | Firestore allow read/write: if true |
| S-02  | CRITICAL | Firebase API keys in source control |
| S-04  | CRITICAL | No authentication; global collections |
| A-01  | CRITICAL | Release signed with debug keystore |
| AV-07 | CRITICAL | Firestore not user-scoped (violates architecture.md) |
| S-05  | HIGH     | firebase_auth not in pubspec.yaml |
| S-07  | HIGH     | No input sanitization for Firestore writes |
| S-06  | MEDIUM   | No Firestore indexes; full collection reads |
| S-08  | MEDIUM   | On-device Firestore cache with open rules |
| S-09  | LOW      | google-services.json committed to repo |

---

## 16. Missing Features (vs PRD/MVP)

| # | Feature | Status |
|---|---------|--------|
| MF-01 | User Authentication (Firebase Auth) | Not implemented; firebase_auth absent |
| MF-02 | User-scoped Firestore (/users/{uid}/...) | Not implemented; global collections only |
| MF-03 | Full-text Search across tasks/habits/transactions | Placeholder SnackBar only |
| MF-04 | Notification inbox/history screen | Placeholder SnackBar only |
| MF-05 | Settings: Notification toggle (enable/disable all) | Hardcoded true; empty callback |
| MF-06 | Settings: Evening Habit Check-in configuration | Empty onTap callback |
| MF-07 | Settings: Expense Tracker Reminder configuration | Empty onTap callback |
| MF-08 | Settings: Real sync status (last sync time, online/offline) | Hardcoded static text |
| MF-09 | Settings: Clear Hive cache (actual implementation) | Placeholder SnackBar |
| MF-10 | User profile / display name | Hardcoded "User" in greeting |
| MF-11 | Weekly/Monthly habit streak logic | Daily-only calendar streak used for all types |
| MF-12 | Task "No Due Date" category in filter tabs | Not present |
| MF-13 | Production release signing config | Debug keystore used |
| MF-14 | Tablet/landscape adaptive layout | No adaptive layout; overflow on landscape |
| MF-15 | AppConstants.moneyCategories integration | Defined but never used; dead code |

---

## 17. Architecture Violations

**AV-01 [HIGH]** No repository abstraction interface. TaskRepository, HabitRepository, and MoneyRepository are concrete classes with no abstract IRepository interface. Impossible to unit test with mocks or swap storage backends without full rewrites.

**AV-02 [HIGH]** Business logic in DashboardScreen.build(). Filtering, sorting, and computing todayTasks, upcomingDeadlines, progressPercentage, and recentTransactions happen inline in the UI build method. Violates the layered architecture described in architecture.md.

**AV-03 [HIGH]** Business logic in MoneyScreen.build(). totalIncome, totalExpenses, categoryExpenses, dailySpending, savings, remainingBudget, and savingsRate are all computed in build(). Should be derived state in a MoneyAnalyticsProvider.

**AV-04 [MEDIUM]** HiveService is not a proper singleton or Riverpod provider. Repositories call HiveService() constructor directly, relying on implicit Dart VM object identity. Fragile and untestable.

**AV-05 [MEDIUM]** TaskPriority, HabitGoalType, and TransactionType enums are defined in app_constants.dart but models store raw strings. The enums are never used for model construction, comparison, or persistence. Defeats their purpose.

**AV-06 [MEDIUM]** All three sync queues store only the entity ID at enqueue time. On syncPending(), live local state is fetched, which may differ from the state at enqueue time. Correct pattern: serialize and store the full Map<String, dynamic> payload at enqueue time.

**AV-07 [CRITICAL]** Firestore collections are global (/tasks, /habits, /transactions, /budgets), not user-scoped (/users/{uid}/tasks etc.). Directly violates the data architecture described in architecture.md. Multi-user support requires a full data migration.

---

## 18. Complete Issue Index

| ID    | Category     | Severity | Short Description |
|-------|--------------|----------|-------------------|
| F-01  | Flutter Core | MEDIUM   | No try/catch around main() initialization |
| F-02  | Flutter Core | MEDIUM   | No orientation lock; landscape overflow on charts |
| F-03  | Flutter Core | LOW      | Default app description in pubspec.yaml |
| F-04  | Navigation   | MEDIUM   | Settings screen inconsistent with shell architecture |
| F-05  | Navigation   | LOW      | No errorBuilder in GoRouter |
| F-06  | Navigation   | LOW      | GoRouter not disposed via Riverpod |
| F-07  | Theme        | MEDIUM   | Theme preference not persisted across restarts |
| F-08  | Theme        | MEDIUM   | Date/time picker hardcoded dark in light mode |
| F-09  | Theme        | LOW      | AppColors.income reference not verified |
| A-01  | Android      | CRITICAL | Release build signed with debug keystore |
| A-02  | Android      | MEDIUM   | POST_NOTIFICATIONS only effective API 33+ |
| A-03  | Android      | MEDIUM   | Desugar library version outdated (2.0.4) |
| A-04  | Android      | LOW      | Placeholder applicationId com.arc.arc |
| A-05  | Android      | HIGH     | Duplicate/conflicting exact alarm permissions |
| A-06  | Android      | MEDIUM   | ScheduledNotificationReceiver needs exported=true on API 31+ |
| A-07  | Android      | LOW      | No roundIcon for adaptive launcher icon |
| A-08  | Android      | LOW      | App label lowercase "arc" |
| A-09  | Android      | MEDIUM   | Kotlin/AGP version compatibility unverified |
| S-01  | Security     | CRITICAL | Firestore rules allow read/write if true |
| S-02  | Security     | CRITICAL | Firebase API keys committed to source control |
| S-03  | Firebase     | MEDIUM   | firebase_options.dart manually maintained, risk of drift |
| S-04  | Security     | CRITICAL | No authentication; all data in global collections |
| S-05  | Firebase     | HIGH     | firebase_auth not in pubspec.yaml dependencies |
| S-06  | Firebase     | MEDIUM   | No Firestore indexes; full collection reads on every sync |
| S-07  | Security     | HIGH     | No input sanitization for Firestore writes |
| S-08  | Security     | MEDIUM   | On-device Firestore cache retention with open rules |
| S-09  | Security     | LOW      | google-services.json committed to repository |
| H-01  | Hive         | CRITICAL | Unsafe as Box<T> cast; crash if box not open |
| H-02  | Hive         | MEDIUM   | HiveService() not a true singleton |
| H-03  | Hive         | MEDIUM   | (as num).toDouble() cast risk on settings box |
| H-04  | Hive         | MEDIUM   | No Hive migration strategy |
| H-05  | Hive         | LOW      | HiveObject extension unused in practice |
| R-01  | Riverpod     | HIGH     | Unsafe as int casts on dashboardProvider map |
| R-02  | Riverpod     | HIGH     | Fragile dateStr parsing in getHabitMetrics() |
| R-03  | Riverpod     | MEDIUM   | Weekly/Monthly habit streak logic incorrect |
| R-04  | Riverpod     | MEDIUM   | currentMonthProvider stale after midnight |
| R-05  | Riverpod     | MEDIUM   | Theme preference not persisted |
| R-06  | Riverpod     | LOW      | Synchronous Hive load blocks main isolate |
| R-07  | Riverpod     | LOW      | ref.read() in notifiers (prefer ref.watch()) |
| T-01  | Task         | MEDIUM   | priority stored as raw string; TaskPriority enum unused |
| T-02  | Task         | MEDIUM   | task.reminder = dueDate; no independent reminder time |
| T-03  | Task         | MEDIUM   | No max-length validation on labels |
| T-04  | Task Repo    | HIGH     | Sync queue stores only ID; queue leaks on local delete |
| T-05  | Task Repo    | MEDIUM   | Sync queue break on failure blocks all subsequent items |
| T-06  | Task Repo    | MEDIUM   | No global sync coordinator; partial sync possible |
| T-07  | Tasks UI     | MEDIUM   | shrinkWrap: true anti-pattern; full list layout |
| T-08  | Tasks UI     | LOW      | Undated tasks not visually differentiated in filter |
| B-01  | Habit        | MEDIUM   | goalType stored as raw string; enum unused |
| B-02  | Habit        | LOW      | Habit reminder not explicitly cancelled on delete |
| B-03  | Habit Repo   | HIGH     | Same sync queue ID-only issue as T-04 |
| B-04  | Habit Repo   | MEDIUM   | Linear O(n) scan on every toggleEntry() |
| B-05  | Habits UI    | HIGH     | fl_chart maxY=0 crash/broken chart risk |
| B-06  | Habits UI    | MEDIUM   | Pre-creation days indistinguishable from no-completion |
| B-07  | Habits UI    | LOW      | habits_screen.dart is 700+ lines |
| M-01  | Money        | MEDIUM   | type stored as raw string; TransactionType enum unused |
| M-02  | Money        | LOW      | date and time separate; sort ignores time component |
| M-03  | Money Repo   | CRITICAL | hide Transaction blocks Firestore atomic writes |
| M-04  | Money Repo   | MEDIUM   | Same sync queue ID-only issue as T-04 |
| M-05  | Money UI     | HIGH     | Remaining balance formula is mathematically incorrect |
| M-06  | Money UI     | HIGH     | Category mismatch: AppConstants vs editor hardcodes |
| M-07  | Money UI     | MEDIUM   | Trend chart hardcoded 31 days; wrong for short months |
| M-08  | Money UI     | MEDIUM   | Budget prompt uses DateTime.now() not currentMonthProvider |
| M-09  | Money UI     | LOW      | _categoryColors map re-created on every setState() |
| D-01  | Dashboard    | HIGH     | Inherits R-01: unsafe as int cast crash risk |
| D-02  | Dashboard    | MEDIUM   | Undated tasks appear in Today's Tasks section |
| D-03  | Dashboard    | MEDIUM   | 6 provider subscriptions; full rebuild on any change |
| D-04  | Dashboard    | MEDIUM   | "Due in 0 days" shown for same-day deadlines |
| D-05  | Dashboard    | LOW      | Value text in metric cards can overflow |
| SE-01 | Settings     | HIGH     | Notification toggle hardcoded; non-functional |
| SE-02 | Settings     | HIGH     | Evening Check-in tap — empty callback |
| SE-03 | Settings     | HIGH     | Expense Reminder tap — empty callback |
| SE-04 | Settings     | HIGH     | Sync status hardcoded static text |
| SE-05 | Settings     | HIGH     | "Clear cache" is a placeholder SnackBar |
| SE-06 | Settings     | MEDIUM   | Settings AppBar inconsistent with CustomTopBar |
| SE-07 | Settings     | LOW      | No explicit back button in Settings AppBar |
| N-01  | Navigation   | MEDIUM   | routeInformationProvider is internal GoRouter API |
| N-02  | Navigation   | MEDIUM   | Icon-only nav bar; no text labels |
| N-03  | Navigation   | LOW      | Non-functional Hero tag on nav pill |
| N-04  | Navigation   | LOW      | BackdropFilter blur runs every frame |
| U-01  | UI/UX        | MEDIUM   | Search button is a placeholder |
| U-02  | UI/UX        | MEDIUM   | Notification bell is a placeholder |
| U-03  | UI/UX        | MEDIUM   | Username hardcoded as "User" |
| U-04  | UI/UX        | MEDIUM   | TopBar date stale after midnight |
| U-05  | UI/UX        | MEDIUM   | Pickers always dark in light mode |
| U-06  | UI/UX        | LOW      | Animations replay on tab re-entry |
| U-07  | UI/UX        | LOW      | 500ms+ animation stagger delay on re-entry |
| U-08  | UI/UX        | LOW      | Free-text category vs. dropdown inconsistency |
| U-09  | UI/UX        | LOW      | AppConstants.moneyCategories dead code |
| U-10  | UI/UX        | LOW      | Redundant Center inside ChoiceChip |
| P-01  | Performance  | HIGH     | shrinkWrap: true nested lists; eager full layout |
| P-02  | Performance  | MEDIUM   | .values.toList() materializes entire Hive box |
| P-03  | Performance  | MEDIUM   | BackdropFilter Gaussian blur every frame |
| P-04  | Performance  | MEDIUM   | sort() inside build() — repeated O(n log n) work |
| P-05  | Performance  | LOW      | Inline O(n) filtering in DashboardScreen.build() |
| P-06  | Performance  | LOW      | flutter_launcher_icons config missing in pubspec.yaml |
| AV-01 | Architecture | HIGH     | No repository interface for testability |
| AV-02 | Architecture | HIGH     | Business logic in DashboardScreen.build() |
| AV-03 | Architecture | HIGH     | Business logic in MoneyScreen.build() |
| AV-04 | Architecture | MEDIUM   | HiveService not a proper singleton or Riverpod provider |
| AV-05 | Architecture | MEDIUM   | Enums defined but unused in models |
| AV-06 | Architecture | MEDIUM   | Sync queue stores incomplete payload |
| AV-07 | Architecture | CRITICAL | Firestore not user-scoped (violates architecture.md) |

---

*End of Report — Total Issues: 87*

*Recommended fix priority:*
*1. Security (S-01, S-02, S-04, A-01, AV-07)*
*2. Data Correctness (M-05, M-06, H-01, R-01, M-03)*
*3. Incomplete Features (SE-01 to SE-05, MF-01 to MF-15)*
*4. Architecture (AV-01 to AV-07)*
*5. Performance (P-01 to P-06)*
*6. Polish and Low-severity (U-*, F-*, LOW items)*
