# ARC-Kotlin Phase 5 — User Actions Required & Manual Verification

## 1. Overview

While all automated tests (170+) pass with 100% success rate, certain physical hardware features and production deployment configurations require manual device testing and credential setup by the project maintainer.

---

## 2. Manual Testing Checklist (On Physical Android Device)

1. **Android 13+ (API 33+) Notification Permission**:
   - Install the debug APK: `adb install -r app/build/outputs/apk/debug/app-debug.apk`.
   - On first launch or when enabling reminders in Settings, verify the system permission prompt appears: *"Allow ARC to send you notifications?"*.
   - Tap "Allow" and confirm notification delivery when a task or habit reminder fires.
2. **Inexact Battery-Friendly Alarms**:
   - Set a task due in 6 minutes.
   - Lock the device and verify that the "Task due soon" notification arrives at or around the 5-minute pre-deadline window without killing device standby battery.
3. **Hardware Biometric Authentication in Vault**:
   - On a device with fingerprint or face biometric enrolled, set a 6-digit PIN in Settings / Vault.
   - Enable Biometric Unlock. Lock the vault and verify single-prompt biometric unlock succeeds instantly.
   - Test invalid biometric attempts and verify fallback to PIN keypad.
4. **Window Security (`FLAG_SECURE`)**:
   - Open the Secret Notes Vault.
   - Open Android's Recent Apps (Task Switcher) view. Verify that the Vault screen content is blanked/obscured and cannot be captured or screenshotted.
5. **Theme Switching**:
   - In Settings or the top app bar, toggle between Dark, Light, and System themes.
   - Verify that all screen components (Tasks, Habits, Money, Dashboard, Search, Settings) adapt immediately.

---

## 3. Production Deployment & Signing Requirements

Before creating a release APK or AAB for Google Play Store publication:

1. **Generate Production Keystore**:
   - Run `keytool` to create a production release key:
     ```shell
     keytool -genkey -v -keystore arc-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias arc-key
     ```
   - Store `arc-release-key.jks` in a secure location outside Git version control.
2. **Configure Signing Config in Gradle**:
   - In `app/build.gradle.kts`, configure release signing using environment variables:
     ```kotlin
     signingConfigs {
         create("release") {
             storeFile = file(System.getenv("KEYSTORE_PATH") ?: "keystore.jks")
             storePassword = System.getenv("KEYSTORE_PASSWORD")
             keyAlias = System.getenv("KEY_ALIAS")
             keyPassword = System.getenv("KEY_PASSWORD")
         }
     }
     ```
3. **Google Play Policy Attestations**:
   - Confirm that `USE_EXACT_ALARM` is NOT declared in production manifest.
   - Confirm that SMS permissions (`READ_SMS`, `RECEIVE_SMS`) are NOT declared in production manifest.
