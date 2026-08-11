# Project Arc — Authentication & Change Password Service Fix Report

## Overview
This report documents the resolution of the two major authentication problems in Project Arc:
1. **Login Password Validation Failure**: Bypassing Firebase Authentication error checking and granting app access regardless of password accuracy.
2. **Change Password Service Failure**: Bypassing Firebase Authentication re-authentication and `updatePassword()` operations without updating the credentials in Firebase Authentication.

---

## 1. Root Cause of the Login Password Validation Problem
`AuthService.loginWithUsername` wrapped `signInWithEmailAndPassword` and `createUserWithEmailAndPassword` inside a broad `try-catch` block. When Firebase Authentication rejected credentials (e.g., `wrong-password` or `invalid-credential`), the catch block caught the exception and generated a synthetic fallback profile (`uid = 'arc_uid_<username>'`) instead of throwing an authentication error.

This allowed the application to bypass Firebase Authentication completely, setting `UserContext` to authenticated without an active `FirebaseAuth.currentUser` session.

---

## 2. Exact Files/Functions Responsible
- **`lib/features/user_management/services/auth_service.dart`**: `loginWithUsername`
- **`lib/features/user_management/views/login_screen.dart`**: `_handleLogin`

---

## 3. Existing Authentication Flow Before the Fix
```
User enters Username + Password
        ↓
Username mapped to internal email identity (username@arc.app)
        ↓
signInWithEmailAndPassword called
        ↓
Firebase Auth throws wrong-password / invalid-credential exception
        ↓
Caught by broad catch (e) block in loginWithUsername
        ↓
Fallback mode active: uid = 'arc_uid_<username>'
        ↓
UserContext set to authenticated without valid FirebaseAuth.currentUser
        ↓
Main App opened (INCORRECT BEHAVIOR)
```

---

## 4. Corrected Authentication Flow
```
User enters Username
        ↓
Username matched against UserProfile.knownUsernames (Shreyas, Aman, Rohit, Sachi, Yash)
        ↓
Username mapped to internal email (username@arc.app)
        ↓
User enters Password
        ↓
_auth.signInWithEmailAndPassword(email, password)
        ↓
Firebase Authentication validates credentials
        ├─ SUCCESS → FirebaseAuth.currentUser authenticated → Open Hive boxes → Main App
        └─ FAILURE → Throw ArgumentError('Invalid password.') → Remain on Login Screen → Show clean error
```

---

## 5. How Username is Mapped to Firebase Authentication
The entered username is sanitized (`username.trim()`) and matched case-insensitively against `UserProfile.knownUsernames` (`Shreyas`, `Aman`, `Rohit`, `Sachi`, `Yash`). The internal email is derived via `UserProfile.emailForUsername(username)`: `${username.toLowerCase()}@arc.app`.

---

## 6. Confirmation of Firebase Password Validation
**CONFIRMED**. All fallback code in `loginWithUsername` that suppressed auth errors has been eliminated. `FirebaseAuth.instance.signInWithEmailAndPassword` is the authoritative source for password validation. If Firebase Auth rejects credentials, `loginWithUsername` throws an error and the application remains unauthenticated on the Login Screen.

---

## 7. Root Cause of the Change Password Failure
1. `AuthService.changePassword` skipped re-authentication and `updatePassword()` whenever `_auth.currentUser` was null (which occurred on fallback logins).
2. Exceptions thrown during re-authentication were caught by a generic `catch (e)` block that swallowed errors with `debugPrint`.
3. `SettingsScreen` reported success ("Password updated successfully!") regardless of whether `updatePassword()` succeeded or was even executed.

---

## 8. Exact Files/Functions Responsible
- **`lib/features/user_management/services/auth_service.dart`**: `changePassword`
- **`lib/features/settings/screens/settings_screen.dart`**: `_handleChangePassword`

---

## 9. Corrected Change Password Flow
```
Authenticated User (FirebaseAuth.currentUser != null)
        ↓
User opens Settings → Change Password
        ↓
Enters Current Password & New Password
        ↓
Re-authenticate: EmailAuthProvider.credential(email, currentPassword)
        ↓
currentUser.reauthenticateWithCredential(credential)
        ├─ WRONG CURRENT PASSWORD → Throw ArgumentError('Current password is incorrect.') → Danger SnackBar
        └─ VALID CURRENT PASSWORD → Proceed
                ↓
currentUser.updatePassword(newPassword)
        ├─ WEAK PASSWORD → Throw ArgumentError('Your new password does not meet requirements.')
        └─ SUCCESS → Clear fields → Close section → Show Success SnackBar
```

---

