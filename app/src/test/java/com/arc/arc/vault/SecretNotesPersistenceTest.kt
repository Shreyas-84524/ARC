package com.arc.arc.vault

import com.arc.arc.core.database.ArcDatabase
import com.arc.arc.core.database.SecretNoteEntity
import com.arc.arc.core.database.SecretNoteMappers.toEntity
import com.arc.arc.core.database.SecretNoteMappers.toModel
import com.arc.arc.core.model.SecretChecklistItemModel
import com.arc.arc.core.model.SecretNoteModel
import com.arc.arc.core.security.VaultCryptoEngine
import com.arc.arc.features.vault.data.ISecretNoteRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.security.GeneralSecurityException
import java.util.Date

/**
 * Test implementation of [ISecretNoteRepository] backed by an in-memory encrypted entity store.
 * Strictly enforces that entities in storage are encrypted using AES-256-GCM.
 */
class InMemorySecretNoteRepository : ISecretNoteRepository {
    private val entityStore = MutableStateFlow<Map<String, SecretNoteEntity>>(emptyMap())

    override fun getNotesFlow(ownerUid: String, dek: ByteArray): Flow<List<SecretNoteModel>> {
        return entityStore.map { map ->
            map.values
                .filter { it.ownerUid == ownerUid }
                .sortedByDescending { it.updatedAt }
                .mapNotNull { entity ->
                    runCatching { entity.toModel(dek) }.getOrNull()
                }
        }
    }

    override suspend fun getNotes(ownerUid: String, dek: ByteArray): List<SecretNoteModel> {
        return entityStore.value.values
            .filter { it.ownerUid == ownerUid }
            .sortedByDescending { it.updatedAt }
            .map { it.toModel(dek) }
    }

    override suspend fun getNoteById(id: String, ownerUid: String, dek: ByteArray): SecretNoteModel? {
        val entity = entityStore.value[id]?.takeIf { it.ownerUid == ownerUid } ?: return null
        return entity.toModel(dek)
    }

    override suspend fun saveNote(note: SecretNoteModel, dek: ByteArray): Result<Unit> {
        if (!note.isValid) {
            return Result.failure(IllegalArgumentException("Note must not be empty"))
        }
        val entity = note.toEntity(dek)
        val current = entityStore.value.toMutableMap()
        current[entity.id] = entity
        entityStore.value = current
        return Result.success(Unit)
    }

    override suspend fun deleteNote(id: String, ownerUid: String): Result<Unit> {
        val current = entityStore.value.toMutableMap()
        val existing = current[id]
        return if (existing != null && existing.ownerUid == ownerUid) {
            current.remove(id)
            entityStore.value = current
            Result.success(Unit)
        } else {
            Result.failure(NoSuchElementException("Note not found: $id"))
        }
    }

    override suspend fun deleteAllForUser(ownerUid: String): Result<Unit> {
        val current = entityStore.value.toMutableMap()
        val toRemove = current.filter { it.value.ownerUid == ownerUid }.keys
        toRemove.forEach { current.remove(it) }
        entityStore.value = current
        return Result.success(Unit)
    }

    override suspend fun getNoteCount(ownerUid: String): Int {
        return entityStore.value.values.count { it.ownerUid == ownerUid }
    }

    override suspend fun getRawEntities(ownerUid: String): List<SecretNoteEntity> {
        return entityStore.value.values.filter { it.ownerUid == ownerUid }
    }

    fun injectRawEntity(entity: SecretNoteEntity) {
        val current = entityStore.value.toMutableMap()
        current[entity.id] = entity
        entityStore.value = current
    }
}

class SecretNotesPersistenceTest {

    private lateinit var repository: InMemorySecretNoteRepository
    private lateinit var testDek: ByteArray
    private lateinit var otherUserDek: ByteArray

    @Before
    fun setUp() {
        repository = InMemorySecretNoteRepository()
        testDek = VaultCryptoEngine.generateDataEncryptionKey().encoded
        otherUserDek = VaultCryptoEngine.generateDataEncryptionKey().encoded
    }

    @Test
    fun testRoomMigrationV3ToV4Definition() {
        assertEquals(3, ArcDatabase.MIGRATION_3_4.startVersion)
        assertEquals(4, ArcDatabase.MIGRATION_3_4.endVersion)
    }

