# User actions required

1. In Firebase Console, verify ownership of `arc-productivity-shreyas`, registered package `com.arc.arc`, Auth providers, SHA fingerprints, Firestore rules/indexes, App Check, backups, and whether Functions/Storage exist outside this repository. Do not paste secrets into chat or source.
2. Decide whether automatic SMS money tracking is core to the Play-distributed app. If yes, prepare the Google Play Permissions Declaration, privacy policy, prominent in-app disclosure/consent, data-handling evidence, and a compliant fallback/distribution plan.
3. Provide access to the existing production signing/Play App Signing process only through secure CI or local signing configuration; never commit keys or passwords.
4. Start an emulator or attach an unlocked test device, accept the ADB trust prompt, and verify `adb devices -l`. This is required for launch and performance validation.
5. Install Android SDK Command-line Tools (latest) if SDK CLI management is desired and add platform-tools to user PATH.
6. Resolve the two Flutter SDK PATH entries before future Flutter maintenance.
7. Review whether `google-services.json` should remain untracked or be committed as non-secret client config under the organization's policy. Phase 0 keeps it untracked/absent.
