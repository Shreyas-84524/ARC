# Phase 2 Handoff Specification

## 1. Handoff Summary

Phase 1 has established ARC-Kotlin's production-grade native foundation:
- **Branch:** `phase-1` (branched from `main` @ `1ac7e2b`)
- **Remote:** `https://github.com/Shreyas-84524/ARC-Kotlin.git`
- **Build Status:** Verified (100% clean compilation, 30 unit tests passing, lint 0 errors, debug APK built)
- **Active Codebase:** `C:\dev\ARC-Kotlin`
- **Read-Only Legacy Reference:** `C:\dev\ARC` (strictly unmodified)

---

## 2. Established Architecture & Patterns for Phase 2

Engineers continuing into Phase 2 should adhere to the established architectural conventions:

### 2.1 Toolchain Conventions
- **AGP 9.4.1 Built-in Kotlin Support:** Do not apply the legacy `kotlin-android` Gradle plugin.
- **Room Database Entities:** Authored in Java (`ArcDatabase.java`, `TaskDao.java`, `TaskEntity.java`) to work seamlessly with `annotationProcessor(libs.androidx.room.compiler)` under AGP built-in Kotlin support. Kotlin extension mappers (`TaskMappers.kt`) bridge entity to domain models.
- **Compose Material 3:** Built using Compose BOM 2026.09.00 and Kotlin 2.4.21. Always use non-deprecated APIs (e.g., `ExposedDropdownMenuAnchorType.PrimaryNotEditable`).
- **ViewModel Lifecycle:** Always define a companion `ViewModelProvider.Factory` on ViewModels and instantiate in composables via `viewModel(factory = ...)`.

### 2.2 Design System Tokens
Always reuse tokens from `com.arc.arc.core.designsystem.theme.ArcTheme`:
- Colors: `ArcTheme.colors.background`, `surface`, `accent`, `textPrimary`, `textSecondary`, `borderSubtle`.
- Dimensions: `ArcDimens.SpacingSm`, `SpacingMd`, `SpacingLg`, `RadiusCard`, `RadiusInput`, `RadiusButton`.
- Typography: `ArcTypography.headlineLarge`, `titleMedium`, `bodyMedium`, `labelSmall`.
- Reusable Components: `ArcButton`, `ArcCard`, `ArcDialog`, `ArcLoadingState`, `ArcEmptyState`, `ArcErrorState`, `ArcPriorityBadge`.

---

## 3. Phase 2 Scope & Objectives

### Objective A: Habits Vertical Slice
1. **Room Persistence:**
   - Define `HabitEntity.java` and `HabitEntryEntity.java` in `core.database`.
   - Update `ArcDatabase.java` version to 2 and add migrations.
   - Note composite key requirement for HabitEntry: `${habitId}_${dateStr}`.
2. **Habit Repository:**
   - Implement `IHabitRepository` with Flow observation and streak calculation algorithms.
3. **Habit UI:**
   - Replace `HabitsPlaceholderScreen.kt` with full `HabitsScreen.kt`.
   - Habit card with weekly progress grid, completion toggle, streak badges, and habit creation bottom sheet.

### Objective B: Daily Dashboard
1. **Dashboard ViewModel:**
   - Combine state flows from `ITaskRepository`, `IHabitRepository`, and `AppPreferencesDataStore`.
2. **Dashboard UI:**
   - Replace `DashboardPlaceholderScreen.kt` with full `DashboardScreen.kt`.
   - Greeting, daily progress ring, urgent tasks section, today's habits checklist, and motivational quote banner.

### Objective C: Firebase Auth & Cloud Sync
1. Configure `google-services.json` for `com.arc.arc.native.dev`.
2. Implement `FirebaseAuthRepository` and WorkManager sync worker.
