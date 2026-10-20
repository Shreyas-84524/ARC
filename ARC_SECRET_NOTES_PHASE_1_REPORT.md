# ARC — Secret Notes Phase 1 Report: Secure Entry & Local-Only Foundation

**Date:** October 13, 2026  
**Status:** Completed & Verified  
**Scope:** Phase 1 Only (Secure Entry Flow, Local-Only Architecture, PIN Protection, First-Use Onboarding)

---

## 1. Executive Summary

Phase 1 of Secret Notes establishes the secure entry gesture, cryptographically protected PIN authorization, in-memory session locking, first-use policy onboarding, and an isolated local-only persistence foundation. 

All operations, state, verifiers, and configurations are strictly offline and isolated from ARC's cloud synchronizer, Firestore, Firebase Auth, and task/habit/money stores.

---

## 2. Architecture Added

The feature module was designed with clean separation of concerns under `lib/features/secret_notes/`:

```
lib/features/secret_notes/
├── models/
│   └── secret_notes_security_state.dart   # Immutable security & lockout state model
├── repositories/
│   └── secret_notes_local_repository.dart # Isolated local storage manager for security & prefs
├── services/
│   ├── secret_notes_crypto.dart           # PBKDF2 HMAC-SHA256, constant-time compare, salt gen
│   └── secret_notes_security_service.dart # PIN validation, setup, verify, lockout math, intro checks
├── providers/
│   └── secret_notes_provider.dart         # Riverpod providers for repo, service, session, config
├── screens/
│   ├── secret_notes_setup_screen.dart     # 6-digit PIN creation & confirmation screen
│   ├── secret_notes_unlock_screen.dart    # PIN unlock screen with countdown lockout UI
│   └── secret_notes_dashboard_screen.dart # Phase 1 placeholder shell with intro dialog trigger
└── widgets/
    ├── secret_notes_pin_field.dart        # Reusable 6-digit numeric masked PIN input
    └── secret_notes_intro_dialog.dart     # First-use modal dialog with 5 privacy points
```

---

## 3. Dedicated Routes & Navigation Isolation

