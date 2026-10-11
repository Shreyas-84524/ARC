# ARC — Phase 1: Authentication Foundation & UI Report

**Date:** October 10, 2026  
**Role:** Senior Flutter Architect & UI/UX Engineer  
**Status:** **PHASE 1 COMPLETE & FULLY VERIFIED (100% Tests Passing, 0 Analyzer Warnings)**  
**Target Environments:** Android, Web (Chrome / Edge), iOS, Desktop  

---

## 1. Executive Summary

Phase 1 establishes a production-grade, secure, and responsive authentication system for the ARC productivity platform. Built on ARC’s foundational tech stack—**Flutter, Riverpod, go_router, Hive, and Firebase Authentication**—this phase delivers end-to-end user onboarding and session management without compromising the existing offline-first architecture or modifying unrelated feature domains.

All 12 requirements outlined in the Phase 1 specification were designed, implemented, and verified against ARC’s test suite. Static analysis (`flutter analyze`), unit and widget tests (`flutter test`), and web release compilation (`flutter build web`) have all passed cleanly.

---

## 2. Architecture & Security Audit Findings

Prior to making modifications, an audit of ARC’s existing infrastructure was performed:

1. **Firebase Core & Auth Configuration:**
   - Single initialization point in `lib/main.dart` via `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
   - `firebase_options.dart` targets project **`arc-productivity-shreyas`** across Android, iOS, Web, and Windows.
   - Prior authentication logic relied on a transitional username mapping (Option A) without public Sign Up or password reset capabilities.
2. **State Management & Routing:**
   - Riverpod `StateNotifierProvider` (`userContextProvider`) orchestrates `UserContext`, tracking `userId`, `profile`, and `isInitializing`.
   - `app_router.dart` uses `RouterNotifier` listening to `userContextProvider` with GoRouter redirection.
3. **Local Storage & Offline-First Boundary:**
   - `HiveService` manages user-scoped boxes (`tasks_box_<uid>`, `habits_box_<uid>`, `money_box_<uid>`, `settings_box_<uid>`) and pending sync queues.
   - All offline storage is cleanly scoped to the authenticated UID, preserving zero-latency launch.
4. **Credential Security Audit:**
   - Verified: **No passwords or credentials are ever written to Hive or Firestore.** Passwords are exclusively transmitted to Firebase Auth.

---

## 3. Firebase Console Configuration & Verification

* **Firebase Project:** `arc-productivity-shreyas`
* **App Registrations:**
  - Web: `1:729643761637:web:712a4edaec1a5743dc790c`
  - Android: `1:729643761637:android:39bc738c98a05bd4dc790c`
  - iOS: `1:729643761637:ios:1f1fa53c132914cbdc790c`
* **Required Firebase Console Action:**
  > [!IMPORTANT]
  > Ensure that **Email/Password** authentication provider is enabled in the Firebase Console:
  > 1. Open [Firebase Console](https://console.firebase.google.com/project/arc-productivity-shreyas/authentication/providers).
  > 2. Navigate to **Authentication** → **Sign-in method**.
  > 3. Verify that **Email/Password** is set to **Enabled**. (Do not enable Email link/passwordless).
  > 4. Google Sign-In is intentionally disabled for Phase 1.

---

## 4. UI/UX Implementation Details

All three screens strictly adhere to ARC's design tokens (`AppColors.darkBg`, `AppColors.lightBg`, `AppColors.darkCard`, `AppColors.lightCard`, `AppColors.accent`, `AppTheme.radiusCard`, `AppTheme.radiusButton`, `AppTheme.radiusInput`, `LucideIcons`):

### A. Login Screen (`lib/features/user_management/views/login_screen.dart`)
* **Responsive Card Layout:** Centered card with `maxWidth: 440`, responsive padding, subtle borders, and elevation.
* **Header:** ARC branding badge, serif title ("Welcome Back"), and concise subtitle.
* **Fields & Validations:**
  - **Email:** Full email format validation (supports legacy test username fallback).
  - **Password:** Minimum 6 characters, masked by default with Lucide eye/eyeOff toggle button.
* **Navigation Links:**
  - Right-aligned **"Forgot Password?"** link navigating directly to `/forgot-password`.
  - Bottom **"Don't have an account? Sign Up"** row navigating to `/signup`.
* **State & Errors:**
  - Accent-colored full-width primary button ("Sign In") with loading spinner.
  - Dedicated contextual error banner for `invalid-credential`, `user-not-found`, and network errors.

### B. Sign Up Screen (`lib/features/user_management/views/signup_screen.dart`)
* **Header:** Icon badge with `LucideIcons.userPlus`, serif title ("Create an Account").
* **Form Inputs & Validations:**
  - **Full Name:** Required, minimum 2 characters.
  - **Email:** Required, validated via regex (`^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$`).
  - **Password:** Required, minimum 6 characters, visibility toggle.
  - **Confirm Password:** Real-time mismatch validation, visibility toggle.
* **Submission Flow:**
  - Validates all fields atomically before submitting.
  - Registers account via `AuthRepository.signUpWithEmailAndPassword()`.
  - Sets Firebase Auth `displayName` to the user's Full Name.
  - Initializes user-scoped Hive boxes.
  - Automatically signs user in and transitions to Dashboard.
* **Navigation:** "Already have an account? Sign In" navigating to `/login`.

### C. Forgot Password Screen (`lib/features/user_management/views/forgot_password_screen.dart`)
* **Header:** Badge with `LucideIcons.keyRound`, serif title ("Reset Password").
* **Input:** Validated email text field.
* **Action:** Dispatches password reset link via `AuthRepository.sendPasswordResetEmail()`.
* **Confirmation View:**
  - Seamless in-place transition to a clean confirmation card with success icon (`LucideIcons.checkCircle2`).
  - Clear user instructions ("Check your inbox or spam folder").
  - "Back to Sign In" primary button and "Try another email address" reset action.

---

## 5. Repository Layer & Riverpod Architecture

Created a dedicated, clean architecture service and repository layer:

### Files Added / Updated:
1. **`lib/features/user_management/models/auth_exception.dart`**:
   - Comprehensive error translation mapping all Firebase error codes (`invalid-credential`, `user-not-found`, `wrong-password`, `email-already-in-use`, `weak-password`, `invalid-email`, `user-disabled`, `network-request-failed`, `too-many-requests`, `operation-not-allowed`) into human-readable messages.
2. **`lib/features/user_management/repository/auth_repository.dart`**:
   - Defines `IAuthRepository` contract and production `AuthRepository`.
   - Methods:
     - `signInWithEmailAndPassword({email, password})`
     - `signUpWithEmailAndPassword({email, password, fullName})`
     - `sendPasswordResetEmail({email})`
     - `signOut()`
     - `currentUser` and `authStateChanges()`
     - `getUserProfile(uid)` and `updateUserProfile(profile)`
     - Backward-compatible `loginWithUsername` and `changePassword` delegates.
3. **`lib/features/user_management/providers/auth_providers.dart`**:
   - `authRepositoryProvider`: Exposes repository singleton.
   - `authStateChangesProvider`: Native `StreamProvider<User?>` for reactive auth tracking.
   - `currentUserProvider`: Direct access to current `User?`.
   - `userProfileProvider`: Family provider fetching `UserProfile` for a given UID.
4. **`lib/features/user_management/services/auth_service.dart`**:
   - Standardized facade delegating to `AuthRepository` to maintain 100% backward compatibility for all existing tests and features.

---

## 6. Authentication Gate & Routing Security

In `lib/routes/app_router.dart`, `RouterNotifier` enforces a strict authentication gate:

| User Lifecycle State | Current URL / Target | Enforced Redirection |
| :--- | :--- | :--- |
| **Initializing (`isInitializing: true`)** | `/splash` | Permitted (`null`) |
| **Initializing (`isInitializing: true`)** | Any other route | `-> /splash` |
| **Signed Out (`!isAuthenticated`)** | `/login`, `/signup`, `/forgot-password` | Permitted (`null`) |
| **Signed Out (`!isAuthenticated`)** | Protected (`/`, `/tasks`, `/settings`, `/admin`) | `-> /login` |
| **Authenticated Normal User** | Auth screens (`/login`, `/signup`, `/forgot-password`, `/splash`) | `-> /` (Dashboard) |
| **Authenticated Normal User** | `/admin` | `-> /` (Dashboard) |
| **Authenticated Normal User** | Protected app routes (`/`, `/tasks`, `/habits`, `/money`, `/settings`) | Permitted (`null`) |
| **Authenticated Administrator** | Auth screens (`/login`, `/signup`, `/splash`) | `-> /admin` |
| **Authenticated Administrator** | `/admin` | Permitted (`null`) |

> [!NOTE]
> No user can bypass protected routes. The router actively guards all shell routes, settings, notifications, and search screens.

---

## 7. Firestore User Profile Architecture (Task 10)

Upon sign-up or first login, `AuthRepository._persistProfile()` writes profile metadata:

* **Target Document:** `users/{uid}`
* **Backward-Compatible Reference:** `users/{uid}/settings/profile`
* **Stored Fields:**
  ```json
  {
    "id": "<uid>",
    "email": "user@example.com",
    "displayName": "Full Name",
    "username": "Full Name",
    "role": "user",
    "createdAt": "2026-10-10T12:00:00.000Z",
    "lastLoginAt": "2026-10-10T12:00:00.000Z"
  }
  ```
* **Security Rules Compliance:** Fits within `match /users/{userId}/{document=**}` allowing access only to the authenticated UID or server admin.
* **Credentials:** Strictly **zero** secrets or passwords stored.

---

## 8. Safe Logout & Resource Disposal (Task 9)

In `lib/features/settings/screens/settings_screen.dart`, `_handleLogout()` guarantees clean resource teardown:

1. **Flush Queue:** Flushes pending changes to cloud or alerts user if offline.
2. **Stop Sync Listeners:** Cancels active Firestore snapshot streams (`syncService.stopRealTimeSync()`).
3. **Close Hive Boxes:** Safely closes all user-scoped boxes for the UID (`HiveService().closeUserBoxes(userId)`). Box files remain cached on disk for next login.
4. **Invalidate Riverpod Providers:** Safely invalidates user-scoped caches and repositories:
   - `tasksProvider`, `habitsProvider`, `habitEntriesProvider`, `moneyProvider`, `monthlyBudgetProvider`, `appSettingsProvider`.
   - `taskRepositoryProvider`, `habitRepositoryProvider`, `moneyRepositoryProvider`, `settingsRepositoryProvider`.
5. **Reset User Context:** Calls `ref.read(userContextProvider.notifier).resetToLegacy()`.
6. **Firebase Sign Out:** Invokes `authService.logout()`.
7. **Route Navigation:** Redirects user cleanly to `/login`.

---

## 9. Verification & Test Results

### 1. Static Analysis (`flutter analyze`)
```text
Analyzing ARC...
No issues found! (ran in 8.6s)
```

### 2. Automated Test Suite (`flutter test`)
**178 of 178 tests passed (100% pass rate across the entire repository).**

```text
00:12 +178: All tests passed!
```

Key test suites covering Phase 1:
- `test/auth_repository_test.dart`: 8 unit tests covering sign-up, sign-in, duplicate email handling, weak password rejection, password reset, session sign-out, and `AuthException` mapping.
- `test/auth_ui_and_gate_test.dart`: 9 tests verifying `SignUpScreen`, `ForgotPasswordScreen`, password visibility toggles, and all 5 scenarios of the GoRouter authentication gate.
- `test/login_screen_redesign_test.dart`: 3 tests verifying Login form controls, placeholders, validation, password reset link, sign up link, and error reporting.
- `test/auth_password_validation_test.dart`: 12 tests verifying password change, session integrity, and user isolation.
- `test/settings_ui_modification_test.dart` & `test/logout_ui_redesign_test.dart`: 4 tests verifying settings profile display, logout confirmation dialog, and cancel/logout flows.
- `test/widget_test.dart`: Full app rendering and initial auth gate routing test.

### 3. Build Check (`flutter build web`)
```text
Compiling lib\main.dart for the Web...
Font asset "lucide.ttf" was tree-shaken, reducing it from 913104 to 20956 bytes (97.7% reduction).
√ Built build\web (87.4s)
```

---

## 10. Outstanding Blockers & Phase 2 Handoff

* **Blockers:** **None.** Phase 1 is completely implemented, verified, and free of defects.
* **Phase 2 Handoff Notes:**
  1. Phase 1 provides the authentication foundation and email/password screens.
  2. Google Sign-In and OAuth providers are intentionally excluded per project instructions and can be integrated into `AuthRepository` during a future phase.
  3. Firebase Console must have Email/Password authentication enabled under Authentication → Sign-in method.
