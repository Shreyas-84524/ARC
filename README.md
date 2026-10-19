# ARC Kotlin

ARC is now a native Android application built with Kotlin, Jetpack Compose, Room, DataStore, WorkManager, Firebase Authentication, and Cloud Firestore synchronization. This workspace was migrated from the legacy Flutter repository while preserving that repository's complete history and local state in `C:\dev\ARC-Backup`.

The imported native source is traceable to `C:\dev\ARC-Kotlin` commit `e9082ed05485a69110b22b9fe2af70f8eec578e7`. That source checkout remains an unchanged, read-only provenance reference.

## Safety boundaries

- The active native workspace is `C:\dev\ARC`.
- The recoverable legacy Flutter snapshot is `C:\dev\ARC-Backup`; treat it as read-only.
- The original Kotlin source checkout is `C:\dev\ARC-Kotlin`; treat it as read-only.
- Debug builds use application ID `com.arc.arc.native.dev`, so they do not replace the production application or share its production data.
- Secret Notes remain local-only and are excluded from Firestore, global search, and notifications.

## Stack

- Android Gradle Plugin 9.4.1 with built-in Kotlin support; Gradle 9.8.1
- Kotlin 2.4.21 and Java 17 bytecode
- Jetpack Compose with Material 3
- Room schema v4 and DataStore Preferences
- Firebase Authentication and offline-first Cloud Firestore synchronization
- WorkManager-based background work using policy-safe inexact scheduling

The production namespace is `com.arc.arc` (`versionCode = 2`, `versionName = "1.4.0-native"`). Minimum SDK is 23; compile and target SDK are 34.

## Build and verification

Configure Android SDK 34 in the ignored `local.properties`, then run from `C:\dev\ARC`:

```powershell
.\gradlew.bat :app:assembleDebug
.\gradlew.bat :app:testDebugUnitTest
.\gradlew.bat :app:lintDebug
```

Release packaging gates are:

```powershell
.\gradlew.bat :app:assembleRelease
.\gradlew.bat :app:bundleRelease
```

## Architecture

Application sources are under `app/src/main/java/com/arc/arc/`:

- `core/auth/`: Firebase and development authentication boundaries
- `core/database/`: Room database, Java entities and DAOs, Kotlin data sources and mappers
- `core/datastore/`: app and vault preferences
- `core/designsystem/`: Compose tokens and reusable components
- `core/model/`: domain models and contract utilities
- `core/security/`: vault cryptography, PIN, biometric, Keystore, clipboard, lifecycle, and window security
- `core/sync/`: Firestore synchronization and WorkManager worker
- `features/`: authentication, dashboard, tasks, habits, money, search, settings, and vault modules
- `navigation/`: native navigation graph and application shell

Room schema history is stored in `app/schemas/`. Unit and contract tests are in `app/src/test/`.

## Documentation

- Phase 0–6 implementation records: `docs/phase-0/` through `docs/phase-6/`
- Migration manifest: `docs/migration/MIGRATION_MANIFEST.md`
- Final workspace migration report: `docs/migration/WORKSPACE_MIGRATION_REPORT.md`

Do not push this migration branch to the legacy Flutter remote until the canonical repository strategy has been reviewed and explicitly approved.
