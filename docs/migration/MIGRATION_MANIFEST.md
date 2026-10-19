# ARC Flutter-to-Kotlin Migration Manifest

## Snapshot identity

Migration date: 2026-10-20 (Asia/Calcutta)

| Role | Path | Branch | HEAD | Remote |
|---|---|---|---|---|
| Destination / legacy Flutter history | `C:\dev\ARC` | `main` at start | `54e53ccf09f3f48d0b13a2f12fe5e347d33677d7` | `https://github.com/Shreyas-84524/ARC.git` |
| Native Kotlin source (read-only) | `C:\dev\ARC-Kotlin` | `codex/frontend-redesign` | `e9082ed05485a69110b22b9fe2af70f8eec578e7` | `https://github.com/Shreyas-84524/ARC-Kotlin.git` |
| Verified Flutter backup | `C:\dev\ARC-Backup` | `main` | `54e53ccf09f3f48d0b13a2f12fe5e347d33677d7` | `https://github.com/Shreyas-84524/ARC.git` |

The destination keeps the original ARC Git object database and history. The Kotlin repository's `.git` directory is never imported. The Kotlin source repository remains an independent, read-only provenance source.

## Preflight inventory

- C: free space before backup: 143,717,347,328 bytes (133.85 GiB).
- Flutter workspace: 51,557 regular files, 7,883,552,916 bytes (7.342 GiB), 5,974 tracked paths, one non-ignored untracked path.
- Kotlin workspace: 39,853 regular files including generated/ignored outputs, 4,473,198,360 bytes (4.166 GiB), 275 tracked paths, zero non-ignored untracked paths.
- Reparse points in either source tree: zero.
- Tracked relative-path collisions: `.gitignore` only; the Kotlin version is imported with the native build foundation.
- Latest intended Kotlin state includes Phase 6 and frontend redesign commit `e9082ed`.
- Existing Kotlin build evidence at that commit: debug APK, release APK, release AAB, Android lint report, and 209 passing tests across 39 suites.

## Original Flutter working state preserved

The backup contains the original uncommitted state exactly, including modifications to:

- `Brain.md`
- Secret Notes settings, setup, unlock, biometric, security, and PIN-field sources under `lib/features/secret_notes/`
- Secret Notes Phase 4, biometric, security, UI/flow tests under `test/`
- Untracked `test/secret_notes_auth_ux_test.dart`

Ignored local/generated content was copied, including `.dart_tool`, Flutter plugin metadata, Android local/Gradle files, platform-generated files, `build`, and dependency directories. No cache or temporary file was excluded from the backup snapshot.

## Backup verification

The copy used a non-destructive recursive operation with junction traversal disabled and without mirror, move, or delete options.

- Copy result: 51,557 files copied; zero failures; zero copy-engine mismatches.
- Independent comparison: 51,557 source and backup files matched by relative path, byte length, and SHA-256.
- SHA-256 digest of the sorted per-file manifest: `7F6C2BCAF8F28375B047A9A20D8E36405E28F3413051193CE789741489001BD7`.
- Source and backup Git HEAD, branch, remotes, and 12-entry porcelain working state are identical.
- Required Flutter directories and files (`lib`, platform directories, `assets`, `test`, `pubspec.yaml`, `pubspec.lock`, and `.git`) are present.
- `git fsck --full` completed successfully. Existing unreachable objects were retained as part of the exact Git metadata snapshot.

## Source-to-destination plan

| Kotlin source | Destination | Import stage |
|---|---|---|
| Root Gradle wrapper/configuration | Repository root | Commit 4 |
| `app/build.gradle.kts`, manifest, base resources | `app/` | Commit 4 |
| `core/model`, `core/database`, `core/datastore`, `core/di`, migrations, sync foundations | Same native paths | Commit 5 |
| Dashboard, Tasks, Habits and shared UI | Same native paths | Commit 6 |
| Money module and financial utilities/models | Same native paths | Commit 7 |
| Vault UI/data and security services | Same native paths | Commit 8 |
| Authentication, Settings, Search, Notifications, Navigation, remaining resources/tests/docs | Same native paths | Commit 9 |
| Reconciled README, AGENTS instructions, final report and verification evidence | Repository root/docs | Commit 10 |

Only source-controlled Kotlin files are imported into Git. Ignored Gradle/build/IDE output is excluded. `local.properties` may be copied locally to make the destination buildable but remains ignored and uncommitted.

## Rollback and recovery

1. Do not delete `C:\dev\ARC-Backup`.
2. The complete Flutter repository can be opened directly from the backup; its branch, object database, ignored files, and uncommitted work are intact.
3. Before this migration branch is merged or pushed, returning to `main` restores the committed Flutter tree. The uncommitted Flutter work remains recoverable from the backup.
4. The independent Kotlin source remains available at `C:\dev\ARC-Kotlin` at commit `e9082ed`.
5. No remote is changed or pushed by this migration.

## Commit contract

The branch `migration/flutter-to-kotlin` will contain exactly ten meaningful commits, in the order prescribed by the migration request. Each removal is performed only after confirming its backup counterpart. Each Kotlin import is copied from the recorded source commit and staged by logical subsystem.
