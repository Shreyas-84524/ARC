# Physical Device Quality Assurance & Hardware Acceptance Protocol

## Overview

While automated JVM unit tests, Robolectric suites, and Gradle builds prove code correctness and compile-time integrity, final production acceptance requires physical device validation.

This document details the standardized physical device testing protocol, test execution matrix, and sign-off criteria required before promoting ARC-Kotlin to Google Play production.

---

## Device Test Matrix

To guarantee broad compatibility and verify hardware-dependent features (BiometricPrompt, StrongBox Keystore, Credential Manager, Notification channels), testing must cover three device tiers:

| Tier | Representative Hardware | OS Version | Hardware Target To Validate |
| :--- | :--- | :--- | :--- |
| **Tier 1: Modern Flagship** | Google Pixel 7/8/9, Samsung Galaxy S23/S24 | Android 14 / 15 (API 34–35) | StrongBox Keystore (`KeyProperties.SECURITY_LEVEL_STRONGBOX`), Credential Manager, Predictive Back gesture, 120Hz smooth scrolling |
| **Tier 2: Mainstream Mid-Range** | OnePlus Nord, Samsung Galaxy A54, Redmi Note 12 | Android 12 / 13 (API 31–33) | TEE Keystore, Dynamic Material You theming, Notification permission dialog (`POST_NOTIFICATIONS`) |
| **Tier 3: Minimum Supported** | Motorola G7, Samsung Galaxy S7/S8 | Android 6.0 – 9.0 (API 23–28) | Core-desugared Java 8 APIs, legacy TEE Keystore fallback, SQLite performance on low-end eMMC flash |

---

## Standardized QA Test Scenarios

### Test 1: Real Firebase Authentication via Credential Manager
- **Action**: Launch application on device with active Google accounts. Tap "Continue with Google".
- **Expected Result**: Bottom sheet credential picker appears. Selecting account authenticates seamlessly and transitions to Main Dashboard. User profile picture and email display accurately in Navigation Drawer / Settings.
- **Pass Criteria**: Firebase Auth state transitions to `Authenticated` with a valid UID matching the Google user.

### Test 2: Live Two-Way Cloud Firestore Synchronization
- **Action**:
  1. On device, create a Task: `"Verify Physical Hardware QA"` with priority `"High"`.
  2. Open Firebase Console (`arc-productivity-shreyas` > Firestore > `users/{uid}/tasks`).
  3. Verify the document appears in real-time with matching UUID.
  4. In Firebase Console, edit the title to `"Verify Physical Hardware QA (Console Edit)"`.
  5. Observe the device screen.
- **Expected Result**: The Task list updates immediately via the snapshot listener without requiring a manual refresh.
- **Pass Criteria**: Document fields, timestamps, and priority match bidirectionally.

### Test 3: Secret Vault Biometrics & StrongBox Hardware Inspection
- **Action**: Navigate to Secret Notes > Set PIN > Enable Biometric Unlock. Lock the vault. Trigger biometric unlock.
- **Expected Result**: Native Android `BiometricPrompt` modal dialog appears. Fingerprint or Face recognition unwraps the hardware-backed Master Key and decrypts the DEK.
- **Pass Criteria**: Notes decrypt and render in < 100ms. In logcat, verify `AndroidKeystoreMasterKeyProvider` reports `STRONGBOX` (on Pixel/Samsung flagships) or `TRUSTED_ENVIRONMENT`.

### Test 4: Process Death & State Restoration
- **Action**: Enable "Don't keep activities" in Android Developer Options. Open Money Manager > Add Transaction form > Fill in fields > Switch to another app > Return to ARC.
- **Expected Result**: Form inputs, scroll position, and state are restored cleanly without crash or blank screen.

### Test 5: Strict Zero-SMS Permission Audit
- **Action**: Inspect app permissions via Android Settings > Apps > ARC > Permissions.
- **Expected Result**: No SMS (`READ_SMS`, `RECEIVE_SMS`), Call Log, or Contact permissions are requested or listed.
- **Pass Criteria**: Zero restricted permissions present in `AndroidManifest.xml` or runtime requests.

---

## Current Environment Status: Physical Device Blocker

> [!WARNING] **Acceptance Status: BLOCKED on Physical Device Sign-Off**
> In the current automated build environment, no physical USB Android devices or active emulators are connected (`adb devices` returns 0 targets).
> 
> Therefore, while the application binary (`app-release.apk`) compiles with 100% test pass rate and verified R8 optimization, **formal production acceptance is blocked until a QA engineer completes the physical device protocol on Tier 1, Tier 2, and Tier 3 devices**.
