# Phase 5 Vault Hardening & Migration Safeguards Results

## 1. Threat Model & Key Protection Hardening

### The Small-PIN Offline Brute-Force Threat
In Phase 4, the vault used PBKDF2-HMAC-SHA256 (100,000 iterations, 32-byte salt) to derive a Key Encryption Key (KEK) directly from a 3–6 digit PIN.
Because the total search space of a 3-to-6 digit PIN is at most $10^6$ combinations, extracting `saltHex` and `encryptedDek` from flash storage allows an adversary to mount an **offline dictionary attack**.
Application-level rate limiting in DataStore is completely bypassed because the attack runs outside the Android runtime without updating preferences.

### The Keystore-Backed V2 Envelope Architecture
To neutralize this threat, Phase 5 introduces a dual-layer hardware-bound wrapping envelope:
1. **Inner Layer (Knowledge Factor):** The Data Encryption Key (DEK) is encrypted with the user's PIN-derived KEK (PBKDF2 HMAC-SHA256).
2. **Outer Layer (Hardware Possession Factor):** The resulting inner envelope is encrypted with an AES-256-GCM Master Key (`arc_vault_mk_${ownerUid}`) rooted in the **Android Keystore (hardware TEE / StrongBox)**.

```
+-----------------------------------------------------------------------------------+
| Vault Key Envelope Format V2 (Hardware-Bound)                                     |
|                                                                                   |
|  [ Outer AES-256-GCM Envelope (Encrypted with Keystore Master Key in TEE) ]       |
|    |                                                                              |
|    +---> [ Inner AES-256-GCM Envelope (Encrypted with PBKDF2 PIN-derived KEK) ]  |
|            |                                                                      |
|            +---> [ Raw 256-bit AES Data Encryption Key (DEK) ]                    |
+-----------------------------------------------------------------------------------+
```

### Security Properties
- **Zero Offline Exposure:** If flash storage is extracted or leaked through backups, the attacker possesses the outer ciphertext, but CANNOT decrypt it because the Master Key is hardware-isolated in the TEE/StrongBox. The attacker cannot even reach the inner layer to evaluate PBKDF2 candidates.
- **Two-Factor Protection:** Decrypting the vault strictly requires both factors:
  1. Physical possession of the enrolled device with intact hardware Keystore key.
  2. Knowledge of the user PIN.

---

## 2. Envelope Versioning & Seamless Migration

- **Format V1 (Legacy PBKDF2):** Supported for backward compatibility with development Phase 4 records.
- **Format V2 (Hardware-Bound Keystore):** Default format for all new setups and upgraded vaults.
- **Transparent Upgrade:** Upon successful PIN entry of a V1 vault, `VaultPinManager` automatically derives new salts, wraps the DEK in the V2 dual-layer envelope, and updates the DataStore record in-place.
- **Rollback & Failure Recovery:**
  - If the V2 upgrade encounters a Keystore exception, it gracefully catches the error and preserves the existing V1 configuration without interrupting the user's unlocked session.
  - An explicit rollback method (`rollbackToV1`) is verified for recovery testing.

---

## 3. Legacy Hive Notes Migration Safeguards

### Audited Finding from Original Flutter Source
Inspection of `C:\dev\ARC\lib\features\secret_notes\repositories\secret_notes_data_repository.dart` confirmed that Flutter persisted secret notes as unencrypted maps in a Hive box (`secret_notes_data`).

### Production Safety Safeguards
1. **Source Data Preservation Invariant:** The legacy Hive box and exported JSON files are **NEVER deleted, modified, or truncated** during migration. They remain intact as immutable recovery checkpoints.
2. **Idempotency & Duplicate Prevention:** `LegacyVaultMigrationAdapter` checks existing note IDs in Room SQLite prior to insertion. On repeated runs or after process interruptions, already migrated notes are safely skipped.
3. **Fault Isolation:** Corrupted or empty legacy entries are isolated and recorded in the migration log without aborting the batch.
4. **Production Gating:** `isProductionMigrationEnabled` remains set to `false` by default until the full production signing and update strategy is authorized.

---

## 4. Test Verification Matrix

All hardening mechanisms are validated by automated unit tests in `VaultHardeningAndMigrationTest.kt`:
1. `keystore backed V2 envelope blocks offline bruteforce attacks` - Verified
2. `transparent automatic upgrade from V1 legacy envelope to V2 hardware bound envelope` - Verified
3. `V2 to V1 rollback preserves DEK recoverability` - Verified
4. `lockout persists across process restarts and resets upon correct PIN` - Verified
5. `legacy migration handles duplicates, re-entry, and source preservation` - Verified
6. `legacy migration isolates corrupted entries without aborting entire batch` - Verified
7. `legacy migration handles malformed JSON string gracefully` - Verified

---

## 5. Unresolved Risks & Prerequisites for Pilot
- **Device Lock Removal:** If a user completely removes their device lock screen or clears Keystore credentials, hardware-bound master keys may be invalidated by Android OS policy. A secure recovery flow must be documented in user-facing setup.
- **Cross-Device Backup Limitation:** Because Keystore master keys are bound to device hardware, encrypted vaults cannot be restored onto another device simply by copying DataStore files. An encrypted manual export mechanism is planned for future phases.
