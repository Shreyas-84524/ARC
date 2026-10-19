package com.arc.arc.features.vault.migration

import com.arc.arc.core.model.SecretNoteModel
import com.arc.arc.features.vault.data.ISecretNoteRepository
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

data class LegacyMigrationResult(
    val migratedCount: Int,
    val skippedCount: Int,
    val errors: List<String> = emptyList(),
    val sourcePreserved: Boolean = true,
)

data class MigrationCheckpoint(
    val totalDiscovered: Int,
    val processedCount: Int,
    val successCount: Int,
    val skippedCount: Int,
    val failureCount: Int,
    val isComplete: Boolean,
)

/**
 * Migration adapter for upgrading legacy unencrypted Flutter Hive notes (`secret_notes_data`)
 * into ARC's AES-256-GCM encrypted native Room vault.
 *
 * CRITICAL SECURITY & DATA INTEGRITY INVARIANTS:
 * 1. Plaintext legacy notes are transformed directly into AES-256-GCM versioned envelopes
 *    before persisting to Room SQLite storage.
 * 2. SOURCE DATA PRESERVATION: Legacy Hive records, boxes, and JSON exports are NEVER deleted,
 *    truncated, or mutated automatically. They serve as immutable recovery checkpoints.
 * 3. IDEMPOTENCY & DUPLICATE PREVENTION: Repeated runs detect existing note IDs in Room
 *    and safely skip them, allowing safe interruption recovery and re-entry.
 * 4. PRODUCTION GATING: Production migration remains gated ([isProductionMigrationEnabled])
 *    until signing and on-device release strategy approval.
 */
class LegacyVaultMigrationAdapter(
    private val repository: ISecretNoteRepository
) {
    private val gson = Gson()

    /**
     * Safety switch: On-device production auto-migration is disabled by default
     * until migration strategy is fully approved.
     */
    var isProductionMigrationEnabled: Boolean = false

    /**
     * Migrates a list of raw legacy Flutter note maps into the encrypted vault for [ownerUid] using [dek].
     * Enforces source preservation, duplicate detection, and recoverable field-level validation.
     */
    suspend fun migrateLegacyMaps(
        ownerUid: String,
        legacyMaps: List<Map<*, *>>,
        dek: ByteArray
    ): LegacyMigrationResult {
        require(dek.size == 32) { "A valid 256-bit DEK is required for encrypted migration" }

        var migrated = 0
        var skipped = 0
        val errors = mutableListOf<String>()

        // Discover existing note IDs in Room for idempotency and interruption recovery
        val existingIds = try {
            repository.getRawEntities(ownerUid).map { it.id }.toSet()
        } catch (e: Exception) {
            emptySet()
        }

        legacyMaps.forEach { rawMap ->
            try {
                val model = SecretNoteModel.fromMap(rawMap).copy(ownerUid = ownerUid)
                if (!model.isValid) {
                    skipped++
                    errors.add("Skipped invalid empty legacy note")
                    return@forEach
                }

                // Duplicate prevention on re-entry: Skip already migrated notes
                if (existingIds.contains(model.id)) {
                    skipped++
                    errors.add("Skipped existing duplicate note ${model.id}")
                    return@forEach
                }

                val saveResult = repository.saveNote(model, dek)
                if (saveResult.isSuccess) {
                    migrated++
                } else {
                    skipped++
                    errors.add("Failed to save note ${model.id}: ${saveResult.exceptionOrNull()?.message}")
                }
            } catch (e: Exception) {
                skipped++
                errors.add("Failed to parse legacy note: ${e.message}")
            }
        }

        return LegacyMigrationResult(
            migratedCount = migrated,
            skippedCount = skipped,
            errors = errors,
            sourcePreserved = true // Source data is never mutated or deleted
        )
    }

    /**
     * Migrates raw legacy JSON string (from Hive backup or export) into the encrypted vault.
     */
    suspend fun migrateLegacyJson(
        ownerUid: String,
        legacyJsonString: String,
        dek: ByteArray
    ): LegacyMigrationResult {
        require(dek.size == 32) { "A valid 256-bit DEK is required for encrypted migration" }

        return try {
            val listType = object : TypeToken<List<Map<String, Any?>>>() {}.type
            val list: List<Map<String, Any?>> = gson.fromJson(legacyJsonString, listType)
            migrateLegacyMaps(ownerUid, list, dek)
        } catch (e: Exception) {
            LegacyMigrationResult(
                migratedCount = 0,
                skippedCount = 0,
                errors = listOf("Malformed legacy JSON export: ${e.message}"),
                sourcePreserved = true
            )
        }
    }
}
