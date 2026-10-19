# Phase 4 Handoff Specification: Secret Notes, Vault & Advanced Security

## 1. Handoff Summary

Phase 3 has successfully delivered ARC-Kotlin's Money Manager, Financial Intelligence Engine, Expense Automation, and Dashboard integration:
- **Base Branch for Phase 4:** `phase-3`
- **Target Branch for Phase 4:** `phase-4`
- **Remote:** `https://github.com/Shreyas-84524/ARC-Kotlin.git`
- **Verified Build Status:**
  - 100% clean compilation
  - 117 automated unit and integration tests passing across 22 test suites
  - Android Lint: 0 errors
  - Debug APK: `app-debug.apk` (21.96 MB)
- **Active Workspace:** `C:\dev\ARC-Kotlin`
- **Read-Only Legacy Reference:** `C:\dev\ARC` (strictly unmodified)

---

## 2. Established Architecture & Patterns for Phase 4

Engineers continuing into Phase 4 should adhere strictly to the verified conventions:

### 2.1 Toolchain Conventions
- **AGP 9.4.1 Built-in Kotlin Support:** Do not apply the legacy `kotlin-android` Gradle plugin.
- **Room Database Entities in Java:** Authored in Java in `com.arc.arc.core.database` to interoperate cleanly with `annotationProcessor(libs.androidx.room.compiler)` under AGP's built-in Kotlin support.
- **Kotlin Extension Mappers:** Author extension mappers bridging Room entities to domain models.
- **Database Migrations:** Never use `.fallbackToDestructiveMigration()`. Author `MIGRATION_3_4` in `ArcDatabase.java` and increment database version to 4.
- **Java 8+ Desugaring:** `isCoreLibraryDesugaringEnabled = true` is configured in `app/build.gradle.kts`. Use `java.time.*` and `java.security.*` freely across minSdk 23+.

### 2.2 Security & Cryptography Standards
- **Encrypted Storage:** Use AndroidX Security (`androidx.security:security-crypto`) or SQLCipher for encrypted Room database access.
- **Biometric Authentication:** Integrate `androidx.biometric:biometric` for fingerprint and face unlock.
- **Key Derivation:** Use PBKDF2 or Android Keystore backed MasterKey (`MasterKey.Builder`).
- **Memory Zeroing:** Wipe cryptographic keys and sensitive strings from memory as soon as operations complete.

---

## 3. Phase 4 Scope & Detailed Objectives

### Objective A: Room Database Migration (v3 -> v4)
1. Inspect legacy `SecretNoteModel` in `C:\dev\ARC/lib/models/secret_note_model.dart`.
2. Create `SecretNoteEntity.java` with encrypted title, content, tags, folder, and timestamp columns.
3. Create `SecretNoteDao.java` with reactive `Flow` queries.
4. Author non-destructive `MIGRATION_3_4` in `ArcDatabase.java` and export Room schema version 4.

### Objective B: Cryptographic Engine & Biometrics
1. Implement `VaultCryptoEngine` using AES-256-GCM.
2. Implement biometric authentication flow with fallback to PIN/password.
3. Implement auto-lock on application lifecycle pause (`LifecycleEventObserver`).

### Objective C: Native Secret Notes & Vault UI
1. Create `SecretNotesScreen.kt` with note cards, search, and category tags.
2. Create `SecretNoteEditorScreen.kt` with rich text input, lock/unlock toggle, and markdown support.
3. Wire `VaultRoute.kt` into `ArcNavHost.kt`.

---

## 4. Verification Checkpoint for Phase 4

Before concluding Phase 4, confirm:
1. All 117 existing unit tests pass without regression.
2. New `SecretNotesContractTest`, `VaultCryptoTest`, and `SecretNotesPersistenceTest` pass.
3. Android Lint reports 0 errors.
4. Schema version 4 is generated and exported.
5. Debug APK compiles and packages cleanly.
