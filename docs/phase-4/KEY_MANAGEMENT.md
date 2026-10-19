# ARC Vault Key Management & Lifecycle

## 1. Key Hierarchy

The vault separates the **User Authentication Credential (PIN)** from the **Data Encryption Key (DEK)**:

```
[ User PIN (3-6 Digits) ] + [ 32-Byte Random Salt ]
                 |
                 | (PBKDF2 HMAC-SHA256, 100,000 iterations)
                 v
   [ Key Encryption Key (KEK) - 256 bits ]
                 |
                 | (AES-256-GCM Unwraps)
                 v
   [ Data Encryption Key (DEK) - 256 bits ]
                 |
                 | (AES-256-GCM Decrypts)
                 v
    [ Plaintext Note Data in RAM ]
```

---

## 2. Key Separation Benefits

1. **Zero Raw PIN Decryption:**
   The PIN is never used directly to encrypt notes. This allows changing the PIN without re-encrypting all database rows.
2. **Seamless PIN Change:**
   Changing the PIN un-wraps the DEK using the old KEK, derives a new KEK from the new PIN + new salt, and re-encrypts only the 32-byte DEK envelope. The hundreds of encrypted note records in SQLite remain untouched.
3. **Biometric Dual-Wrapping:**
   Biometrics can wrap the same 256-bit DEK using an Android Keystore biometric-bound key, allowing either biometric or PIN unlock to access the identical notes.

---

## 3. In-Memory Key Zeroing & Ephemeral Session

- The 32-byte DEK exists in memory **only** while `VaultAuthState.Unlocked` is active.
- When `lock()` is called (via explicit user tap, background auto-lock, timeout, or account switch), `Arrays.fill(activeDek, 0.toByte())` actively overwrites the byte array with zeroes in heap memory.
- `VaultAuthState.Unlocked.toString()` explicitly redacts the key (`activeDek=[REDACTED]`) to prevent accidental leakage in logs.
