package com.arc.arc.vault

import com.arc.arc.core.database.SecretNoteEntity
import com.arc.arc.core.datastore.VaultConfig
import com.arc.arc.core.model.SecretNoteModel
import com.arc.arc.core.security.InMemoryMasterKeyProvider
import com.arc.arc.core.security.InvalidPinException
import com.arc.arc.core.security.VaultCryptoEngine
import com.arc.arc.core.security.VaultLockoutException
import com.arc.arc.core.security.VaultPinManager
import com.arc.arc.features.vault.data.ISecretNoteRepository
import com.arc.arc.features.vault.migration.LegacyVaultMigrationAdapter
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.security.GeneralSecurityException
import java.util.Base64

class VaultHardeningAndMigrationTest {

    private class FakeNoteRepository : ISecretNoteRepository {
        val notes = mutableMapOf<String, SecretNoteModel>()
        val rawEntities = mutableListOf<SecretNoteEntity>()

        override fun getNotesFlow(ownerUid: String, dek: ByteArray): Flow<List<SecretNoteModel>> =
            flowOf(notes.values.filter { it.ownerUid == ownerUid })

        override suspend fun getNotes(ownerUid: String, dek: ByteArray): List<SecretNoteModel> =
            notes.values.filter { it.ownerUid == ownerUid }

        override suspend fun getNoteById(id: String, ownerUid: String, dek: ByteArray): SecretNoteModel? =
            notes[id]?.takeIf { it.ownerUid == ownerUid }

        override suspend fun saveNote(note: SecretNoteModel, dek: ByteArray): Result<Unit> {
            notes[note.id] = note
            rawEntities.removeAll { it.id == note.id }
            rawEntities.add(SecretNoteEntity(note.id, note.ownerUid, "enc_title", "enc_payload", note.color, note.createdAt.time, note.updatedAt.time))
            return Result.success(Unit)
        }

        override suspend fun deleteNote(id: String, ownerUid: String): Result<Unit> {
            notes.remove(id)
            rawEntities.removeAll { it.id == id && it.ownerUid == ownerUid }
            return Result.success(Unit)
        }

        override suspend fun deleteAllForUser(ownerUid: String): Result<Unit> {
            notes.entries.removeIf { it.value.ownerUid == ownerUid }
            rawEntities.removeIf { it.ownerUid == ownerUid }
            return Result.success(Unit)
        }

        override suspend fun getNoteCount(ownerUid: String): Int =
            notes.values.count { it.ownerUid == ownerUid }

        override suspend fun getRawEntities(ownerUid: String): List<SecretNoteEntity> =
            rawEntities.filter { it.ownerUid == ownerUid }
    }

    private lateinit var dataStore: InMemoryVaultPreferencesDataStore
    private lateinit var masterKeyProvider: InMemoryMasterKeyProvider
    private lateinit var pinManager: VaultPinManager
    private lateinit var repository: FakeNoteRepository
    private lateinit var migrationAdapter: LegacyVaultMigrationAdapter

    @Before
    fun setup() {
        dataStore = InMemoryVaultPreferencesDataStore()
        masterKeyProvider = InMemoryMasterKeyProvider(isHardwareBacked = true)
        pinManager = VaultPinManager(dataStore, masterKeyProvider)
        repository = FakeNoteRepository()
        migrationAdapter = LegacyVaultMigrationAdapter(repository)
    }

    @Test
    fun `keystore backed V2 envelope blocks offline bruteforce attacks`() = runBlocking {
        val ownerUid = "victim_v2_user"
        val targetPin = "1357"

        // Setup PIN with Keystore master key provider
        val setupResult = pinManager.setupPin(ownerUid, targetPin, 4)
        assertTrue(setupResult.isSuccess)
        val trueDek = setupResult.getOrThrow()

        val config = dataStore.getVaultConfig(ownerUid)
        assertEquals("Config must use Format V2", VaultPinManager.FORMAT_VERSION_V2_KEYSTORE, config.formatVersion)

        // Offline attacker extracts salt and outer encrypted DEK from flash
        val extractedSalt = VaultCryptoEngine.hexToBytes(config.saltHex!!)
        val extractedOuterEnvelope = config.encryptedDek!!

        // Attacker attempts offline dictionary attack without access to the Keystore Master Key
        var offlineSuccess = false
        for (candidate in 1350..1360) {
            val candidatePin = candidate.toString()
            try {
                // Attacker attempts to derive KEK and decrypt directly (fails because outer layer is encrypted with Master Key)
                val candidateKek = VaultCryptoEngine.deriveKeyFromPin(candidatePin.toCharArray(), extractedSalt)
                VaultCryptoEngine.decryptFromString(extractedOuterEnvelope, candidateKek)
                offlineSuccess = true
                break
            } catch (e: GeneralSecurityException) {
                // Expected failure: outer envelope cannot be decrypted with PIN KEK
            }
        }

        assertFalse("Offline attacker must NOT be able to crack V2 envelope without hardware Master Key", offlineSuccess)

        // Verify that legitimate verification with provider succeeds
        val legitimateResult = pinManager.verifyPin(ownerUid, targetPin)
        assertTrue("Legitimate verification must succeed", legitimateResult.isSuccess)
        assertArrayEquals("Decrypted DEK must match true DEK", trueDek, legitimateResult.getOrThrow())
    }

