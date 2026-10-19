package com.arc.arc.migration

import com.arc.arc.core.database.ArcDatabase
import com.arc.arc.core.database.BudgetDao
import com.arc.arc.core.database.BudgetEntity
import com.arc.arc.core.database.HabitDao
import com.arc.arc.core.database.HabitEntity
import com.arc.arc.core.database.HabitEntryEntity
import com.arc.arc.core.database.SecretNoteDao
import com.arc.arc.core.database.TaskDao
import com.arc.arc.core.database.TaskEntity
import com.arc.arc.core.database.TransactionDao
import com.arc.arc.core.database.TransactionEntity
import com.arc.arc.core.migration.HiveToRoomMigrator
import com.arc.arc.core.migration.LegacyHiveSnapshot
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class HiveToRoomMigrationTest {

    private val testDispatcher = StandardTestDispatcher()

    // Test in-memory DAOs
    private class TestTaskDao : TaskDao {
        val tasks = mutableMapOf<String, TaskEntity>()
        override fun insert(task: TaskEntity) { tasks[task.id] = task }
        override fun insertAll(list: List<TaskEntity>) { list.forEach { tasks[it.id] = it } }
        override fun update(task: TaskEntity) { tasks[task.id] = task }
        override fun deleteById(id: String, ownerUid: String): Int = if (tasks.remove(id) != null) 1 else 0
        override fun deleteAllForUser(ownerUid: String): Int {
            val count = tasks.values.count { it.ownerUid == ownerUid }
            tasks.values.removeAll { it.ownerUid == ownerUid }
            return count
        }
        override fun getById(id: String, ownerUid: String): TaskEntity? = tasks[id]?.takeIf { it.ownerUid == ownerUid }
        override fun getAllForUser(ownerUid: String): List<TaskEntity> = tasks.values.filter { it.ownerUid == ownerUid }
        override fun getPendingForUser(ownerUid: String): List<TaskEntity> = tasks.values.filter { it.ownerUid == ownerUid && !it.completed }
        override fun getCompletedForUser(ownerUid: String): List<TaskEntity> = tasks.values.filter { it.ownerUid == ownerUid && it.completed }
        override fun getTaskCountForUser(ownerUid: String): Int = tasks.values.count { it.ownerUid == ownerUid }
    }

    private class TestHabitDao : HabitDao {
        val habits = mutableMapOf<String, HabitEntity>()
        val entries = mutableMapOf<String, HabitEntryEntity>()

        override fun insertHabit(habit: HabitEntity) { habits[habit.id] = habit }
        override fun insertAllHabits(list: List<HabitEntity>) { list.forEach { habits[it.id] = it } }
        override fun updateHabit(habit: HabitEntity) { habits[habit.id] = habit }
        override fun deleteHabitById(id: String, ownerUid: String): Int = if (habits.remove(id) != null) 1 else 0
        override fun deleteAllHabitsForUser(ownerUid: String): Int {
            val c = habits.values.count { it.ownerUid == ownerUid }
            habits.values.removeAll { it.ownerUid == ownerUid }
            return c
        }
        override fun getHabitById(id: String, ownerUid: String): HabitEntity? = habits[id]?.takeIf { it.ownerUid == ownerUid }
        override fun getAllHabitsForUser(ownerUid: String): List<HabitEntity> = habits.values.filter { it.ownerUid == ownerUid }
        override fun getHabitCountForUser(ownerUid: String): Int = habits.values.count { it.ownerUid == ownerUid }

        override fun insertEntry(entry: HabitEntryEntity) { entries[entry.id] = entry }
        override fun insertAllEntries(list: List<HabitEntryEntity>) { list.forEach { entries[it.id] = it } }
        override fun deleteEntryById(entryId: String, ownerUid: String): Int = if (entries.remove(entryId) != null) 1 else 0
        override fun deleteEntriesForHabit(habitId: String, ownerUid: String): Int {
            val c = entries.values.count { it.habitId == habitId && it.ownerUid == ownerUid }
            entries.values.removeAll { it.habitId == habitId && it.ownerUid == ownerUid }
            return c
        }
        override fun deleteAllEntriesForUser(ownerUid: String): Int {
            val c = entries.values.count { it.ownerUid == ownerUid }
            entries.values.removeAll { it.ownerUid == ownerUid }
            return c
        }
        override fun getEntryById(entryId: String, ownerUid: String): HabitEntryEntity? = entries[entryId]?.takeIf { it.ownerUid == ownerUid }
        override fun getAllEntriesForUser(ownerUid: String): List<HabitEntryEntity> = entries.values.filter { it.ownerUid == ownerUid }
        override fun getEntriesForHabit(ownerUid: String, habitId: String): List<HabitEntryEntity> = entries.values.filter { it.habitId == habitId && it.ownerUid == ownerUid }
        override fun getEntriesForDate(ownerUid: String, dateStr: String): List<HabitEntryEntity> = entries.values.filter { it.dateStr == dateStr && it.ownerUid == ownerUid }
    }

    private class TestTransactionDao : TransactionDao {
        val txs = mutableMapOf<String, TransactionEntity>()

        override fun insertTransaction(transaction: TransactionEntity) { txs[transaction.id] = transaction }
        override fun insertAllTransactions(list: List<TransactionEntity>) { list.forEach { txs[it.id] = it } }
        override fun updateTransaction(transaction: TransactionEntity) { txs[transaction.id] = transaction }
        override fun deleteTransactionById(id: String, ownerUid: String): Int = if (txs.remove(id) != null) 1 else 0
        override fun deleteAllTransactionsForUser(ownerUid: String): Int {
            val c = txs.values.count { it.ownerUid == ownerUid }
            txs.values.removeAll { it.ownerUid == ownerUid }
            return c
        }
        override fun getTransactionById(id: String, ownerUid: String): TransactionEntity? = txs[id]?.takeIf { it.ownerUid == ownerUid }
        override fun getAllTransactionsForUser(ownerUid: String): List<TransactionEntity> = txs.values.filter { it.ownerUid == ownerUid }
        override fun getTransactionsForDateRange(ownerUid: String, startDate: Long, endDate: Long): List<TransactionEntity> =
            txs.values.filter { it.ownerUid == ownerUid && it.date in startDate..endDate }
        override fun getTransactionsByType(ownerUid: String, type: String): List<TransactionEntity> =
            txs.values.filter { it.ownerUid == ownerUid && it.type == type }
        override fun getTransactionsByCategory(ownerUid: String, category: String): List<TransactionEntity> =
            txs.values.filter { it.ownerUid == ownerUid && it.category == category }
        override fun getTransactionByFingerprint(ownerUid: String, fingerprint: String): TransactionEntity? =
            txs.values.firstOrNull { it.ownerUid == ownerUid && it.automationFingerprint == fingerprint }
        override fun getTotalAmountPaiseForTypeAndRange(ownerUid: String, type: String, startDate: Long, endDate: Long): Long =
            txs.values.filter { it.ownerUid == ownerUid && it.type == type && it.date in startDate..endDate }.sumOf { it.amountPaise }
        override fun getTransactionCountForUser(ownerUid: String): Int = txs.values.count { it.ownerUid == ownerUid }
    }

    private class TestBudgetDao : BudgetDao {
        val budgets = mutableMapOf<String, BudgetEntity>()
        override fun insertBudget(budget: BudgetEntity) { budgets[budget.id] = budget }
        override fun updateBudget(budget: BudgetEntity) { budgets[budget.id] = budget }
        override fun getBudgetForMonth(ownerUid: String, month: String): BudgetEntity? =
            budgets.values.firstOrNull { it.ownerUid == ownerUid && it.month == month }
        override fun getAllBudgetsForUser(ownerUid: String): List<BudgetEntity> =
            budgets.values.filter { it.ownerUid == ownerUid }
        override fun deleteBudgetForMonth(ownerUid: String, month: String): Int {
            val key = "${ownerUid}_$month"
            return if (budgets.remove(key) != null) 1 else 0
        }
        override fun deleteAllBudgetsForUser(ownerUid: String): Int {
            val c = budgets.values.count { it.ownerUid == ownerUid }
            budgets.values.removeAll { it.ownerUid == ownerUid }
            return c
        }
    }

    private class MockArcDatabase(
        val testTaskDao: TestTaskDao,
        val testHabitDao: TestHabitDao,
        val testTransactionDao: TestTransactionDao,
        val testBudgetDao: TestBudgetDao,
    ) : ArcDatabase() {
        override fun taskDao(): TaskDao = testTaskDao
        override fun habitDao(): HabitDao = testHabitDao
        override fun transactionDao(): TransactionDao = testTransactionDao
        override fun budgetDao(): BudgetDao = testBudgetDao
        override fun secretNoteDao(): SecretNoteDao = throw UnsupportedOperationException("Secret notes excluded from ordinary database operations")
        override fun createOpenHelper(config: androidx.room.DatabaseConfiguration): androidx.sqlite.db.SupportSQLiteOpenHelper = throw UnsupportedOperationException()
        override fun createInvalidationTracker(): androidx.room.InvalidationTracker =
            androidx.room.InvalidationTracker(this, "tasks", "habits", "habit_entries", "transactions", "budgets")
        override fun clearAllTables() {}
        override fun runInTransaction(body: Runnable) { body.run() }
    }

    private lateinit var mockDb: MockArcDatabase
    private lateinit var taskDao: TestTaskDao
    private lateinit var habitDao: TestHabitDao
    private lateinit var txDao: TestTransactionDao
    private lateinit var budgetDao: TestBudgetDao
    private lateinit var migrator: HiveToRoomMigrator

    private val ownerUid = "shreyas_production_uid"

    @Before
    fun setUp() {
        taskDao = TestTaskDao()
        habitDao = TestHabitDao()
        txDao = TestTransactionDao()
        budgetDao = TestBudgetDao()
        mockDb = MockArcDatabase(taskDao, habitDao, txDao, budgetDao)
        migrator = HiveToRoomMigrator(mockDb, testDispatcher)
    }

    @Test
    fun testCompleteMigrationOfAllModules() = runTest(testDispatcher) {
        val snapshot = LegacyHiveSnapshot(
            tasks = listOf(
                mapOf("id" to "task_1", "title" to "Complete Phase 6", "priority" to "High", "completed" to false),
                mapOf("id" to "task_2", "title" to "Deploy Release", "priority" to "Must", "completed" to true)
            ),
            habits = listOf(
                mapOf("id" to "habit_1", "name" to "Morning Meditation", "category" to "Wellness", "colorValue" to 0xFF4A90E2)
            ),
            habitEntries = listOf(
                mapOf("id" to "habit_1_2026-10-19", "habitId" to "habit_1", "dateStr" to "2026-10-19", "completed" to true)
            ),
            transactions = listOf(
                mapOf("id" to "tx_1", "amount" to 450.0, "amountPaise" to 45000L, "type" to "Expense", "category" to "Food")
            ),
            budgets = listOf(
                mapOf("month" to "2026-10", "amount" to 25000.0)
            )
        )

        val result = migrator.executeMigration(ownerUid, snapshot)

        assertTrue(result.success)
        assertEquals(2, result.tasksMigrated)
        assertEquals(1, result.habitsMigrated)
        assertEquals(1, result.transactionsMigrated)
        assertEquals(0, result.errors.size)

        assertEquals(2, taskDao.getTaskCountForUser(ownerUid))
        assertEquals(1, habitDao.getHabitCountForUser(ownerUid))
        assertEquals(1, habitDao.getAllEntriesForUser(ownerUid).size)
        assertEquals(1, txDao.getTransactionCountForUser(ownerUid))

        assertTrue(migrator.verifyRecordEquivalence(ownerUid, 2, 1, 1))
    }

    @Test
    fun testMigrationIdempotencyReRunningDoesNotDuplicateRecords() = runTest(testDispatcher) {
        val snapshot = LegacyHiveSnapshot(
            tasks = listOf(
                mapOf("id" to "task_100", "title" to "Idempotent Task", "priority" to "Low")
            ),
            habits = listOf(
                mapOf("id" to "habit_100", "name" to "Reading", "category" to "Learning")
            ),
            transactions = listOf(
                mapOf("id" to "tx_100", "amount" to 120.0, "type" to "Expense", "category" to "Books")
            )
        )

        // First execution
        val result1 = migrator.executeMigration(ownerUid, snapshot)
        assertTrue(result1.success)
        assertEquals(1, taskDao.getTaskCountForUser(ownerUid))
        assertEquals(1, habitDao.getHabitCountForUser(ownerUid))
        assertEquals(1, txDao.getTransactionCountForUser(ownerUid))

        // Second execution (re-run of identical source data)
        val result2 = migrator.executeMigration(ownerUid, snapshot)
        assertTrue(result2.success)

        // Record count in Room must remain exactly 1 per table (no duplication)
        assertEquals(1, taskDao.getTaskCountForUser(ownerUid))
        assertEquals(1, habitDao.getHabitCountForUser(ownerUid))
        assertEquals(1, txDao.getTransactionCountForUser(ownerUid))
    }

    @Test
    fun testCorruptedRecordsAreSkippedWhileValidRecordsSucceed() = runTest(testDispatcher) {
        val snapshot = LegacyHiveSnapshot(
            tasks = listOf(
                mapOf("id" to "valid_task", "title" to "Valid Task"),
                mapOf("id" to "", "title" to "Missing ID Task"),
                mapOf("id" to "no_title_task")
            ),
            transactions = listOf(
                mapOf("id" to "valid_tx", "amount" to 500.0),
                mapOf("id" to "corrupt_tx")
            )
        )

        val result = migrator.executeMigration(ownerUid, snapshot)
        assertTrue(result.success)
        assertEquals(1, result.tasksMigrated)
        assertEquals(1, result.transactionsMigrated)
        assertTrue(result.errors.size >= 3)
    }

    @Test
    fun testEmptyDatasetMigrationSucceedsCleanly() = runTest(testDispatcher) {
        val emptySnapshot = LegacyHiveSnapshot()
        val result = migrator.executeMigration(ownerUid, emptySnapshot)

        assertTrue(result.success)
        assertEquals(0, result.tasksMigrated)
        assertEquals(0, result.habitsMigrated)
        assertEquals(0, result.transactionsMigrated)
        assertTrue(result.errors.isEmpty())
        assertTrue(migrator.verifyIntegrity(ownerUid))
    }

    @Test
    fun testLargeDatasetPerformanceAndCompleteness() = runTest(testDispatcher) {
        val largeTasks = (1..300).map { i ->
            mapOf("id" to "bulk_task_$i", "title" to "Bulk Task $i", "priority" to "Medium")
        }
        val largeHabits = (1..100).map { i ->
            mapOf("id" to "bulk_habit_$i", "name" to "Bulk Habit $i", "category" to "Daily")
        }
        val largeTxs = (1..200).map { i ->
            mapOf("id" to "bulk_tx_$i", "amount" to (i * 10.0), "type" to "Expense", "category" to "General")
        }

        val snapshot = LegacyHiveSnapshot(
            tasks = largeTasks,
            habits = largeHabits,
            transactions = largeTxs
        )

        val result = migrator.executeMigration(ownerUid, snapshot)
        assertTrue(result.success)
        assertEquals(300, result.tasksMigrated)
        assertEquals(100, result.habitsMigrated)
        assertEquals(200, result.transactionsMigrated)
        assertTrue(result.executionTimeMs < 5000)

        assertTrue(migrator.verifyRecordEquivalence(ownerUid, 300, 100, 200))
    }
}