## 10. Re-authentication Implementation
Re-authentication is explicitly enforced prior to updating credentials.
```dart
final credential = auth.EmailAuthProvider.credential(
  email: email,
  password: currentPassword,
);
await currentUser.reauthenticateWithCredential(credential);
```
If re-authentication fails due to `wrong-password` or `invalid-credential`, `changePassword` throws `ArgumentError('Current password is incorrect.')`.

---

## 11. Confirmation of updatePassword() Execution
**CONFIRMED**. `currentUser.updatePassword(newPassword)` is executed on the authenticated `FirebaseAuth.currentUser` object immediately after re-authentication.

---

## 12. Confirmation of Zero Password Storage
**CONFIRMED**. Passwords are **NEVER** stored in Hive boxes, Firestore documents, SharedPreferences, or application logs. Firebase Authentication remains the sole repository of authentication credentials.

---

## 13. Error Handling Improvements
Raw Firebase error codes are translated into clean, user-friendly error messages:
- `user-not-found` → `"Invalid username."`
- `wrong-password` / `invalid-credential` → `"Invalid password."` or `"Current password is incorrect."`
- `weak-password` → `"Your new password does not meet the password requirements."`
- `requires-recent-login` → `"For security reasons, please log out and log back in before changing your password."`

---

## 14. Test Cases Performed & Results
The comprehensive unit test suite in `test/auth_password_validation_test.dart` verified all 15 scenarios:

| Test ID | Test Description | Expected Behavior | Result |
| :--- | :--- | :--- | :--- |
| **TEST 1** | Correct Username + Correct Password | Firebase auth succeeds; user authenticated | **PASS** |
| **TEST 2** | Correct Username + Wrong Password | Firebase auth rejects; remains unauthenticated | **PASS** |
| **TEST 3** | Invalid Username | Throws `ArgumentError('Invalid username.')` | **PASS** |
| **TEST 4** | Empty Username | Validation error; no auth call | **PASS** |
| **TEST 5** | Empty Password | Validation error; no auth call | **PASS** |
| **TEST 6** | Correct Password After Failed Attempt | Retry with correct password succeeds | **PASS** |
| **TEST 7** | Change Password | Updates password in Firebase Auth | **PASS** |
| **TEST 8** | Wrong Current Password | Throws `Current password is incorrect.` | **PASS** |
| **TEST 9** | New Password Validation (<6 chars) | Throws length validation error | **PASS** |
| **TEST 10** | Old Password After Change | Old password login fails | **PASS** |
| **TEST 11** | New Password After Change | New password login succeeds | **PASS** |
| **TEST 12** | Session Continuity | Authenticated UID remains unchanged | **PASS** |
| **TEST 13** | Explicit Logout | Clears session cleanly | **PASS** |
| **TEST 14** | Login After Logout | Log in with new password succeeds | **PASS** |
| **TEST 15** | User Isolation | User A password change does not affect User B | **PASS** |

---

## 15–18. Build & Validation Metrics

### 16. `flutter analyze`
- **Result**: **0 issues found** (Passes cleanly)

### 17. `flutter test`
- **Result**: **All 131 tests passed** (100% pass rate)

### 18. `flutter build apk --debug`
- **Result**: **Build Succeeded** (`build/app/outputs/flutter-apk/app-debug.apk`)

---

## 19–22. Architecture & Policy Preservation Checklist

- [x] **Item 19 (User Isolation)**: Confirmed. User-scoped Hive boxes (`users/{uid}/*`) and Firestore path scoping remain 100% isolated.
- [x] **Item 20 (Synchronization Architecture)**: Confirmed. Hive-first synchronization architecture is completely preserved.
- [x] **Item 21 (12-Hour Sync Policy)**: Confirmed. Minimum 12-hour full sync interval is unchanged.
- [x] **Item 22 (2 Syncs per 24 Hours Policy)**: Confirmed. Maximum 2 full syncs per 24-hour rolling window policy is unchanged.

---

## Final Acceptance Criteria Verification
- ✓ Correct username + correct password → Login succeeds.
- ✓ Correct username + wrong password → Login fails.
- ✓ Invalid username → Login fails.
- ✓ Application cannot enter authenticated Main App without successful Firebase Authentication.
- ✓ Change Password actually updates Firebase Authentication password.
- ✓ Old password fails after successful password change.
- ✓ New password succeeds after successful password change.
- ✓ Passwords are never stored in Hive or Firestore.
- ✓ Firebase Authentication remains authoritative source.
- ✓ Existing session restoration & explicit logout work.
- ✓ User-scoped Hive isolation & synchronization architecture intact.
- ✓ `flutter analyze`, `flutter test`, and `flutter build apk --debug` all pass.
