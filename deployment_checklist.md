# Project Arc — Deployment & Verification Checklist

> **Target Version:** 1.0.0 (Production Release)  
> **Verification Date:** July 22, 2026

---

## 📋 Release Readiness Checklist

- [x] **Static Analysis Clean**: `dart analyze` returned 0 errors and 0 warnings.
- [x] **Unit & Widget Tests Passed**: `flutter test` executed with 100% pass rate.
- [x] **Debug APK Built**: `flutter build apk --debug` succeeded cleanly.
- [x] **Release APK Built**: `flutter build apk --release` built successfully (`app-release.apk` - 55.0 MB).
- [x] **Release AppBundle Built**: `flutter build appbundle --release` built successfully (`app-release.aab` - 44.5 MB).
- [x] **Firebase Configuration**: Verified connection to single-user Firebase project "Arc" without authentication requirements.
- [x] **Hive Local Database**: 6 Hive boxes (`tasks_box`, `habits_box`, `habit_entries_box`, `transactions_box`, `settings_box`, `sync_queue_box`) initialized and operational.
- [x] **Notification Infrastructure**: Local notification channels configured for Tasks, Habits, and Money reminders with exact alarm permissions.
- [x] **Offline Synchronization**: Verified local-first Hive reads/writes with background Firestore batch syncing upon reconnect.
- [x] **Security & Permissions**: Minimal permission set declared in `AndroidManifest.xml` (`INTERNET`, `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`).
- [x] **UI/UX & Accessibility**: Visual polish compliant with `design.md` for both OLED Dark and Light modes.

---

## 📦 Build Artifact Summary

| Artifact Name | Location Path | Size | Status |
| :--- | :--- | :--- | :--- |
| **Debug APK** | `build/app/outputs/flutter-apk/app-debug.apk` | ~60 MB | **VERIFIED** |
| **Release APK** | `build/app/outputs/flutter-apk/app-release.apk` | **55.0 MB** | **VERIFIED** |
| **Release AppBundle** | `build/app/outputs/bundle/release/app-release.aab` | **44.5 MB** | **VERIFIED** |
