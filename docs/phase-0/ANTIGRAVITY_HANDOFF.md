# Antigravity handoff

## Verified state

`C:\dev\ARC-Kotlin` contains a minimal Compose application using AGP 9.4.1, Gradle 9.8.1, Kotlin 2.4.21 Compose compiler, compile SDK 37, target SDK 36, min SDK 23, and JDK 17 bytecode. Production namespace is preserved; debug installs as `com.arc.arc.native.dev`. There are no ARC features, Firebase credentials, dangerous permissions, or production signing settings in the scaffold.

The Flutter source is `C:\dev\ARC` at commit `54e53cc` and must remain read-only. It has pre-existing uncommitted Secret Notes work. Read the feature, storage, Firebase, security, and dependency documents before coding.

## Core compatibility contracts

- Firebase UID is the owner key.
- Firestore paths and record IDs must remain stable.
- Hive boxes/type IDs/field order are migration inputs, not schemas to casually reinterpret.
- Secret Notes remain local-only and require a dedicated secure migration.
- SMS finance ingestion is policy-gated.
- Production upgrades require the same application ID and signing identity; development uses the suffix.

## Exact next steps

1. Confirm the build/test/lint commands in `PHASE_0_REPORT.md` still pass.
2. Create Phase 1 tests for Task/Habit/HabitEntry/Transaction serialization using fixtures derived from Dart models.
3. Introduce Room and DataStore behind interfaces, with exported schemas and migration tests.
4. Implement auth/session navigation against a Firebase development configuration after console verification.
5. Port design tokens and the authenticated shell, then Tasks as the first vertical slice.
6. Establish Macrobenchmark/baseline-profile infrastructure before broad feature porting.

Performance gates and user dependencies are in `PERFORMANCE_BASELINE.md` and `USER_ACTIONS_REQUIRED.md`. Do not repeat Phase 0 discovery unless the source commit or environment changes.
