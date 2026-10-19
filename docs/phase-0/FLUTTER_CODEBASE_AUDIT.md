# Flutter codebase audit

Status: **Completed (static/read-only)**.

The source is `C:\dev\ARC`, Flutter package `arc` version `1.3.5+1`, Git HEAD `54e53cc`. It contains 97 Dart files under `lib` and 52 Dart test files. The source was already dirty before Phase 0 (Secret Notes files/tests and `Brain.md`); no files were changed by this audit.

## Architecture

- Bootstrap: `lib/main.dart` initializes Firebase, Hive, time zones, local notifications, Riverpod, full sync, real-time listeners, and notification reconciliation.
- Navigation: `lib/routes/app_router.dart` uses GoRouter with auth/admin redirects and a Secret Notes setup/unlock/session gate.
- State: Riverpod providers are concentrated in `lib/providers/global_providers.dart` and feature providers.
- Data: feature repositories use Hive-first writes and pending queues, then Firestore synchronization through `lib/core/services/sync_service.dart` and `sync_manager.dart`.
- UI: feature-first screens/widgets with shared theme and controls under `lib/core`.
- Native Android: `MainActivity.kt` implements haptics and secure-window channels; `MoneyAutomationBridge.kt` and `MoneySmsReceiver.kt` implement the SMS event path.

## Notable quality findings

- The app catches and logs many initialization/sync failures, which improves availability but can make operational failure look successful.
- Legacy root Firestore collections coexist with user-scoped collections; migration code exists in `data_migration_service.dart`.
- Release Flutter builds are configured with the debug signing key in `android/app/build.gradle.kts`; this is not production-ready.
- The tracked Flutter repository contains both `firebase_options.dart` and `android/app/google-services.json`. These are client configuration, but still require project/access review before any reuse.
- No Cloud Functions source or Firebase Storage rules file was found in the repository inventory.
