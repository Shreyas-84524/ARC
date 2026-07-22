# Project Arc — Phase 1 Stabilization Report

> **Phase Name:** Phase 1 — Foundation Repair & Android Startup Stabilization  
> **Status:** COMPLETED SUCCESSFULLY  
> **Date:** 2026-07-22  
> **Scope:** Android Build System, Flutter Startup, GoRouter Navigation, Hive Box Retrieval, Notification Service, Riverpod Dashboard Null Safety, Verification & APK Builds.

---

## 1. Root Causes Found

### Primary Root Cause of Blank Screen on App Startup
- **Generic Type-Mismatch Exception in Hive Box Access**: In `task_repository.dart`, `habit_repository.dart`, and `money_repository.dart`, `HiveService().getBox(...) as Box<T>` was executed. `HiveService.getBox` returned `Box<dynamic>`. In strong-mode Dart 3, casting `BoxImpl<dynamic> as Box<Task>` (or `Box<Habit>`, `Box<Transaction>`) throws a runtime `TypeError`. Because these repositories were constructed synchronously inside Riverpod `StateNotifierProvider` initializers, the `TypeError` was thrown immediately when the widget tree loaded `dashboardProvider`. Flutter caught the exception during initial frame rendering, preventing the UI from building and resulting in a blank/empty screen.
- **Unsafe GoRouter Location Retrieval in `ShellScreen`**: `ShellScreen` attempted to inspect `GoRouter.of(context).routeInformationProvider.value.uri.path` on `build()`. On initial application launch, `routeInformationProvider` can be empty or uninitialized, causing navigation frame evaluation failures.

### Android Build & Runtime Deficiencies
- **Missing `exported="true"` on `ScheduledNotificationBootReceiver`**: In `AndroidManifest.xml`, `ScheduledNotificationBootReceiver` had `<intent-filter>` declarations for `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, and `QUICKBOOT_POWERON`, but was marked `android:exported="false"`. On Android 12+ (API 31+), any component declaring intent-filters MUST specify `android:exported="true"`, or Android package installation/runtime boot intent delivery fails.
- **Redundant/Conflicting Alarm Permissions**: `USE_EXACT_ALARM` was declared alongside `SCHEDULE_EXACT_ALARM`. `USE_EXACT_ALARM` is restricted to alarm clock/timer apps on Google Play policy.
- **Outdated Desugaring Library**: `desugar_jdk_libs:2.0.4` was used; updated to `2.1.2`.
- **Notification Initialization Icon Mismatch**: `NotificationService` initialized with `@mipmap/ic_launcher` while `AndroidManifest.xml` registered `@mipmap/launcher_icon`.

---

## 2. Files Modified

1. [android/app/src/main/AndroidManifest.xml](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/android/app/src/main/AndroidManifest.xml)
2. [android/app/build.gradle.kts](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/android/app/build.gradle.kts)
3. [lib/core/services/hive_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/services/hive_service.dart)
4. [lib/features/task_manager/repository/task_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/task_manager/repository/task_repository.dart)
5. [lib/features/habit_tracker/repository/habit_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/habit_tracker/repository/habit_repository.dart)
6. [lib/features/money_tracker/repository/money_repository.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/money_tracker/repository/money_repository.dart)
7. [lib/routes/app_router.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/routes/app_router.dart)
8. [lib/features/dashboard/screens/shell_screen.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/dashboard/screens/shell_screen.dart)
9. [lib/providers/global_providers.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/providers/global_providers.dart)
10. [lib/features/dashboard/screens/dashboard_screen.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/features/dashboard/screens/dashboard_screen.dart)
11. [lib/core/notifications/notification_service.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/core/notifications/notification_service.dart)
12. [lib/main.dart](file:///c:/Learning%20some%20new%20stuff/App%20Development/arc/lib/main.dart)

---

## 3. Fixes Applied

### Android Build System
- Updated `ScheduledNotificationBootReceiver` in `AndroidManifest.xml` to `android:exported="true"`.
- Removed `android.permission.USE_EXACT_ALARM`, keeping `SCHEDULE_EXACT_ALARM`.
- Capitalized `android:label="Arc"`.
- Updated `coreLibraryDesugaring` in `android/app/build.gradle.kts` to `"com.android.tools:desugar_jdk_libs:2.1.2"`.

### Hive & Data Retrieval
- Refactored `HiveService.getBox<T>(String boxName)` to be a generic typed method `Box<T> getBox<T>(String boxName)`. Added `Hive.isBoxOpen(boxName)` check before box access.
- Added adapter check `if (!Hive.isAdapterRegistered(id))` guards in `HiveService.init()` to prevent double-registration exceptions.
- Updated `TaskRepository`, `HabitRepository`, and `MoneyRepository` to call `HiveService().getBox<T>(...)`, completely removing all runtime type casts.

### Navigation & Shell
- Added `errorBuilder` to `GoRouter` in `app_router.dart` for graceful fallback handling of invalid route paths.
- Updated `ShellRoute` builder to pass `state.uri.path` directly into `ShellScreen(location: state.uri.path, child: child)`.
- Updated `ShellScreen` to use the passed `location` or fallback to `GoRouterState.of(context).uri.path`, eliminating internal API calls.

### Riverpod & Dashboard Stability
- Updated `dashboardProvider` and `DashboardScreen.build()` property extraction to use null-safe coalescing casts (`as int? ?? 0`, `as double? ?? 0.0`), guaranteeing that missing or unexpected map values never crash the dashboard.

### App Startup & Notifications
- Wrapped `main()` in `runZonedGuarded` with `FlutterError.onError` handler set to catch framework-level startup errors.
- Added individual `try/catch` blocks around `Firebase.initializeApp`, `HiveService().init()`, and `NotificationService().init()` so that an offline or missing service warning does not crash cold start.
- Updated `NotificationService` initialization to point to `@mipmap/launcher_icon`.

---

## 4. Verification Results

| Step | Command | Result |
|------|---------|--------|
| Clean Workspace | `flutter clean` | **PASSED** (Build cache cleared) |
| Dependency Resolution | `flutter pub get` | **PASSED** (Dependencies resolved cleanly) |
| Static Code Analysis | `dart analyze` | **PASSED** (0 issues / warnings found) |
| Automated Tests | `flutter test` | **PASSED** (All widget tests passed) |
| Debug APK Build | `flutter build apk --debug` | **PASSED** (`build/app/outputs/flutter-apk/app-debug.apk`) |
| Release APK Build | `flutter build apk --release` | **PASSED** (`build/app/outputs/flutter-apk/app-release.apk`) |

---

## 5. Build & APK Status

- **Debug Build Status**: SUCCESSFUL
- **Debug APK Location**: `build/app/outputs/flutter-apk/app-debug.apk`
- **Release Build Status**: SUCCESSFUL
- **Release APK Location**: `build/app/outputs/flutter-apk/app-release.apk`
- **Startup Verification**: Verified — app launches directly into the Dashboard screen without blank screen or runtime exceptions.

---

## 6. Remaining Issues (For Next Phases)

None within Phase 1 scope. Foundation is fully stabilized. Ready for Phase 2 (Data Layer Stabilization).
