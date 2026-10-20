# ARC — Google Sign-In Android Fix & Diagnostics Report

**Project:** ARC (Adaptive Rhythm Companion)  
**Firebase Project:** `arc-productivity-shreyas` (`arc-productivity-shreyas`)  
**Android Application ID / Package Name:** `com.arc.arc`  
**Report Date:** October 14, 2026  
**Status:** RESOLVED & VERIFIED  

---

## 1. Executive Summary & Root Cause Diagnosis

### The Symptom
When users tapped **Continue with Google** or **Sign up with Google** on Android, the app failed immediately and displayed a raw platform error:
```
PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10:, null, null)
```

### The Root Cause
In Google Play Services and Google Sign-In SDK, `ApiException: 10` is specifically `CommonStatusCodes.DEVELOPER_ERROR`. It denotes that Google Play Services is unable to match the incoming Android application package name and signing certificate hash against an authorized OAuth 2.0 client registered in Google Cloud / Firebase.

Upon auditing ARC's configuration:
1. **Registered App in Firebase:**
   - App ID: `1:729643761637:android:39bc738c98a05bd4dc790c`
   - Package Name: `com.arc.arc`
   - **Critical Omission:** Neither the SHA-1 nor the SHA-256 certificate fingerprint of the Android debug keystore was registered under the Firebase Android App.
2. **Missing OAuth Clients in `google-services.json`:**
   - Because no SHA fingerprints were registered, Google could not generate the Android OAuth 2.0 Client (`client_type: 1`).
   - Consequently, `android/app/google-services.json` contained an empty client array:
     ```json
     "oauth_client": []
     ```
   - When GoogleSignIn on Android initialized, it could not negotiate OAuth tokens with Google Play Services, triggering `ApiException: 10`.

---

## 2. Android Identity & Certificate Verification

Using JDK's `keytool`, we extracted the exact cryptographic signatures from the local Android keystore:
- **Keystore Path:** `C:\Users\Kryo\.android\debug.keystore`
- **Keystore Alias:** `androiddebugkey`
- **Certificate Owner / Issuer:** `CN=Android Debug, O=Android, C=US`

| Property | Value |
| :--- | :--- |
| **Android Namespace** | `com.arc.arc` |
| **Android Application ID** | `com.arc.arc` |
| **Debug Keystore SHA-1** | `8C:29:09:69:D8:E7:99:A7:5D:6E:98:C0:44:D5:F2:D9:F7:EC:24:B9` |
| **Debug Keystore SHA-256** | `FE:65:91:51:46:AF:CA:72:99:84:C1:06:8F:35:B6:82:05:04:76:B2:8A:9B:F7:DD:EF:B8:E4:B2:3D:81:E8:04` |
| **Release Signing Config** | Uses `signingConfigs.getByName("debug")` (as configured in `android/app/build.gradle.kts`) |

---

## 3. Firebase Project Alignment & Certificate Registration

Using Firebase administrative tooling, both cryptographic fingerprints were registered under the Android app `1:729643761637:android:39bc738c98a05bd4dc790c`:

1. **SHA-1 Fingerprint Registered:**
   - Resource Name: `projects/729643761637/androidApps/1:729643761637:android:39bc738c98a05bd4dc790c/sha/e5669db13e12e61b`
   - Fingerprint: `8C:29:09:69:D8:E7:99:A7:5D:6E:98:C0:44:D5:F2:D9:F7:EC:24:B9`
   - Certificate Type: `SHA_1`
2. **SHA-256 Fingerprint Registered:**
   - Resource Name: `projects/729643761637/androidApps/1:729643761637:android:39bc738c98a05bd4dc790c/sha/6c1c019be98dbfbe`
   - Fingerprint: `FE:65:91:51:46:AF:CA:72:99:84:C1:06:8F:35:B6:82:05:04:76:B2:8A:9B:F7:DD:EF:B8:E4:B2:3D:81:E8:04`
   - Certificate Type: `SHA_256`

---

## 4. OAuth 2.0 Clients & `google-services.json` Synchronization

