# ARC-Kotlin — Phase 6 Handoff: Production Firebase, Release Delivery & Play Store Launch

## 1. Baseline Handoff Status

Phase 5 has successfully concluded with the native Android architecture completely implemented, integrated, and verified:
- **Baseline Git Commit**: Phase 5 completed on branch `phase-5`.
- **Automated Test Health**: 32 test suites, 170+ unit tests, 100% pass rate.
- **R8 / Packaging**: `assembleDebug` builds cleanly with ProGuard/R8 rules preserving Room, Gson, Biometrics, and Compose runtime.
- **Privacy & Security**: Zero-Cloud Vault strictly preserved across search, notifications, exports, and sync.

---

## 2. Phase 6 Objectives: Production Cloud & Deployment Readiness

Future work in Phase 6 will focus on:

1. **Production Firebase Integration**:
   - Transition from `DevFakeAuthRepository` to official `FirebaseAuth` with Google Sign-In and Email/Password flows.
   - Connect Firestore offline-enabled persistence for Tasks, Habits, and Money.
   - Enforce that Secret Notes Vault remains 100% local-only and is NEVER synced to Firestore.
2. **Production App Signing & Key Management**:
   - Configure Gradle release signing configs via CI/CD secrets or local environment variables.
   - Build and verify release Android App Bundle (`:app:bundleRelease`).
3. **CI/CD Pipeline Setup**:
   - Establish GitHub Actions workflow for automated compilation, lint checks, unit tests, and release artifact generation.
4. **Google Play Console Release**:
   - Prepare Store Listing, privacy policy disclosures, screenshots, and release track distribution.

---

## 3. Important Architectural Invariants to Maintain in Phase 6

- Treat `C:\dev\ARC` as strictly READ-ONLY.
- Never add `USE_EXACT_ALARM` or SMS permissions.
- Never store Secret Notes in plaintext or sync them to Firebase.
- Maintain Room schema version integrity (do not use destructive fallback).
- Keep all unit tests passing before merging or cutting releases.
