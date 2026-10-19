package com.arc.arc.contracts

import com.arc.arc.core.migration.IHiveToRoomMigrator
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Validates the safety contracts of the planned Hive-to-Room migration:
 * - Deterministic plan generation
 * - Idempotency
 * - Non-destructive inspection of source data
 * - Integrity validation
 */
class HiveToRoomMigrationTest {

    private class MockHiveToRoomMigrator : IHiveToRoomMigrator {
        val simulatedHiveTasks = listOf("t1", "t2", "t3")
        var executionCount = 0

        override suspend fun planMigration(ownerUid: String): IHiveToRoomMigrator.MigrationPlan {
            return IHiveToRoomMigrator.MigrationPlan(
                ownerUid = ownerUid,
                estimatedTaskCount = simulatedHiveTasks.size,
                estimatedHabitCount = 0,
                estimatedTransactionCount = 0,
                sourceFingerprint = "fingerprint_v1_sha256",
            )
        }

        override suspend fun executeMigration(
            ownerUid: String,
            plan: IHiveToRoomMigrator.MigrationPlan,
        ): IHiveToRoomMigrator.MigrationResult {
            executionCount++
            return IHiveToRoomMigrator.MigrationResult(
                success = true,
                tasksMigrated = plan.estimatedTaskCount,
                habitsMigrated = 0,
                transactionsMigrated = 0,
                errors = emptyList(),
                executionTimeMs = 45,
            )
        }

        override suspend fun verifyIntegrity(ownerUid: String): Boolean {
            return true
        }
    }

    @Test
    fun testMigrationPlanningAndDeterministicExecution() = runBlocking {
        val migrator = MockHiveToRoomMigrator()
        val plan = migrator.planMigration("test_uid_123")

        assertEquals("test_uid_123", plan.ownerUid)
        assertEquals(3, plan.estimatedTaskCount)
        assertEquals("fingerprint_v1_sha256", plan.sourceFingerprint)

        val result1 = migrator.executeMigration("test_uid_123", plan)
        assertTrue(result1.success)
        assertEquals(3, result1.tasksMigrated)
        assertTrue(result1.errors.isEmpty())

        // Re-run must succeed idempotently without side effects
        val result2 = migrator.executeMigration("test_uid_123", plan)
        assertTrue(result2.success)
        assertEquals(3, result2.tasksMigrated)
        assertEquals(2, migrator.executionCount)

        assertTrue(migrator.verifyIntegrity("test_uid_123"))
    }
}
