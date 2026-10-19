# ARC-Kotlin — Phase 5 Handoff: Settings, Global Search, Notifications & Final System Polish

## 1. Baseline State

- **Completed Branches:** `phase-1`, `phase-2`, `phase-3`, `phase-4`
- **Active Baseline Commit:** `phase-4` (latest verified commit)
- **Room Database Schema:** Version 4 (`1.json`, `2.json`, `3.json`, `4.json` verified)
- **Build Status:** All unit tests pass; `./gradlew assembleDebug` passes cleanly.

---

## 2. Phase 5 Objectives

1. **Settings & Customization:**
   - Migrate Settings module from Flutter (`lib/features/settings/`).
   - Theme management, reminder defaults, notification toggles, DataStore backup/export options.
2. **Global Search:**
   - Unified search indexing across Tasks, Habits, and Financial Transactions.
   - Respecting vault privacy boundaries (Secret Notes excluded from global system searches).
3. **Notification Engine & Reminders:**
   - Native `WorkManager` and `AlarmManager` for scheduled habit and task reminders.
   - Android 13+ `POST_NOTIFICATIONS` runtime permission handling.
4. **Final System Hardening & Release Packaging:**
   - ProGuard / R8 minification rules.
   - Release signing preparation.
   - Complete migration verification vs. original Flutter app (`C:\dev\ARC`).

---

## 3. Strict Development Rules

1. Treat `C:\dev\ARC` as strictly READ-ONLY.
2. Branch `phase-5` directly from verified `phase-4`.
3. Never use destructive database migrations.
4. Keep user data isolated by authenticated `uid`.
