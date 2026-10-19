package com.arc.arc.vault

import com.arc.arc.core.model.SecretChecklistItemModel
import com.arc.arc.core.model.SecretNoteModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

/**
 * Validates 100% schema compatibility between Kotlin [SecretNoteModel]
 * and the legacy Flutter Secret Notes implementation.
 */
class SecretNoteContractTest {

    @Test
    fun secretNote_serialization_preservesAllLegacyFields() {
        val now = Date(1760000000000L)
        val checklist = listOf(
            SecretChecklistItemModel(
                id = "item-1",
                text = "Backup recovery phrase",
                isCompleted = true,
                createdAt = now,
                order = 0,
            ),
            SecretChecklistItemModel(
                id = "item-2",
                text = "Destroy temporary scratchpad",
                isCompleted = false,
                createdAt = now,
                order = 1,
            )
        )

        val note = SecretNoteModel(
            id = "note_1760000000_123456",
            ownerUid = "dev_uid_shreyas",
            title = "Hardware Wallet Seed",
            description = "Confidential backup stored in vault",
            color = "emerald",
            checklist = checklist,
            createdAt = now,
            updatedAt = now,
        )

        val map = note.toMap()
        assertEquals("note_1760000000_123456", map["id"])
        assertEquals("dev_uid_shreyas", map["ownerUid"])
        assertEquals("Hardware Wallet Seed", map["title"])
        assertEquals("Confidential backup stored in vault", map["description"])
        assertEquals("emerald", map["color"])

        val deserialized = SecretNoteModel.fromMap(map)
        assertEquals(note.id, deserialized.id)
        assertEquals(note.ownerUid, deserialized.ownerUid)
        assertEquals(note.title, deserialized.title)
        assertEquals(note.description, deserialized.description)
        assertEquals(note.color, deserialized.color)
        assertEquals(2, deserialized.checklist.size)
        assertEquals("Backup recovery phrase", deserialized.checklist[0].text)
        assertTrue(deserialized.checklist[0].isCompleted)
        assertEquals("Destroy temporary scratchpad", deserialized.checklist[1].text)
        assertFalse(deserialized.checklist[1].isCompleted)
    }

    @Test
    fun secretNote_jsonRoundTrip_preservesContentAndChecklists() {
        val note = SecretNoteModel(
            id = "note_test_json",
            ownerUid = "dev_uid_aman",
            title = "Server Root Key",
            description = "SSH Ed25519 public fingerprint and instructions",
            color = "purple",
            checklist = listOf(
                SecretChecklistItemModel(id = "c1", text = "Rotate monthly", isCompleted = false, order = 0)
            )
        )

        val jsonString = note.toJson()
        val parsed = SecretNoteModel.fromJson(jsonString)

        assertEquals(note.id, parsed.id)
        assertEquals(note.ownerUid, parsed.ownerUid)
        assertEquals(note.title, parsed.title)
        assertEquals(note.description, parsed.description)
        assertEquals(note.color, parsed.color)
        assertEquals(1, parsed.checklist.size)
        assertEquals("Rotate monthly", parsed.checklist.first().text)
    }

    @Test
    fun secretNote_validity_acceptsValidAndRejectsEmpty() {
        // Valid: Title only
        assertTrue(SecretNoteModel(title = "Passphrase").isValid)

        // Valid: Description only
        assertTrue(SecretNoteModel(description = "Confidential text").isValid)

        // Valid: Checklist item only
        assertTrue(
            SecretNoteModel(
                checklist = listOf(SecretChecklistItemModel(text = "Task item"))
            ).isValid
        )

        // Invalid: Empty or whitespace only
        assertFalse(SecretNoteModel(title = "   ", description = "   ", checklist = emptyList()).isValid)

        // Invalid: Empty checklist items
        assertFalse(
            SecretNoteModel(
                title = "",
                description = "",
                checklist = listOf(SecretChecklistItemModel(text = "   "))
            ).isValid
        )
    }

    @Test
    fun secretNote_fromLegacyFlutterMap_handlesMissingChecklistGracefully() {
        // Phase 2 legacy Flutter note without 'checklist' field
        val legacyMap = mapOf<String, Any?>(
            "id" to "legacy_note_123",
            "title" to "Old Note Title",
            "description" to "Saved before checklists existed",
            "color" to "sky",
            "createdAt" to "2026-10-13T10:00:00.000Z",
            "updatedAt" to "2026-10-13T10:05:00.000Z",
        )

        val note = SecretNoteModel.fromMap(legacyMap)
        assertEquals("legacy_note_123", note.id)
        assertEquals("Old Note Title", note.title)
        assertTrue(note.checklist.isEmpty())
        assertTrue(note.isValid)
    }

    @Test
    fun secretNote_corruptedChecklistItems_isolatedGracefully() {
        val mapWithCorruptedItem = mapOf<String, Any?>(
            "id" to "note_corrupted_items",
            "title" to "Resilient Note",
            "checklist" to listOf(
                mapOf("id" to "item-valid", "text" to "Valid item", "isCompleted" to true),
                "corrupted-string-not-a-map",
                42,
            )
        )

        val note = SecretNoteModel.fromMap(mapWithCorruptedItem)
        assertEquals(1, note.checklist.size)
        assertEquals("Valid item", note.checklist.first().text)
    }
}