    @Test
    fun testSaveAndRetrieveSecretNote() = runTest {
        val note = SecretNoteModel(
            id = "note-1",
            ownerUid = "user-123",
            title = "Server Passphrase",
            description = "Master recovery seed for primary database cluster",
            color = "coral",
            checklist = listOf(
                SecretChecklistItemModel(id = "c1", text = "Rotate keys", isCompleted = true),
                SecretChecklistItemModel(id = "c2", text = "Verify replication", isCompleted = false)
            ),
            createdAt = Date(1700000000000L),
            updatedAt = Date(1700000500000L)
        )

        val saveResult = repository.saveNote(note, testDek)
        assertTrue(saveResult.isSuccess)

        val retrieved = repository.getNoteById("note-1", "user-123", testDek)
        assertNotNull(retrieved)
        assertEquals("Server Passphrase", retrieved?.title)
        assertEquals("Master recovery seed for primary database cluster", retrieved?.description)
        assertEquals("coral", retrieved?.color)
        assertEquals(2, retrieved?.checklist?.size)
        assertEquals("Rotate keys", retrieved?.checklist?.get(0)?.text)
        assertTrue(retrieved?.checklist?.get(0)?.isCompleted == true)
        assertEquals("Verify replication", retrieved?.checklist?.get(1)?.text)
        assertFalse(retrieved?.checklist?.get(1)?.isCompleted == true)
    }

    @Test
    fun testZeroPlaintextInPersistenceStorage() = runTest {
        val secretTitle = "Bank Swiss Account 987654"
        val secretBody = "Passcode: 4892-Omega-Bravo-Confidential"
        val secretItem = "Physical Safe Key Location: Behind Bookshelf"

        val note = SecretNoteModel(
            id = "note-classified",
            ownerUid = "user-123",
            title = secretTitle,
            description = secretBody,
            checklist = listOf(SecretChecklistItemModel(id = "item-1", text = secretItem))
        )

        repository.saveNote(note, testDek)

        val rawEntities = repository.getRawEntities("user-123")
        assertEquals(1, rawEntities.size)
        val entity = rawEntities.first()

        // Verify entity fields are encrypted Base64 strings, NOT containing sensitive plaintext
        assertFalse("Entity encryptedTitle must not leak title!", entity.encryptedTitle.contains(secretTitle))
        assertFalse("Entity encryptedPayload must not leak title!", entity.encryptedPayload.contains(secretTitle))
        assertFalse("Entity encryptedPayload must not leak body!", entity.encryptedPayload.contains(secretBody))
        assertFalse("Entity encryptedPayload must not leak checklist text!", entity.encryptedPayload.contains(secretItem))

        // Check that envelope header version is 0x01
        val decodedTitleEnvelope = java.util.Base64.getDecoder().decode(entity.encryptedTitle)
        assertEquals("Envelope version must be 1", 1.toByte(), decodedTitleEnvelope[0])
    }

    @Test
    fun testNonceUniquenessAcrossMultipleSaves() = runTest {
        val noteA = SecretNoteModel(
            id = "note-dup-1",
            ownerUid = "user-123",
            title = "Identical Title",
            description = "Identical Description"
        )
        val noteB = SecretNoteModel(
            id = "note-dup-2",
            ownerUid = "user-123",
            title = "Identical Title",
            description = "Identical Description"
        )

        repository.saveNote(noteA, testDek)
        repository.saveNote(noteB, testDek)

        val entities = repository.getRawEntities("user-123")
        assertEquals(2, entities.size)

        val entityA = entities.first { it.id == "note-dup-1" }
        val entityB = entities.first { it.id == "note-dup-2" }

        // Even with identical plaintext and identical key, ciphertexts MUST differ due to random IVs
        assertFalse("Titles must have unique ciphertexts", entityA.encryptedTitle == entityB.encryptedTitle)
        assertFalse("Payloads must have unique ciphertexts", entityA.encryptedPayload == entityB.encryptedPayload)
    }

