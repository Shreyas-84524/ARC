# Remaining Integrations Beyond Phase 3

## 1. Overview

With Phase 3 complete, ARC-Kotlin now features:
- Core Architecture & Foundation (Phase 0)
- Development Auth & Offline-First Tasks (Phase 1)
- Productivity Dashboard & Habit Tracker (Phase 2)
- Money Manager, Financial Intelligence & Expense Detection (Phase 3)

The following modules and capabilities remain scheduled for future migration phases:

---

## 2. Scheduled Future Modules

### 2.1 Phase 4: Secret Notes, Vault & Advanced Security
- **Flutter Reference:** `C:\dev\ARC/lib/features/secret_notes/`, `C:\dev\ARC/lib/features/vault/`.
- **Target Deliverables:**
  - AES-256-GCM / SQLCipher encrypted storage for sensitive user notes.
  - AndroidX BiometricPrompt integration (fingerprint / face unlock).
  - PIN / Master Password protection with PBKDF2 / Argon2 key derivation.
  - Secret note categories, search, auto-lock on app backgrounding, and secure clipboard zeroing.

### 2.2 Phase 5: Production Firebase Authentication & Cloud Sync
- **Target Deliverables:**
  - Transition from `DevFakeAuthRepository` to official `FirebaseAuth` with Google Sign-In and Email/Password.
  - Firestore two-way offline synchronization for Tasks, Habits, Money, and Settings.
  - Conflict resolution policies (last-write-wins with server timestamp verification).
  - Cloud Functions integration and FCM push notifications.

### 2.3 Phase 6: Release Engineering & Production Hardening
- **Target Deliverables:**
  - ProGuard / R8 code shrinking and resource optimization.
  - Release signing keystore configuration and CI/CD workflow setup.
  - Crashlytics and performance monitoring integration.
  - Final Play Store compliance audit and release packaging.
