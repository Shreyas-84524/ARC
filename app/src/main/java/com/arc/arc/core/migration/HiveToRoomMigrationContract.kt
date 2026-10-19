package com.arc.arc.core.migration

/**
 * Interface contract for future deterministic, transactional, idempotent
 * migration from legacy Hive storage to native Room databases.
 *
 * SAFETY RULES FOR LATER PHASES:
 * 1. Do NOT mutate or delete original Hive boxes during migration.
 * 2. Migration must execute in a single transactional unit per user.
 * 3. All record IDs and timestamps must be strictly verified.
 * 4. Migration is idempotent: re-running on existing data produces identical state without duplicate records.
 * 5. Rollback restores previous state if any step fails.
 */
interface IHiveToRoomMigrator {

    data class MigrationPlan(
        val ownerUid: String,
        val estimatedTaskCount: Int,
        val estimatedHabitCount: Int,
        val estimatedTransactionCount: Int,
        val sourceFingerprint: String,
    )

    data class MigrationResult(
        val success: Boolean,
        val tasksMigrated: Int = 0,
        val habitsMigrated: Int = 0,
        val transactionsMigrated: Int = 0,
        val errors: List<String> = emptyList(),
        val executionTimeMs: Long = 0,
    )

    /**
     * Inspects legacy Hive boxes without mutating them and prepares a migration plan.
     */
    suspend fun planMigration(ownerUid: String): MigrationPlan

    /**
     * Executes the transactional migration according to the plan.
     */
    suspend fun executeMigration(ownerUid: String, plan: MigrationPlan): MigrationResult

    /**
     * Verifies data integrity between source Hive records and target Room records.
     */
    suspend fun verifyIntegrity(ownerUid: String): Boolean
}