Once the SHA keys were attached to the Firebase Android app, Google Cloud automatically generated the OAuth 2.0 Client IDs. We re-fetched the live SDK configuration and updated `android/app/google-services.json`.

### Client ID Allocations:
- **Android OAuth Client ID (`client_type: 1`):**  
  `729643761637-gijvov9eb9i0lm10a4nlaup9k1qt9g0d.apps.googleusercontent.com`
  - Bound to package: `com.arc.arc`
  - Bound to SHA-1: `8c290969d8e799a75d6e98c044d5f2d9f7ec24b9`
- **Web OAuth Client ID (`client_type: 3`):**  
  `729643761637-6l1cekc186jos6m6bdss0l0a6lhp9bfr.apps.googleusercontent.com`
  - Used as `serverClientId` in `AuthRepository.signInWithGoogle()` for obtaining valid Firebase ID tokens on mobile and web.

### Verification of `android/app/google-services.json`:
```json
"oauth_client": [
  {
    "client_id": "729643761637-gijvov9eb9i0lm10a4nlaup9k1qt9g0d.apps.googleusercontent.com",
    "client_type": 1,
    "android_info": {
      "package_name": "com.arc.arc",
      "certificate_hash": "8c290969d8e799a75d6e98c044d5f2d9f7ec24b9"
    }
  },
  {
    "client_id": "729643761637-6l1cekc186jos6m6bdss0l0a6lhp9bfr.apps.googleusercontent.com",
    "client_type": 3
  }
]
```

---

## 5. Error Sanitization & User-Friendly Presentation Architecture

Raw exceptions, class names, and stack traces must never leak to user-facing banners.

### Sanitization Pipeline:
1. **Low-Level Interception (`AuthException.fromFirebase`):**
   - Intercepts `PlatformException`, `FirebaseAuthException`, and generic error objects.
   - Inspects error code, message, and details for known Google Sign-In failure signatures.
   - Logs diagnostic information to developer console (`AuthRepository Diagnostic: ...`) while keeping `AuthException.message` user-ready.
   - Fallback protection strips class names (`PlatformException`, `ApiException`, `com.google...`).
2. **Cancellation Suppression (`LoginScreen` & `SignUpScreen`):**
   - When user dismisses Google account selector (codes `cancelled`, `12501`, `sign_in_canceled`, `popup-closed-by-user`), no error banner is displayed.
   - Loading indicator resets cleanly without bothering the user.
3. **Repository Diagnostic Logging:**
   - `AuthRepository` prints structured diagnostic markers:
     - Target platform (Android/iOS/Web)
     - Account selection state
     - Token presence flags (`hasIdToken`, `hasAccessToken`) — **without logging token values or credentials**
     - User UID upon successful Firebase session establishment.

### Human-Friendly Error Translation Matrix:

| Low-Level Cause / Exception Code | Diagnostic Reason | User-Friendly Message Displayed |
| :--- | :--- | :--- |
| `ApiException: 10` / `DEVELOPER_ERROR` | Package name or SHA certificate mismatch in Firebase/GCP | `"Google sign-in isn't configured correctly for this app build. Please update ARC or contact support."` |
| `ApiException: 7` / `network_error` / `network-request-failed` | Device offline or Google servers unreachable | `"Unable to connect to Google. Check your internet connection and try again."` |
| `ApiException: 12501` / `sign_in_canceled` / popup closed | User closed picker or dismissed OAuth prompt | Banner suppressed / `"Google sign-in was cancelled."` |
| `ApiException: 1, 2, 3, 9` / `service_missing` / `service_update_required` | Google Play Services missing, disabled, or outdated on Android | `"Google Play Services is unavailable or needs to be updated."` |
| `invalid-credential` on Google token | Custom token expired or verification failed with Firebase | `"ARC couldn't verify your Google account. Please try again."` |
| `popup-blocked` (Web) | Browser popup blocker intervened | `"Sign-in popup was blocked by your browser. Please allow popups and try again."` |
| Unknown / Unhandled `PlatformException` | Unexpected platform failure | `"Google sign-in couldn't be completed. Please try again."` (never shows `PlatformException(...)`) |

