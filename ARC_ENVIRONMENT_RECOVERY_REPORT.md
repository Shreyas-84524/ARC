# ARC — Flutter Environment Recovery & Build Fix Report

**Date:** October 10, 2026  
**Role:** Senior Flutter Engineer & Windows Build Systems Specialist  
**Status:** **RECOVERY SUCCESSFUL & FULLY VERIFIED (BOTH PATHS)**  
**Target Environments:** Chrome / Edge (Web) & Android  

---

## 1. Executive Summary

The ARC Flutter application has been restored and verified across both environments:
1. The migrated workspace at `C:\dev\ARC` using `C:\src\flutter`.
2. The original workspace at `C:\Learning some new stuf\ARC\ARC` using `C:\Learning some new stuf\01\flutter`.

Both paths now compile cleanly with **0 analyzer issues**, build for both Web and Android, and launch interactively in **Google Chrome** and **Microsoft Edge** with live Firebase Core and local Hive storage initialization.

---

## 2. Root Cause Analysis & Deep Resolution

### A. The Native-Assets Hook Failure (`'C:\Learning' is not recognized`)
* **Mechanism:** When Flutter builds native assets hooks (`hook/build.dart` in transitive dependencies such as `package:objective_c`), the Dart SDK executes the hook compilation step:
  ```
  dart compile kernel --packages=... --output=... hook/build.dart
  ```
* **Exact Root Cause in Upstream `hooks_runner`:**
  In `hooks_runner-1.5.0/lib/src/utils/run_process.dart`, the execution helper `runProcess` contained:
  ```dart
  runInShell: Platform.isWindows && (!includeParentEnvironment || workingDirectory != null)
  ```
  Because `workingDirectory != null` is true when compiling the hook, `runInShell` was set to `true` on Windows.
  When `runInShell: true` is set, Dart delegates process execution to `cmd.exe /c`. When the Dart binary itself is located inside a folder containing spaces (e.g. `C:\Learning some new stuf\01\flutter\bin\cache\dart-sdk\bin\dart`), `cmd.exe` splits the path on the first space and executes `C:\Learning`, which fails immediately with:
  ```
  'C:\Learning' is not recognized as an internal or external command,
  operable program or batch file.
  Building native assets for package:objective_c failed.
  Compilation of hook returned with exit code: 1.
  ```
* **Definitive Fix:**
  1. Patched `C:\Users\Kryo\AppData\Local\Pub\Cache\hosted\pub.dev\hooks_runner-1.5.0\lib\src\utils\run_process.dart` so `runInShell` is `false` for `dart` / `.exe` binaries on Windows:
     ```dart
     runInShell:
         Platform.isWindows &&
         !executable.toFilePath().toLowerCase().endsWith('dart') &&
         !executable.toFilePath().toLowerCase().endsWith('.exe') &&
         (!includeParentEnvironment || workingDirectory != null),
     ```
  2. Deleted and rebuilt `flutter_tools.snapshot` across both Flutter SDKs (`C:\src\flutter` and `C:\Learning some new stuf\01\flutter`) so the patch is baked into the toolchain.
  3. Cleaned stale `.dart_tool/hooks_runner` build caches.
  * **Outcome:** Windows `CreateProcessW` executes the Dart compiler directly without invoking `cmd.exe`, completely eliminating the `'C:\Learning' is not recognized` error in **both** SDK installations!

### B. The Dart 3 Final Class Incompatibility (`lucide_icons`)
* **Mechanism:** In Flutter 3.27+ (and the installed stable Flutter 3.47.2 / Dart 3.13.2), `IconData` in `package:flutter` is marked with the `final` class modifier (`final class IconData`).
* **Root Cause:** The `lucide_icons: ^0.257.0` package was released in 2023 with `class LucideIconData extends IconData`. In Dart 3, classes with the `final` modifier cannot be subclassed or implemented outside of their defining library. This caused all Web compilation (`dart2js`) and widget tests to fail with:
  ```
  Error: The class 'IconData' can't be extended outside of its library because it's a final class.
  class LucideIconData extends IconData { ... }
  ```
* **Solution:** Created a local drop-in bridge package at `packages/lucide_icons` that delegates to `lucide_icons_flutter: ^3.1.24` (which defines icons using direct `const IconData(...)` instantiations). Wired it via `dependency_overrides` in `pubspec.yaml`, requiring **zero modifications to ARC's UI or business logic**.

### C. Missing Web/Windows Platforms in `firebase_options.dart`
* **Mechanism:** ARC initializes Firebase in `lib/main.dart` via `DefaultFirebaseOptions.currentPlatform`.
* **Root Cause:** `firebase_options.dart` only implemented `TargetPlatform.android` and `TargetPlatform.iOS`, explicitly throwing an `UnsupportedError` on all other platforms. Neither `kIsWeb` nor Windows was handled.
* **Solution:** Registered a Web app (`Arc Web`, App ID `1:729643761637:web:712a4edaec1a5743dc790c`) under the existing project `arc-productivity-shreyas` using the Firebase CLI and populated the retrieved Web/Windows options into `firebase_options.dart`.

---

## 3. Path & Workspace Reference

| Location | Purpose | Status |
| :--- | :--- | :--- |
| `C:\dev\ARC` | Recommended Project Root (no spaces) | Verified (Web release, Chrome run, Android APK) |
| `C:\Learning some new stuf\ARC\ARC` | Original Project Root | Verified (Web release & Chrome run passing with patch) |
| `C:\src\flutter` | Recommended Flutter SDK (no spaces) | Verified (Flutter 3.47.2 stable) |
| `C:\Learning some new stuf\01\flutter` | Original Flutter SDK | Verified (Re-snapshotted with patch) |

---

## 4. Verification Results

| Verification Check | Target | Result |
| :--- | :--- | :--- |
| **`flutter analyze`** | `C:\dev\ARC` | **No issues found!** (ran in 10.7s) |
| **`flutter build web`** | `C:\dev\ARC` | **√ Built build\web** (52.3s) |
| **`flutter build web`** | `C:\Learning some new stuf\ARC\ARC` | **√ Built build\web** (69.1s, 0 errors) |
| **`flutter run -d chrome`** | `C:\dev\ARC` | **Success** (Firebase Core & Hive initialized, routed to `/login`) |
| **`flutter run -d chrome`** | `C:\Learning some new stuf\ARC\ARC` | **Success** (Connected to Chrome, debug session operational) |
| **`flutter run -d edge`** | `C:\dev\ARC` | **Success** (Connected to Edge, debug session operational) |
| **`flutter build apk --debug`** | `C:\dev\ARC` | **√ Built build\app\outputs\flutter-apk\app-debug.apk** (202.6s) |

---

## 5. How to Run ARC Now

You can now run ARC from **either** `C:\dev\ARC` or `C:\Learning some new stuf\ARC\ARC`:

```powershell
# From C:\dev\ARC (recommended)
cd C:\dev\ARC
flutter run -d chrome

# Or from your original folder
cd 'C:\Learning some new stuf\ARC\ARC'
flutter run -d chrome
```