    @Test
    fun `transparent automatic upgrade from V1 legacy envelope to V2 hardware bound envelope`() = runBlocking {
        val ownerUid = "legacy_upgrading_user"
        val pin = "4321"

        // Setup legacy V1 vault (null masterKeyProvider)
        val legacyPinManager = VaultPinManager(dataStore, null)
        val setupResult = legacyPinManager.setupPin(ownerUid, pin, 4)
        assertTrue(setupResult.isSuccess)
        val expectedDek = setupResult.getOrThrow()

        val v1Config = dataStore.getVaultConfig(ownerUid)
        assertEquals(VaultPinManager.FORMAT_VERSION_V1_PBKDF2, v1Config.formatVersion)

        // User unlocks after updating to modern app with masterKeyProvider
        val modernPinManager = VaultPinManager(dataStore, masterKeyProvider)
        val unlockResult = modernPinManager.verifyPin(ownerUid, pin)
        assertTrue(unlockResult.isSuccess)
        assertArrayEquals("Decrypted DEK must be preserved during upgrade", expectedDek, unlockResult.getOrThrow())

        // Verify config was automatically upgraded to V2 in-place
        val upgradedConfig = dataStore.getVaultConfig(ownerUid)
        assertEquals("Envelope must be upgraded to V2", VaultPinManager.FORMAT_VERSION_V2_KEYSTORE, upgradedConfig.formatVersion)

        // Subsequent unlock works seamlessly in V2 format
        val secondUnlock = modernPinManager.verifyPin(ownerUid, pin)
        assertTrue(secondUnlock.isSuccess)
        assertArrayEquals(expectedDek, secondUnlock.getOrThrow())
    }

    @Test
    fun `V2 to V1 rollback preserves DEK recoverability`() = runBlocking {
        val ownerUid = "rollback_user"
        val pin = "5555"

        val setupResult = pinManager.setupPin(ownerUid, pin, 4)
        val expectedDek = setupResult.getOrThrow()
        assertEquals(VaultPinManager.FORMAT_VERSION_V2_KEYSTORE, dataStore.getVaultConfig(ownerUid).formatVersion)

        // Rollback to V1
        val rollbackResult = pinManager.rollbackToV1(ownerUid, pin)
        assertTrue("Rollback must succeed", rollbackResult.isSuccess)

        val rolledBackConfig = dataStore.getVaultConfig(ownerUid)
        assertEquals(VaultPinManager.FORMAT_VERSION_V1_PBKDF2, rolledBackConfig.formatVersion)

        // Unlock with legacy V1 manager (no master key provider)
        val legacyPinManager = VaultPinManager(dataStore, null)
        val unlockResult = legacyPinManager.verifyPin(ownerUid, pin)
        assertTrue(unlockResult.isSuccess)
        assertArrayEquals(expectedDek, unlockResult.getOrThrow())
    }

    @Test
    fun `lockout persists across process restarts and resets upon correct PIN`() = runBlocking {
        val ownerUid = "lockout_persistence_user"
        val pin = "7890"
        pinManager.setupPin(ownerUid, pin, 4)

        val baseTime = 100_000L

        // Trigger 5 failed attempts
        repeat(5) {
            val res = pinManager.verifyPin(ownerUid, "0000", baseTime)
            assertTrue(res.isFailure)
        }

        // 6th attempt should be locked out
        val lockedResult = pinManager.verifyPin(ownerUid, pin, baseTime + 10_000L)
        assertTrue(lockedResult.isFailure)
        assertTrue(lockedResult.exceptionOrNull() is VaultLockoutException)

        // Simulate process death: create fresh VaultPinManager instance reading from same DataStore
        val freshPinManager = VaultPinManager(dataStore, masterKeyProvider)
        val postDeathResult = freshPinManager.verifyPin(ownerUid, pin, baseTime + 15_000L)
        assertTrue("Lockout must persist across process death", postDeathResult.isFailure)
        assertTrue(postDeathResult.exceptionOrNull() is VaultLockoutException)

        // Advance time past lockout (30s)
        val afterExpiryResult = freshPinManager.verifyPin(ownerUid, pin, baseTime + 35_000L)
        assertTrue("Correct PIN after lockout expiry must succeed", afterExpiryResult.isSuccess)

        // Verify attempts counter was reset
        assertEquals(0, dataStore.getVaultConfig(ownerUid).failedAttempts)
    }