    @Test
    fun testMultiUserIsolationEnforced() = runTest {
        val userANote = SecretNoteModel(
            id = "note-a",
            ownerUid = "user-alice",
            title = "Alice's Secret Journal",
            description = "Alice confidential"
        )
        val userBNote = SecretNoteModel(
            id = "note-b",
            ownerUid = "user-bob",
            title = "Bob's Crypto Keys",
            description = "Bob confidential"
        )

        repository.saveNote(userANote, testDek)
        repository.saveNote(userBNote, otherUserDek)

        // Alice attempts to read notes
        val aliceNotes = repository.getNotes("user-alice", testDek)
        assertEquals(1, aliceNotes.size)
        assertEquals("note-a", aliceNotes.first().id)
        assertNull(repository.getNoteById("note-b", "user-alice", testDek))

        // Bob attempts to read notes
        val bobNotes = repository.getNotes("user-bob", otherUserDek)
        assertEquals(1, bobNotes.size)
        assertEquals("note-b", bobNotes.first().id)
        assertNull(repository.getNoteById("note-a", "user-bob", otherUserDek))
    }

    @Test
    fun testWrongKeyThrowsSecurityException() = runTest {
        val note = SecretNoteModel(
            id = "note-secure",
            ownerUid = "user-123",
            title = "Classified",
            description = "Top Secret"
        )
        repository.saveNote(note, testDek)

        val wrongKey = VaultCryptoEngine.generateDataEncryptionKey().encoded

        try {
            repository.getNoteById("note-secure", "user-123", wrongKey)
            fail("Decryption with wrong key must throw GeneralSecurityException")
        } catch (_: GeneralSecurityException) {
            // Success: AEAD authentication tag rejected wrong key
        }
    }

    @Test
    fun testCorruptedCiphertextFailsAuthentication() = runTest {
        val note = SecretNoteModel(
            id = "note-tamper",
            ownerUid = "user-123",
            title = "Integrity Test",
            description = "Tamper check"
        )
        val entity = note.toEntity(testDek)

        // Corrupt a byte in the payload ciphertext
        val envelopeBytes = java.util.Base64.getDecoder().decode(entity.encryptedPayload)
        envelopeBytes[envelopeBytes.size - 5] = (envelopeBytes[envelopeBytes.size - 5].toInt() xor 0xFF).toByte()
        val tamperedPayload = java.util.Base64.getEncoder().encodeToString(envelopeBytes)

        val corruptedEntity = SecretNoteEntity(
            entity.id,
            entity.ownerUid,
            entity.encryptedTitle,
            tamperedPayload,
            entity.color,
            entity.createdAt,
            entity.updatedAt
        )

        repository.injectRawEntity(corruptedEntity)

        // Directly decrypting the corrupted entity must throw GeneralSecurityException
        try {
            corruptedEntity.toModel(testDek)
            fail("Corrupted entity must fail GCM authentication")
        } catch (_: GeneralSecurityException) {
            // Expected: AEAD tag failure
        }

        // Flow observation must gracefully filter out the corrupted record rather than crashing the app
        val notes = repository.getNotesFlow("user-123", testDek).first()
        assertTrue("Corrupted record should be filtered out from UI flow", notes.isEmpty())
    }

    @Test
    fun testDeleteAndCountOperations() = runTest {
        val note1 = SecretNoteModel(id = "n1", ownerUid = "user-1", title = "T1")
        val note2 = SecretNoteModel(id = "n2", ownerUid = "user-1", title = "T2")
        val note3 = SecretNoteModel(id = "n3", ownerUid = "user-2", title = "T3")

        repository.saveNote(note1, testDek)
        repository.saveNote(note2, testDek)
        repository.saveNote(note3, otherUserDek)

        assertEquals(2, repository.getNoteCount("user-1"))
        assertEquals(1, repository.getNoteCount("user-2"))

        // Delete note1
        val deleteResult = repository.deleteNote("n1", "user-1")
        assertTrue(deleteResult.isSuccess)
        assertEquals(1, repository.getNoteCount("user-1"))
        assertNull(repository.getNoteById("n1", "user-1", testDek))

        // Attempting to delete note3 under user-1 must fail
        val invalidDelete = repository.deleteNote("n3", "user-1")
        assertFalse(invalidDelete.isSuccess)

        // Wipe all notes for user-1
        repository.deleteAllForUser("user-1")
        assertEquals(0, repository.getNoteCount("user-1"))
        assertEquals(1, repository.getNoteCount("user-2")) // user-2 untouched
    }
}
