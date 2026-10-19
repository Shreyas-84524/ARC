# ARC Vault Auto-Lock & Privacy Safeguards

## 1. Screen Protection (`FLAG_SECURE`)

- **Attack Vector:** Recent Apps overview screenshots, user screenshots, screen recordings, and malicious screen-snooping apps.
- **Implementation:** `VaultWindowSecurity.kt` and `SecureVaultEffect`:
  - When a user enters `VaultRoute`, `activity.window.addFlags(FLAG_SECURE)` is immediately engaged.
  - Android OS disables screenshots, screen recording, and blacks out the app snapshot in the task switcher overview.
  - When navigating away from Vault, `onDispose` cleanly clears the flag so the rest of the application remains normal.

---

## 2. Background Auto-Lock (`VaultLifecycleManager`)

- **Observer:** `VaultLifecycleManager` attaches to the activity `Lifecycle`.
- **Policies:**
  - `IMMEDIATE`: Locks the vault as soon as the app transitions to `ON_STOP` (app backgrounded).
  - `THIRTY_SECONDS`: Enforces a 30-second grace period for quick app switching, automatically locking if the background duration exceeds 30 seconds.
- **Session Termination:** User sign-out or account switch calls `onUserSessionTerminated()`, instantly locking the vault and purging the DEK.

---

## 3. Clipboard Protection (`VaultClipboardHelper`)

- On Android 13+ (API 33+), copying sensitive note text sets `ClipDescription.EXTRA_IS_SENSITIVE = true`.
- This informs the Android System UI not to display a preview popup of the copied secret on screen, preventing shoulder-surfing and screen recording leaks.