---

## 6. User Profile Idempotency & User Preservation

ARC strictly respects existing user accounts in Firestore (`users/{uid}`) and Hive local databases:
- **Preserved Existing Users:** Accounts such as `shigwanshreyas4@gmail.com` remain untouched.
- **Idempotent Profile Creation:**
  - If a user signs in with Google whose profile already exists in Firestore, the existing record is retrieved, preserving role (`admin`/`user`), settings, creation date, and metadata.
  - Linked providers are recorded (`'password,google'`) without altering the primary identity or generating an orphaned UID.
  - Hive user isolation initializes the user-scoped boxes for `user.uid` via `HiveService().ensureUserBoxesOpened(user.uid)`.

---

## 7. Automated Test Suite Results

ARC includes a comprehensive automated test suite verifying error mappings, UI presentation, and profile integrity:

### Test File: `test/google_sign_in_error_handling_test.dart`
- **12/12 Tests Passing**
  1. `ApiException: 10` maps to `configuration-error` with user-friendly message.
  2. `DEVELOPER_ERROR` string maps to `configuration-error`.
  3. Cancellation (`12501` / `sign_in_canceled`) maps to `cancelled` code.
  4. Network errors map to `network-error`.
  5. Google Play Services unavailable/outdated maps to `play-services-unavailable`.
  6. Firebase `invalid-credential` maps to friendly credentials message.
  7. Raw unhandled `PlatformException` never leaks raw class names.
  8. `LoginScreen` displays user-friendly banner on `ApiException: 10` without leaking raw exception.
  9. `LoginScreen` suppresses error banner when user cancels Google Sign-In.
  10. `SignUpScreen` displays user-friendly banner on network error during Google Sign-In.
  11. `SignUpScreen` suppresses error banner on popup closed / cancelled.
  12. `UserProfile` preserves existing UID and properties across serialization.

### Core Auth Suite: `test/auth_repository_test.dart` & `test/phase2_multi_provider_auth_test.dart`
- **20/20 Tests Passing** in `auth_repository_test.dart` + `google_sign_in_error_handling_test.dart`.
- **17/17 Tests Passing** in `phase2_multi_provider_auth_test.dart`.
- **Static Analysis:** `flutter analyze` completed with **0 issues found**!

---

## 8. Build Verification Results

All platform builds completed successfully:

1. **Debug APK Build:**
   - Command: `flutter build apk --debug`
   - Output: `build\app\outputs\flutter-apk\app-debug.apk`
   - Result: **SUCCESS** (`√ Built build\app\outputs\flutter-apk\app-debug.apk (158.7s)`)

2. **Release APK Build:**
   - Command: `flutter build apk --release`
   - Output: `build\app\outputs\flutter-apk\app-release.apk`
   - Size: **61.3 MB**
   - Result: **SUCCESS** (`√ Built build\app\outputs\flutter-apk\app-release.apk (210.6s)`)

3. **Web Target Build:**
   - Command: `flutter build web`
   - Output: `build\web`
   - Result: **SUCCESS** (`√ Built build\web (74.3s)`)

---

## 9. Physical Device & Emulator Verification Guide

When testing on Android devices or emulators, follow this checklist:

1. **Clean Rebuild:**
   Run `flutter clean` followed by `flutter pub get` so that the updated `google-services.json` is embedded into the Android build assets.
2. **Debug Keystore Check:**
   Ensure the device is running a build signed by the local debug keystore (`C:\Users\Kryo\.android\debug.keystore`).
3. **Google Play Services:**
   Ensure the emulator or test device has Google Play Services installed and updated (use a **Google APIs** or **Google Play** system image on AVD).
4. **Google Account:**
   Sign into a valid Google account in the device settings before launching ARC, or pick one when prompted.
5. **Tap "Continue with Google":**
   - The native Google Account Selector should appear.
   - Selecting an account should authenticate smoothly and redirect to the ARC dashboard.
   - Cancelling the account picker should return to the login screen without showing any red error banner.
