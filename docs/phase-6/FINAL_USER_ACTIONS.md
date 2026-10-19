# Final User & DevOps Actions Required for Production Rollout

## Overview

ARC-Kotlin Phase 6 implementation, automated verification, R8 compilation, and documentation are complete.

To promote ARC-Kotlin from development acceptance to live Google Play production, the repository owner and DevOps engineer must complete the following manual, environment-specific operational steps.

---

## Step 1: Generate or Import Production Release Keystore

The repository enforces strict zero-credential storage in Git. To sign release builds for Google Play:

1. **Generate Production Keystore** (if not already existing from Google Play Console):
   ```bash
   keytool -genkey -v -keystore arc-release-upload.jks \
       -alias arc-upload-key \
       -keyalg RSA \
       -keysize 2048 \
       -validity 10000 \
       -dname "CN=Shreyas, OU=ARC, O=ARC Productivity, L=Bangalore, ST=Karnataka, C=IN"
   ```

2. **Extract Cryptographic Fingerprints**:
   ```bash
   keytool -list -v -keystore arc-release-upload.jks -alias arc-upload-key
   ```
   Record both the **SHA-1** and **SHA-256** fingerprints.

---

## Step 2: Register SHA Fingerprints in Firebase Console

1. Navigate to [Firebase Console](https://console.firebase.google.com/) > Project `arc-productivity-shreyas`.
2. Open **Project Settings** > **General** > **Your Apps**.
3. Under Android app `com.arc.arc`:
   - Add the **SHA-1** fingerprint extracted from your upload keystore.
   - Add the **SHA-256** fingerprint.
   - (If Google Play App Signing is enabled, also copy the **SHA-1** fingerprint provided by Google Play App Signing and add it to Firebase).
4. Download the updated `google-services.json` and place it in `app/google-services.json`.

---

## Step 3: Configure Environment Variables for Automated Builds

Set the following environment variables in your local terminal or CI/CD runner (GitHub Secrets):

```powershell
$env:KEYSTORE_PATH = "C:\secure\keys\arc-release-upload.jks"
$env:KEYSTORE_PASSWORD = "YourSecurePassword"
$env:KEY_ALIAS = "arc-upload-key"
$env:KEY_PASSWORD = "YourKeyPassword"
```

Then compile the signed production artifacts:
```powershell
.\gradlew.bat :app:assembleRelease
.\gradlew.bat :app:bundleRelease
```

---

## Step 4: Perform Physical Device Acceptance

1. Connect a physical Android phone running Android 12, 13, or 14 via USB debugging.
2. Install the signed release APK:
   ```powershell
   adb install -r app/build/outputs/apk/release/app-release.apk
   ```
3. Execute the 5 test scenarios specified in [`PHYSICAL_DEVICE_QA.md`](file:///C:/dev/ARC-Kotlin/docs/phase-6/PHYSICAL_DEVICE_QA.md):
   - Google Sign-In with real account.
   - Live Firestore two-way synchronization.
   - Secret Notes PIN creation, biometric unlock, and auto-lock.
   - Memory and process recreation check.
   - Permission check (zero SMS / zero exact alarm permissions).

---

## Step 5: Upload AAB to Google Play Console Internal Track

1. Navigate to Google Play Console > App: ARC (`com.arc.arc`).
2. Go to **Release** > **Testing** > **Internal testing**.
3. Create a new release:
   - Upload file: `app/build/outputs/bundle/release/app-release.aab`.
   - Release name: `1.4.0-native (versionCode 2)`.
   - Release notes: `"Major architectural upgrade to Native Android (Kotlin & Jetpack Compose). Faster performance, lower memory usage, and enhanced biometric vault security."`
4. Save and roll out to internal test group.
5. Validate over-the-air update migration on existing test devices.
