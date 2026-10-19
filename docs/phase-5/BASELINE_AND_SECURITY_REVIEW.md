# Phase 5 Baseline Verification & Vault Security Reconciliation

## 1. Baseline Verification & Toolchain Reconciliation

- **Native Repository:** `C:\dev\ARC-Kotlin`
- **Legacy Flutter Reference:** `C:\dev\ARC` (Strictly READ-ONLY)
- **Base Commit:** `f58f4e9` (`origin/phase-4`)
- **New Branch:** `phase-5`
- **Toolchain:**
  - Android Gradle Plugin: `9.4.1` (AGP built-in Kotlin support)
  - Gradle: `9.8.1`
  - Kotlin: `2.4.21`
  - Java Bytecode: Java 17
  - SDK Targets: Compile SDK 37, Min SDK 23, Target SDK 36
- **Test Baseline Reconciliation:**
  - Total Unit Tests Executed: **160 tests**
  - Total Test Suites: **30 test classes**
  - Failures: **0**
  - Errors: **0**
  - Skipped: **0**
  - Pass Rate: **100%**
  - Reconciliation Note: The 160-test figure reported in Phase 4 documentation accurately matches the 30 XML test report files in `app/build/test-results/testDebugUnitTest/` with zero discrepancies.

---

## 2. In-Depth Vault Security Architecture Review

An exhaustive audit of the Secret Notes and Encrypted Vault subsystem was performed across the complete codebase:
- `VaultCryptoEngine.kt`
- `VaultPinManager.kt`
- `VaultAuthCoordinator.kt`
- `BiometricAuthManager.kt`
- `VaultPreferencesDataStore.kt`
- `LegacyVaultMigrationAdapter.kt`
- `VaultLifecycleManager.kt`
- `AndroidManifest.xml` & `data_extraction_rules.xml`

### Severity-Ranked Findings Report

```
┌──────────┬─────────────────────────────────────────────────────────────┬──────────┐
│ Finding  │ Vulnerability Description                                   │ Severity │
├──────────┼─────────────────────────────────────────────────────────────┼──────────┤
│ SEC-01   │ Small-PIN Offline Brute-Force Vulnerability                 │ HIGH     │
│ SEC-02   │ Biometric Authentication Unbound to Keystore CryptoObject  │ MEDIUM   │
│ SEC-03   │ Legacy Hive Binary Storage vs Synthetic JSON Migration Gap  │ LOW      │
│ SEC-04   │ Local-Only Isolation & Anti-Exfiltration Invariants Verified│ POSITIVE │
└──────────┴─────────────────────────────────────────────────────────────┴──────────┘
```

---

### Detailed Findings & Threat Model Analysis

#### SEC-01: Small-PIN Offline Brute-Force Vulnerability (HIGH SEVERITY)
- **Component:** `VaultPinManager`, `VaultCryptoEngine`, `VaultPreferencesDataStore`
- **Vulnerability Mechanism:**
  The Data Encryption Key (DEK) is encrypted with a Key Encryption Key (KEK) derived from a 3–6 digit PIN using PBKDF2-HMAC-SHA256 (100,000 iterations, 32-byte salt).
  The resulting encrypted envelope (`[Version(1)][IV(12)][Ciphertext+Tag]`) and `saltHex` are stored in plaintext DataStore preferences on flash storage.
- **Threat Vector:**
  If an adversary extracts device storage (via rooted device, physical read, debug ADB session, or local backup exploitation), they obtain `saltHex` and `encryptedDek`.
  Because the PIN search space is small:
  - 3 digits: 1,000 possibilities
  - 4 digits: 10,000 possibilities
  - 5 digits: 100,000 possibilities
  - 6 digits: 1,000,000 possibilities
  An attacker can execute an **offline dictionary attack**.
  Because AES-256-GCM uses a 128-bit authentication tag, incorrect PINs fail AEAD verification with probability $1 - 2^{-128}$, providing a 100% accurate oracle.
  On modern hardware (GPU/ASIC), 10,000 PBKDF2 iterations take less than 0.5 seconds.
  **Crucially, application-level rate limiting (5 attempts = 30s lockout) is completely bypassed during offline attacks**, as the application is not running and DataStore is never queried or updated.
- **Proof-of-Concept:**
  Implemented in `VaultSecurityAuditTest.kt` (`offline brute force vulnerability demonstration`), demonstrating automated offline recovery of a 4-digit PIN in seconds while `failedAttempts` remains 0.
- **Required Remediation (Sub-Phase 5.2):**
  Integrate Android Keystore hardware-backed wrapping (Master Key stored in TEE/StrongBox) so that the wrapping key material cannot be extracted from flash storage, preventing offline attacks without hardware access.

---

#### SEC-02: Biometric Authentication Unbound to Keystore CryptoObject (MEDIUM SEVERITY)
- **Component:** `BiometricAuthManager`, `VaultAuthCoordinator`
- **Vulnerability Mechanism:**
  `BiometricAuthManager.authenticate()` launches `BiometricPrompt` with prompt info only, rather than wrapping a `Cipher` or `SecretKey` generated with `setUserAuthenticationRequired(true)` via `BiometricPrompt.CryptoObject`. The DEK passed to `unlockWithBiometrics(dek)` is currently held or passed as raw bytes without hardware-gated authentication binding.
- **Threat Vector:**
  Biometric authentication provides UX confirmation but does not cryptographically gate the key in hardware (TEE/StrongBox). If the app process or memory is compromised, biometric prompt bypass could occur without cryptographic enforcement.
- **Required Remediation (Sub-Phase 5.2):**
  Bind biometric unlock to an Android Keystore key requiring biometric authorization.

---

#### SEC-03: Legacy Hive Binary Storage vs Synthetic JSON Migration Gap (LOW / INFORMATIONAL)
- **Component:** `LegacyVaultMigrationAdapter`
- **Vulnerability Mechanism:**
  `LegacyVaultMigrationAdapter` parses raw Maps (`List<Map<*, *>>`) or JSON arrays (`migrateLegacyJson`). However, on an actual device running Flutter, Hive stores records in `.hive` binary format (compact binary type-tagged records), not JSON files.
- **Threat Vector:**
  Migration works seamlessly if legacy data is exported to JSON or read through Hive engine bindings, but raw direct file ingestion of binary `.hive` files without Hive deserialization requires either the Hive format parser or an exported checkpoint.
- **Required Remediation (Sub-Phase 5.2):**
  Document the exact separation between synthetic JSON migration, Hive binary compatibility, and device migration; ensure source data is never deleted automatically.

---

#### SEC-04: Local-Only Isolation & Anti-Exfiltration Invariants Verified (POSITIVE INVARIANT)
- **Component:** `AndroidManifest.xml`, `data_extraction_rules.xml`, `ArcNavHost.kt`, `SecureVaultEffect.kt`
- **Verification:**
  1. `allowBackup="false"` and `fullBackupContent="false"` are declared in `AndroidManifest.xml`.
  2. `data_extraction_rules.xml` excludes all storage domains (`root`, `file`, `database`, `sharedpref`, `external`) from both cloud backup and device transfer.
  3. Dynamic window masking via `SecureVaultEffect` sets `FLAG_SECURE` whenever vault composables are rendered.
  4. Sensitive clipboard tagging (`ClipDescription.EXTRA_IS_SENSITIVE`) prevents clipboard preview leaks on Android 13+.
  5. In-memory DEK zeroing is verified upon session lock or app backgrounding.