Three dedicated routes were added into [app_router.dart](file:///c:/dev/ARC/lib/routes/app_router.dart):

1. `/secret-notes/setup` — Opened when the user initiates entry and Secret Notes is not yet configured.
2. `/secret-notes/unlock` — Opened when Secret Notes is configured but locked in the current session.
3. `/secret-notes` — Phase 1 placeholder dashboard, accessible only when configured, authenticated in ARC, and unlocked in memory.

### Guard & Redirect Policies:
- **Main ARC Authentication Required:** Any unauthenticated attempt to navigate to `/secret-notes*` redirects to `/login`.
- **Not Configured Guard:** Navigating to `/secret-notes` or `/secret-notes/unlock` when unconfigured redirects to `/secret-notes/setup`.
- **Session Lock Guard:** Directly typing `/secret-notes` in browser/router without unlocking redirects to `/secret-notes/unlock`.
- **Direct Entry Guard:** Navigating to `/secret-notes/setup` or `/secret-notes/unlock` when already configured and unlocked redirects to `/secret-notes`.

---

## 4. Swipe Entry Implementation

- Integrated into [tasks_screen.dart](file:///c:/dev/ARC/lib/features/task_manager/screens/tasks_screen.dart) without altering ARC's navigation bar or modifying existing task interaction gestures.
- Uses horizontal drag tracking with a deliberate delta threshold (minimum 80 logical pixels left-to-right).
- Accidental small horizontal jitter (< 80px), right-to-left swipes, and vertical list scrolls do not trigger the gesture.
- Upon valid swipe, checks `secretNotesSecurityServiceProvider.isSecretNotesConfigured()` and routes cleanly to `/secret-notes/setup` or `/secret-notes/unlock`.

---

## 5. PIN Hashing & Cryptographic Strategy

- **Zero Plain-Text Storage:** Raw PINs are never stored, transmitted, cached, or logged.
- **Salt Generation:** 32 cryptographically secure pseudo-random bytes via `Random.secure()`.
- **Key Derivation:** RFC 2898 PBKDF2 HMAC-SHA256 with 10,000 iterations producing a 32-byte derived verifier key.
- **Timing Attack Resistance:** Verification uses constant-time byte comparison (`SecretNotesCrypto.constantTimeEquals`), preventing timing side-channel attacks.
- **PIN Requirements:** Exactly 6 numeric digits (`^[0-9]{6}$`). Rejects empty inputs, whitespace, letters, or mismatched confirmation.

---

## 6. Brute-Force & Attempt Protection Logic

- **Threshold:** Up to 5 failed PIN attempts are permitted.
- **Lockout Policy:** Upon the 5th consecutive failure, Secret Notes is locked for 30 seconds. Subsequent failure cycles increase the lockout duration incrementally.
- **Persistence:** Failed attempts and `lockedUntil` timestamp are persisted in the local security store, preventing lockout bypass via app restarts.
- **Reactive UI:** [SecretNotesUnlockScreen](file:///c:/dev/ARC/lib/features/secret_notes/screens/secret_notes_unlock_screen.dart) disables the input and Unlock button during lockout, streaming a live countdown timer until access is restored.
- **Scope Isolation:** Lockout strictly isolates Secret Notes. ARC account login, tasks, habits, and money features remain completely unaffected.

---

## 7. Session Lock State

- Controlled in-memory via `secretNotesSessionProvider` (`StateNotifier<bool>`).
- Initializes to `false` when the app process starts.
- Set to `true` upon successful PIN verification.
- Can be locked manually via the Lock button in the dashboard or upon app process termination.
- Never persisted across process restarts ("unlocked forever" is disallowed).

---

## 8. First-Use Policy Onboarding

Upon initial PIN creation and first entry to the dashboard, [SecretNotesIntroDialog](file:///c:/dev/ARC/lib/features/secret_notes/widgets/secret_notes_intro_dialog.dart) is displayed. It presents the 5 required privacy principles:

1. **Local only:** Notes are stored only on this device and never synced with Firebase or ARC cloud services.
2. **Separate PIN:** The Secret Notes PIN is completely separate from ARC account credentials or Google sign-in.
3. **Independent settings:** Secret Notes operates with its own independent preferences.
4. **Possible permanent loss:** Clearing app data or uninstalling ARC permanently removes these notes.
5. **Keep your PIN safe:** ARC never stores readable PINs; forgotten PINs cannot be recovered from any cloud service.

Acknowledgement is confirmed via the **"I Understand"** button and persisted in `secret_notes_preferences` (`secret_notes_intro_seen = true`). The dialog is presented only once per setup lifecycle.

---

## 9. Local-Only Privacy & Storage Isolation Guarantees

- **Dedicated Storage Namespaces:**
  - `secret_notes_security`: Stores salt, hash, iteration count, configuration state, and lockout metadata.
  - `secret_notes_preferences`: Stores local preferences such as `secret_notes_intro_seen`.
  - Future data (Phase 2) will utilize dedicated `secret_notes_data`.
- **Zero Cloud Exposure:**
  - No Firestore collections created or queried.
  - No entries queued in Hive sync boxes (`tasks_sync_queue_box`, `habits_sync_queue_box`, `money_sync_queue_box`).
  - No synchronization listeners or background sync triggers attached.
  - No coupling to Firebase UID or remote authentication tokens.
- **Privacy Logging Compliance:**
  - All debug logs emit sanitized lifecycle messages only (e.g., `Secret Notes: PIN setup completed successfully.`).
  - PIN inputs, salts, derived hashes, or verification payloads are never written to `debugPrint`, stdout, or analytics.

---

## 10. Quality Gate Verification

### A. Static Analysis
```bash
flutter analyze
```
**Result:** `No issues found!` (0 errors, 0 warnings, 0 lints)

### B. Automated Test Suite
```bash
flutter test
```
**Result:** **254 / 254 tests passed** (including all 32 dedicated Secret Notes unit and widget tests).

Key test groups:
- `test/secret_notes_security_test.dart` (16 tests): Cryptography, PBKDF2 derivation, salt generation, constant-time comparison, PIN validation, lockout persistence, and privacy rules.
- `test/secret_notes_ui_and_flow_test.dart` (16 tests): Setup screen, unlock screen, lockout timer, intro popup, placeholder dashboard, swipe gesture detection, horizontal threshold validation, and router navigation guards.
- Project-wide regression tests (222 tests): Auth, Task Manager, Habits, Money Tracker, User Isolation, and Sync queues all passing.

### C. Build Verification
- **Web Build:** `flutter build web --no-pub` completed successfully (`Built build\web` in 55.0s).
- **Android Compilation:** `flutter build apk --debug --no-pub` completed successfully (`Built build\app\outputs\flutter-apk\app-debug.apk` in 94.2s).

---

## 11. Files Created and Modified

### Created:
- `lib/features/secret_notes/models/secret_notes_security_state.dart`
- `lib/features/secret_notes/services/secret_notes_crypto.dart`
- `lib/features/secret_notes/repositories/secret_notes_local_repository.dart`
- `lib/features/secret_notes/services/secret_notes_security_service.dart`
- `lib/features/secret_notes/providers/secret_notes_provider.dart`
- `lib/features/secret_notes/widgets/secret_notes_pin_field.dart`
- `lib/features/secret_notes/widgets/secret_notes_intro_dialog.dart`
- `lib/features/secret_notes/screens/secret_notes_setup_screen.dart`
- `lib/features/secret_notes/screens/secret_notes_unlock_screen.dart`
- `lib/features/secret_notes/screens/secret_notes_dashboard_screen.dart`
- `test/secret_notes_security_test.dart`
- `test/secret_notes_ui_and_flow_test.dart`
- `ARC_SECRET_NOTES_PHASE_1_REPORT.md`

### Modified:
- `pubspec.yaml` (added `crypto: ^3.0.3`)
- `lib/core/services/hive_service.dart` (registered `secret_notes_security` and `secret_notes_preferences` local boxes)
- `lib/routes/app_router.dart` (added Secret Notes route definitions and redirection guards)
- `lib/features/task_manager/screens/tasks_screen.dart` (added left-to-right swipe gesture detector)
