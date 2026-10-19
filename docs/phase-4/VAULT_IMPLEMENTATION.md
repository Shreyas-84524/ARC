# ARC Vault Implementation Architecture

## 1. Room Schema Version 4

The database was upgraded from Version 3 to Version 4 via migration `MIGRATION_3_4`:

```sql
CREATE TABLE IF NOT EXISTS `secret_notes` (
    `id` TEXT NOT NULL,
    `ownerUid` TEXT NOT NULL,
    `encryptedTitle` TEXT NOT NULL,
    `encryptedPayload` TEXT NOT NULL,
    `color` TEXT NOT NULL,
    `createdAt` INTEGER NOT NULL,
    `updatedAt` INTEGER NOT NULL,
    PRIMARY KEY(`id`)
);

CREATE INDEX IF NOT EXISTS `index_secret_notes_ownerUid` ON `secret_notes` (`ownerUid`);
CREATE INDEX IF NOT EXISTS `index_secret_notes_ownerUid_updatedAt` ON `secret_notes` (`ownerUid`, `updatedAt`);
```

- Schema verification exported to `app/schemas/com.arc.arc.core.database.ArcDatabase/4.json`.

---

## 2. Component Architecture

1. **Entity & DAO:**
   - `SecretNoteEntity.java`: Room persistence entity storing ciphertext envelopes.
   - `SecretNoteDao.java`: Reactive `Flow` queries filtered strictly by `ownerUid`.
2. **Mappers & Encryption:**
   - `SecretNoteMappers.kt`: Converts between in-memory `SecretNoteModel` and encrypted `SecretNoteEntity`.
3. **Data Source & Repository:**
   - `RoomSecretNoteDataSource.kt`: Local Room data source executing encrypted queries and table invalidation observation.
   - `OfflineFirstSecretNoteRepository.kt`: Repository layer managing encrypted persistence and multi-user isolation.
4. **State Machine & Coordinator:**
   - `VaultAuthCoordinator.kt`: Central state machine (`Unconfigured`, `Locked`, `Authenticating`, `Unlocked`, `LockedOut`).
5. **UI Layer:**
   - `VaultPinDots.kt`: Dynamic indicator rendering.
   - `VaultNumericKeypad.kt`: On-screen numeric touch pad.
   - `VaultUnlockScreen.kt`: Unlock gate with lockout banner and error feedback.
   - `VaultPinSetupScreen.kt`: PIN creation and confirmation.
   - `SecretNoteCard.kt`: Decrypted note card with checklist progress.
   - `SecretNotesScreen.kt`: Decrypted notes dashboard with search and color filters.
   - `SecretNoteEditorScreen.kt`: Note composition and checklist editing.
   - `SecretNotesViewModel.kt`: MVVM UDF presentation logic.
   - `VaultRoute.kt`: Top-level route applying `SecureVaultEffect` and auto-lock disposal.
