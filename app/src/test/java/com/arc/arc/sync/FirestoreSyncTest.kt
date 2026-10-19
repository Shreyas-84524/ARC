package com.arc.arc.sync

import com.arc.arc.core.sync.FirestoreSyncManager
import com.arc.arc.core.sync.SyncMutation
import com.arc.arc.core.sync.SyncMutationType
import com.arc.arc.core.sync.SyncStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Architectural tests verifying Cloud Firestore synchronization boundaries,
 * queueing logic, and strict Zero-Cloud Vault guarantees.
 */
class FirestoreSyncTest {

    @Test
    fun testZeroCloudVaultArchitecturalInvariantThrowsSecurityException() {
        // Strict invariant: Secret Notes and Vault data must NEVER enter cloud sync
        val forbiddenCollections = listOf(
            "secret_notes",
            "secret_notes_data",
            "secret_notes_security",
            "secret_notes_preferences",
            "vault_keys",
            "encrypted_vault",
            "notes_vault"
        )

        for (col in forbiddenCollections) {
            val ex = assertThrows(SecurityException::class.java) {
                FirestoreSyncManager.assertVaultExcluded(col)
            }
            assertTrue(
                "Exception message must mention architectural invariant violation",
                ex.message?.contains("ARCHITECTURAL INVARIANT VIOLATION") == true
            )
        }
    }

    @Test
    fun testAllowedCollectionsSucceed() {
        val allowed = listOf(
            FirestoreSyncManager.COL_TASKS,
            FirestoreSyncManager.COL_HABITS,
            FirestoreSyncManager.COL_HABIT_ENTRIES,
            FirestoreSyncManager.COL_TRANSACTIONS,
            FirestoreSyncManager.COL_BUDGETS,
            FirestoreSyncManager.COL_SETTINGS
        )

        for (col in allowed) {
            // Must not throw any exception
            FirestoreSyncManager.assertVaultExcluded(col)
        }
    }

    @Test
    fun testUnknownCollectionThrowsIllegalArgumentException() {
        assertThrows(IllegalArgumentException::class.java) {
            FirestoreSyncManager.assertVaultExcluded("unknown_unsupported_collection")
        }
    }

    @Test
    fun testSyncMutationQueueModel() {
        val mutation = SyncMutation(
            id = "mut_1",
            collection = FirestoreSyncManager.COL_TASKS,
            docId = "task_123",
            type = SyncMutationType.UPSERT,
            payload = mapOf("title" to "Buy groceries", "completed" to false),
            timestamp = 1000L,
            retryCount = 0,
        )

        assertEquals("mut_1", mutation.id)
        assertEquals("tasks", mutation.collection)
        assertEquals("task_123", mutation.docId)
        assertEquals(SyncMutationType.UPSERT, mutation.type)
        assertEquals(0, mutation.retryCount)
    }

    @Test
    fun testSyncStatusEnumCompleteness() {
        val statuses = SyncStatus.values().map { it.name }.toSet()
        assertTrue(statuses.contains("IDLE"))
        assertTrue(statuses.contains("SYNCING"))
        assertTrue(statuses.contains("SUCCESS"))
        assertTrue(statuses.contains("ERROR"))
        assertTrue(statuses.contains("OFFLINE"))
    }
}
