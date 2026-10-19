# Secret Notes & Secure Vault Security Audit and Threat Model

## 1. Executive Summary

As part of ARC's Flutter-to-Kotlin migration (Phase 4), this audit evaluates the security architecture of the legacy Flutter Secret Notes implementation (`C:\dev\ARC`), establishes an exhaustive threat model, and specifies the native Android cryptographic foundation for the encrypted vault in `C:\dev\ARC-Kotlin`.

---

## 2. Legacy Flutter Secret Notes Audit Findings

### 2.1 Storage & Encryption Mechanism
- **Legacy Storage:** Flutter stored notes in a local Hive box (`secret_notes_data`).
- **CRITICAL FINDING — PLAINTEXT AT-REST STORAGE:**
  In the legacy Flutter application, `SecretNotesCrypto.pbkdf2HmacSha256` was utilized **solely to derive a hash for PIN verification**. When persisting notes via `SecretNotesDataRepository.saveNote()`, the note object was converted to a plain map (`note.toMap()`) and saved directly into Hive without any cryptographic encryption.
- **Consequence:** The legacy PIN lock functioned exclusively as an **application-level UI gate**. The note titles, descriptions, and checklist items were stored in cleartext on disk. Anyone with physical access, ADB backup access, or root privileges could extract `secret_notes_data.hive` and read all confidential notes in plaintext.
- **Native Resolution:** ARC-Kotlin Phase 4 mandates **true at-rest authenticated encryption (`AES-256-GCM`)**. Note contents are never stored as plaintext in Room, DataStore, SharedPreferences, cache, or logs.

### 2.2 Previously Observed Issues & Root Cause Analysis

#### Issue 1: Biometric Authentication Prompting Twice on Vault Entry
- **Root Cause in Flutter:** In `secret_notes_unlock_screen.dart`, `_checkBiometrics()` was invoked asynchronously in `initState()`. Concurrent route-guard redirects from Riverpod state providers and multiple lifecycle observers simultaneously called `attemptBiometricUnlock()` without an atomic in-flight guard or centralized state machine.
- **Native Prevention:** Centralized `VaultAuthCoordinator` with strict state machine (`LOCKED`, `AUTHENTICATING`, `UNLOCKED`, `LOCKED_OUT`). An atomic boolean guard (`compareAndSet`) guarantees that exactly **one** BiometricPrompt is active at any time.

#### Issue 2: PIN Indicator Dots Displayed Before User Input
- **Root Cause in Flutter:** The PIN indicator widgets in setup and unlock screens were statically rendered or pre-populated with active dots before user keystrokes occurred.
- **Native Prevention:** The native Compose `VaultPinDots` component renders dynamic empty indicators (`○ ○ ○ ○ ○ ○`) based on the configured PIN length ($N \in [3, 6]$). Indicators fill incrementally (`● ● ● ○ ○ ○`) strictly in response to user input and immediately reset to empty upon clearing or error.

#### Issue 3: Variable PIN Length Support (3 to 6 Digits)
- **Root Cause in Flutter:** The service allowed `minPinLength = 3` and `maxPinLength = 6`, but the UI hardcoded 6 digits in multiple places (`maxLength: 6`, static 6-dot UI).
- **Security Considerations for Short PINs (3 Digits):**
  A 3-digit PIN contains only $10^3 = 1,000$ possible combinations ($\approx 10$ bits of entropy). If used directly as a raw key, it is trivially brute-forced in milliseconds.
- **Native Prevention:**
  1. Configurable PIN length from 3 to 6 digits supported natively in UI and storage.
  2. Display an explicit visual warning when a user selects $< 6$ digits.
  3. Strict, persistent exponential rate-limiting (throttling surviving app restarts).
  4. The low-entropy PIN is **never** used as the raw data encryption key; it acts as an authentication credential to unwrap a high-entropy 256-bit random Key Encryption Key (KEK) using PBKDF2 HMAC-SHA256 with 100,000 iterations and a 32-byte salt.

---

## 3. Comprehensive Security Threat Model

The following threat model assesses threats, risk levels, ARC mitigations, and platform boundaries:

| Threat / Attack Vector | Threat Actor / Scenario | Risk | ARC Native Mitigation | Platform Limitation / Assumption |
|---|---|---|---|---|
| **1. Unencrypted Disk Extraction** | Attacker accesses device filesystem via ADB, backup, or file explorer. | **CRITICAL** | Payloads encrypted using `AES-256-GCM`. Room stores only encrypted envelopes `[version \| IV \| ciphertext + tag]`. | Requires Android OS sandbox integrity. |
| **2. Low-Entropy PIN Brute-Force** | Attacker attempts repeated PIN entry on unlocked or stolen device. | **HIGH** | Persistent failed-attempt tracking in DataStore (5 failures: 30s lockout, 6 failures: 60s, >6: 120s). Survives process restart. PBKDF2 100,000 iterations slows offline attacks. | A 3-digit PIN remains inherently vulnerable if the attacker dumps memory; 6 digits strongly recommended. |
| **3. Memory Extraction / RAM Dump** | Attacker inspects memory while vault is active or suspended. | **HIGH** | Plaintext notes kept in memory only while vault session is active; cleared on auto-lock or backgrounding. | JVM `String` instances cannot be guaranteed zeroed due to string interning/garbage collection. |
| **4. Screen Capture / Recent Apps Leaks** | Malware, user screenshots, or Recent Apps task switcher expose secret notes. | **HIGH** | Dynamic `FLAG_SECURE` applied to `Window` while inside Vault destinations; cleared when navigating away. | Rooted devices or kernel-level capture tools can bypass `FLAG_SECURE`. |
| **5. Biometric Bypass / Enrollment Tampering** | Attacker enrolls a new fingerprint on an unlocked device to access vault. | **HIGH** | Biometric keys in Android Keystore configured with `setInvalidatedByBiometricEnrollment(true)`. Adding a new fingerprint invalidates the key. | Requires hardware-backed Android Keystore with biometric binding. |
| **6. Clipboard Snooping** | Third-party apps read clipboard after user copies secret note content. | **MEDIUM** | ARC does not provide auto-copy. Manual copy triggers an explicit security warning and sets `ClipDescription.EXTRA_IS_SENSITIVE`. | Android clipboard history apps may capture copied content before system clearing. |
| **7. Multi-User Cross-Access** | User switches accounts in dev auth; User B views User A's secret notes. | **HIGH** | Multi-user isolation enforced: Vault keys and Room entities partitioned by `ownerUid`. Switching user resets vault to locked. | Relies on ARC's auth repository user session integrity. |
| **8. Insecure Automatic PIN Reset** | Attacker triggers PIN reset to view encrypted notes. | **CRITICAL** | **Zero backdoor PIN resets.** Resetting a forgotten PIN wipes the local vault; it never decrypts existing ciphertext. | Users must be informed that forgotten PINs result in permanent loss of local notes. |
| **9. Accidental Cloud Sync Leakage** | Bug or sync queue uploads secret notes to Firestore or analytics. | **CRITICAL** | `SecretNote` entities have **no Firestore mapping, no cloud repository, no sync queue, and no network endpoints**. | Relies on architecture boundaries remaining local-only. |
| **10. Backup & Device Migration Leak** | Android Auto Backup or ADB backup extracts unencrypted notes to cloud/PC. | **HIGH** | Android backup excludes vault files and Keystore-wrapped metadata via `backup_rules.xml`. | User-mediated encrypted migration must be authenticated. |

---

## 4. Cryptographic Key Hierarchy

```
+-----------------------------------------------------------+
|                     Android Keystore                      |
|  Master Key: AES-256 (Hardware-backed / StrongBox where)  |
+-----------------------------------------------------------+
                             |
                             | (Wraps / Unwraps)
                             v
+-----------------------------------------------------------+
|              Vault Key Encryption Key (KEK)               |
|  Derived via PBKDF2-HMAC-SHA256 (100k iterations, salt)   |
|         OR Keystore Biometric-Bound CryptoObject          |
+-----------------------------------------------------------+
                             |
                             | (Protects)
                             v
+-----------------------------------------------------------+
|            Data Encryption Key (DEK) - 256-bit            |
|       Cryptographically secure random AES-256 key         |
+-----------------------------------------------------------+
                             |
                             | (Encrypts / Decrypts)
                             v
+-----------------------------------------------------------+
|                  Secret Note Envelope                     |
|  [Version: 1 byte][IV / Nonce: 12 bytes][Ciphertext + Tag] |
+-----------------------------------------------------------+
```

---

## 5. Security Conclusions & Review Requirements

1. **Non-Negotiable Rules Enforced:**
   - No plaintext storage of secret notes.
   - No cloud transmission of secret notes or PINs.
   - No floating-point math or unauthenticated cryptography.
   - Non-destructive Room migration (V3 -> V4).
2. **Independent Review Disclaimer:**
   Passing automated tests confirms algorithmic correctness and regression safety, but does not substitute for an independent third-party cryptographic code review or physical hardware penetration test.
