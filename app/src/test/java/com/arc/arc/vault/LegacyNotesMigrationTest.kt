package com.arc.arc.vault

import com.arc.arc.core.security.VaultCryptoEngine
import com.arc.arc.features.vault.migration.LegacyVaultMigrationAdapter
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

class LegacyNotesMigrationTest {

    private lateinit var repository: InMemorySecretNoteRepository
    private lateinit var adapter: LegacyVaultMigrationAdapter
    private lateinit var dek: ByteArray

    private val ownerUid = "migrated-user-123"

    @Before
    fun setUp() {
        repository = InMemorySecretNoteRepository()
        adapter = LegacyVaultMigrationAdapter(repository)
        dek = VaultCryptoEngine.generateDataEncryptionKey().encoded
    }

    @Test
    fun testMigrateLegacyFlutterNotesJson() = runTest {
        val legacyJson = """
            [
              {
                "id": "legacy_note_1",
                "title": "Legacy Passport Info",
                "description": "Passport Number: A12345678, Expiry: 2030",
                "color": "sky",
                "checklist": [
                  {"id": "item_1", "text": "Scan visa pages", "isCompleted": true},
                  {"id": "item_2", "text": "Print flight tickets", "isCompleted": false}
                ],
                "createdAt": "2026-09-15T10:30:00.000Z",
                "updatedAt": "2026-09-15T11:00:00.000Z"
              },
              {
                "id": "legacy_note_2",
                "title": "Crypto Seed Phrase",
                "description": "Alpha Bravo Charlie Delta",
                "color": "amber",
                "checklist": [],
                "createdAt": "2026-09-20T14:15:00.000Z",
                "updatedAt": "2026-09-20T14:15:00.000Z"
              }
            ]
        """.trimIndent()

        val result = adapter.migrateLegacyJson(ownerUid, legacyJson, dek)
        assertEquals(2, result.migratedCount)
        assertEquals(0, result.skippedCount)
        assertTrue(result.errors.isEmpty())

        // Verify storage in Room contains ZERO plaintext
        val rawEntities = repository.getRawEntities(ownerUid)
        assertEquals(2, rawEntities.size)

        rawEntities.forEach { entity ->
            assertFalse(entity.encryptedTitle.contains("Passport"))
            assertFalse(entity.encryptedTitle.contains("Crypto"))
            assertFalse(entity.encryptedPayload.contains("A12345678"))
            assertFalse(entity.encryptedPayload.contains("Charlie"))
        }

        // Verify decrypted notes match legacy data exactly
        val decryptedNotes = repository.getNotes(ownerUid, dek)
        assertEquals(2, decryptedNotes.size)

        val note1 = decryptedNotes.first { it.id == "legacy_note_1" }
        assertEquals("Legacy Passport Info", note1.title)
        assertEquals("Passport Number: A12345678, Expiry: 2030", note1.description)
        assertEquals("sky", note1.color)
        assertEquals(2, note1.checklist.size)
        assertTrue(note1.checklist[0].isCompleted)
        assertFalse(note1.checklist[1].isCompleted)

        val note2 = decryptedNotes.first { it.id == "legacy_note_2" }
        assertEquals("Crypto Seed Phrase", note2.title)
        assertEquals("Alpha Bravo Charlie Delta", note2.description)
        assertEquals("amber", note2.color)
    }

    @Test
    fun testMigrateMalformedJsonReturnsGracefulError() = runTest {
        val malformedJson = "{ invalid json content }"
        val result = adapter.migrateLegacyJson(ownerUid, malformedJson, dek)

        assertEquals(0, result.migratedCount)
        assertEquals(1, result.errors.size)
        assertTrue(result.errors.first().contains("Malformed legacy JSON"))
    }

    @Test
    fun testInvalidDekLengthRejectsMigration() = runTest {
        val invalidDek = ByteArray(16) // 128-bit key instead of required 256-bit

        try {
            adapter.migrateLegacyJson(ownerUid, "[]", invalidDek)
            fail("Should throw IllegalArgumentException when DEK length is not 32 bytes")
        } catch (_: IllegalArgumentException) {
            // Expected
        }
    }
}