    @Test
    fun `legacy migration handles duplicates, re-entry, and source preservation`() = runBlocking {
        val ownerUid = "mig_user_1"
        val dek = ByteArray(32) { (it + 1).toByte() }

        val noteMap1 = mapOf(
            "id" to "note_1",
            "title" to "Secret 1",
            "content" to "Content 1",
            "createdAt" to "2026-03-01T10:00:00.000Z",
            "updatedAt" to "2026-03-01T10:00:00.000Z",
            "color" to "charcoal"
        )
        val noteMap2 = mapOf(
            "id" to "note_2",
            "title" to "Secret 2",
            "content" to "Content 2",
            "createdAt" to "2026-03-01T11:00:00.000Z",
            "updatedAt" to "2026-03-01T11:00:00.000Z",
            "color" to "navy"
        )
        val rawBatch = listOf(noteMap1, noteMap2)

        // Initial migration
        val firstResult = migrationAdapter.migrateLegacyMaps(ownerUid, rawBatch, dek)
        assertEquals(2, firstResult.migratedCount)
        assertEquals(0, firstResult.skippedCount)
        assertTrue(firstResult.sourcePreserved)
        assertEquals(2, repository.getNoteCount(ownerUid))

        // Interrupted/Re-entry scenario: Re-running with note_1, note_2, and a new note_3
        val noteMap3 = mapOf(
            "id" to "note_3",
            "title" to "Secret 3",
            "content" to "Content 3",
            "createdAt" to "2026-03-01T12:00:00.000Z",
            "updatedAt" to "2026-03-01T12:00:00.000Z",
            "color" to "emerald"
        )
        val secondBatch = listOf(noteMap1, noteMap2, noteMap3)
        val secondResult = migrationAdapter.migrateLegacyMaps(ownerUid, secondBatch, dek)

        // Duplicate prevention: note_1 and note_2 skipped, only note_3 migrated
        assertEquals(1, secondResult.migratedCount)
        assertEquals(2, secondResult.skippedCount)
        assertEquals(3, repository.getNoteCount(ownerUid))
        assertTrue(secondResult.sourcePreserved)
    }

    @Test
    fun `legacy migration isolates corrupted entries without aborting entire batch`() = runBlocking {
        val ownerUid = "mig_user_corrupt"
        val dek = ByteArray(32) { (it + 5).toByte() }

        val validNote = mapOf(
            "id" to "valid_note",
            "title" to "Good Note",
            "content" to "Valid",
            "createdAt" to "2026-03-01T10:00:00.000Z",
            "updatedAt" to "2026-03-01T10:00:00.000Z",
            "color" to "charcoal"
        )
        val corruptEmptyNote = mapOf(
            "id" to "corrupt_note",
            "title" to "",
            "content" to "",
            "createdAt" to "2026-03-01T10:00:00.000Z",
            "updatedAt" to "2026-03-01T10:00:00.000Z"
        )

        val result = migrationAdapter.migrateLegacyMaps(ownerUid, listOf(validNote, corruptEmptyNote), dek)
        assertEquals(1, result.migratedCount)
        assertEquals(1, result.skippedCount)
        assertEquals(1, result.errors.size)
        assertTrue(result.errors[0].contains("Skipped invalid empty legacy note"))
    }

    @Test
    fun `legacy migration handles malformed JSON string gracefully`() = runBlocking {
        val ownerUid = "mig_user_bad_json"
        val dek = ByteArray(32) { 7 }

        val result = migrationAdapter.migrateLegacyJson(ownerUid, "{ this is not valid json ]", dek)
        assertEquals(0, result.migratedCount)
        assertEquals(1, result.errors.size)
        assertTrue(result.errors[0].contains("Malformed legacy JSON export"))
    }
}
