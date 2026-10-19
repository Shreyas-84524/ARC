# ARC Legacy Notes Migration Architecture

## 1. Legacy Hive Data Inspection

In the legacy Flutter application, secret notes were stored in a Hive box named `secret_notes_data`.
Each note was stored as a raw map:
```json
{
  "id": "note_1697200000000_123456",
  "title": "Confidential Note",
  "description": "Sensitive credentials",
  "color": "sky",
  "checklist": [
    {"id": "item_1", "text": "Rotate password", "isCompleted": true}
  ],
  "createdAt": "2026-09-15T10:30:00.000Z",
  "updatedAt": "2026-09-15T11:00:00.000Z"
}
```

**Critical Security Flaw:** The notes were stored in cleartext. The PIN check was only an application gate.

---

## 2. Migration Procedure & Adapter (`LegacyVaultMigrationAdapter`)

1. **Prerequisite:** The user must configure or enter their PIN to unlock or generate their native 256-bit DEK.
2. **Ingestion & Validation:** `LegacyVaultMigrationAdapter.migrateLegacyJson` parses the JSON array, validates non-empty status, and maps each entry to `SecretNoteModel`.
3. **Encrypted Persistence:** Every note is encrypted using `AES-256-GCM` with a unique random nonce and written to Room `secret_notes`.
4. **Post-Migration Cleansing:** Once encrypted in Room, the legacy Hive box / cleartext backup must be wiped to ensure no plaintext remnants exist in the sandbox.
5. **Data Fidelity:** 100% of legacy fields (`id`, `title`, `description`, `color`, `checklist`, `createdAt`, `updatedAt`) are preserved without loss.
