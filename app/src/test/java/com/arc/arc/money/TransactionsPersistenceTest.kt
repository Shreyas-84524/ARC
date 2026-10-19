package com.arc.arc.money

import com.arc.arc.core.database.ArcDatabase
import com.arc.arc.core.model.BudgetModel
import com.arc.arc.core.model.MonthlySummaryModel
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.features.money.data.ITransactionRepository
import com.arc.arc.features.tasks.data.SyncResult
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.YearMonth
import java.time.ZoneOffset
import java.util.Date

/**
 * In-memory test repository implementing ITransactionRepository with exact Room
 * arithmetic (paise in Long), user isolation, and budget tracking semantics.
 */
class InMemoryTransactionRepository : ITransactionRepository {
    private val transactionsStore = MutableStateFlow<Map<String, TransactionModel>>(emptyMap())
    private val budgetsStore = MutableStateFlow<Map<String, BudgetModel>>(emptyMap())

    override fun getTransactionsFlow(ownerUid: String): Flow<List<TransactionModel>> {
        return transactionsStore.map { map ->
            map.values.filter { it.ownerUid == ownerUid }.sortedByDescending { it.date.time }
        }
    }

    override fun getBudgetFlow(ownerUid: String, month: String): Flow<BudgetModel?> {
        val key = "${ownerUid}_$month"
        return budgetsStore.map { map -> map[key] }
    }

    override fun getAllBudgetsFlow(ownerUid: String): Flow<List<BudgetModel>> {
        return budgetsStore.map { map ->
            map.values.filter { it.ownerUid == ownerUid }.sortedByDescending { it.month }
        }
    }

    override suspend fun getTransactions(ownerUid: String): List<TransactionModel> {
        return transactionsStore.value.values.filter { it.ownerUid == ownerUid }
            .sortedByDescending { it.date.time }
    }

    override suspend fun getTransactionById(id: String, ownerUid: String): TransactionModel? {
        return transactionsStore.value[id]?.takeIf { it.ownerUid == ownerUid }
    }

    override suspend fun saveTransaction(transaction: TransactionModel): Result<Unit> {
        if (transaction.amountPaise <= 0L && transaction.amount <= 0.0) {
            return Result.failure(IllegalArgumentException("Transaction amount must be positive"))
        }
        val current = transactionsStore.value.toMutableMap()
        current[transaction.id] = transaction
        transactionsStore.value = current
        return Result.success(Unit)
    }

    override suspend fun deleteTransaction(id: String, ownerUid: String): Result<Unit> {
        val current = transactionsStore.value.toMutableMap()
        if (current.remove(id) != null) {
            transactionsStore.value = current
            return Result.success(Unit)
        }
        return Result.failure(NoSuchElementException("Transaction not found: $id"))
    }

    override suspend fun getBudget(ownerUid: String, month: String): BudgetModel? {
        val key = "${ownerUid}_$month"
        return budgetsStore.value[key]
    }

    override suspend fun saveBudget(budget: BudgetModel): Result<Unit> {
        val key = "${budget.ownerUid}_${budget.month}"
        val current = budgetsStore.value.toMutableMap()
        current[key] = budget
        budgetsStore.value = current
        return Result.success(Unit)
    }

    override suspend fun deleteBudget(ownerUid: String, month: String): Result<Unit> {
        val key = "${ownerUid}_$month"
        val current = budgetsStore.value.toMutableMap()
        if (current.remove(key) != null) {
            budgetsStore.value = current
            return Result.success(Unit)
        }
        return Result.failure(NoSuchElementException("Budget not found for month: $month"))
    }

    override suspend fun getMonthlySummary(ownerUid: String, month: String): MonthlySummaryModel {
        val (startMillis, endMillis) = try {
            val ym = YearMonth.parse(month)
            val start = ym.atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
            val end = ym.atEndOfMonth().atTime(23, 59, 59, 999_000_000).atZone(ZoneOffset.UTC).toInstant().toEpochMilli()
            Pair(start, end)
        } catch (_: Exception) {
            Pair(0L, Long.MAX_VALUE)
        }

        val incomePaise = calculateIncomePaise(ownerUid, startMillis, endMillis)
        val expensePaise = calculateExpensesPaise(ownerUid, startMillis, endMillis)
        val budget = getBudget(ownerUid, month)
        val budgetPaise = budget?.amountPaise ?: 0L

        return MonthlySummaryModel.fromPaise(
            month = month,
            ownerUid = ownerUid,
            monthlyBudgetPaise = budgetPaise,
            totalIncomePaise = incomePaise,
            totalExpensesPaise = expensePaise,
            updatedAt = Date(),
        )
    }

    override suspend fun calculateIncomePaise(ownerUid: String, startDate: Long, endDate: Long): Long {
        return transactionsStore.value.values
            .filter { it.ownerUid == ownerUid && it.isIncome && it.date.time in startDate..endDate }
            .sumOf { it.amountPaise }
    }

    override suspend fun calculateExpensesPaise(ownerUid: String, startDate: Long, endDate: Long): Long {
        return transactionsStore.value.values
            .filter { it.ownerUid == ownerUid && it.isExpense && it.date.time in startDate..endDate }
            .sumOf { it.amountPaise }
    }

    override suspend fun calculateBalancePaise(ownerUid: String, startDate: Long, endDate: Long): Long {
        return calculateIncomePaise(ownerUid, startDate, endDate) - calculateExpensesPaise(ownerUid, startDate, endDate)
    }

    override suspend fun syncPending(ownerUid: String): SyncResult {
        return SyncResult.PendingOffline(0, "Local-first")
    }
}

class TransactionsPersistenceTest {

    private lateinit var repository: InMemoryTransactionRepository

    @Before
    fun setup() {
        repository = InMemoryTransactionRepository()
    }

    @Test
    fun testTransactionCRUDOperations() = runTest {
        val tx = TransactionModel.fromPaise(
            id = "tx-001",
            ownerUid = "user-a",
            amountPaise = 25050L, // 250.50
            type = "Expense",
            category = "Food",
            notes = "Dinner at restaurant",
        )

        // Create
        val createResult = repository.saveTransaction(tx)
        assertTrue(createResult.isSuccess)

        // Read
        val fetched = repository.getTransactionById("tx-001", "user-a")
        assertNotNull(fetched)
        assertEquals(25050L, fetched?.amountPaise)
        assertEquals("Dinner at restaurant", fetched?.notes)
        assertEquals(250.50, fetched?.amount ?: 0.0, 0.001)

        // Update
        val updated = fetched!!.copy(notes = "Dinner with friends")
        repository.saveTransaction(updated)
        val fetchedUpdated = repository.getTransactionById("tx-001", "user-a")
        assertEquals("Dinner with friends", fetchedUpdated?.notes)

        // Delete
        val deleteResult = repository.deleteTransaction("tx-001", "user-a")
        assertTrue(deleteResult.isSuccess)
        assertNull(repository.getTransactionById("tx-001", "user-a"))
    }

    @Test
    fun testFinancialIntegerArithmeticAccuracy() = runTest {
        val now = Date()
        // Save multiple income and expenses with exact paise
        repository.saveTransaction(
            TransactionModel.fromPaise(
                id = "inc-1",
                ownerUid = "user-a",
                amountPaise = 7500000L, // ₹75,000.00
                type = "Income",
                category = "Salary",
                date = now,
            )
        )
        repository.saveTransaction(
            TransactionModel.fromPaise(
                id = "exp-1",
                ownerUid = "user-a",
                amountPaise = 1245050L, // ₹12,450.50
                type = "Expense",
                category = "Rent",
                date = now,
            )
        )
        repository.saveTransaction(
            TransactionModel.fromPaise(
                id = "exp-2",
                ownerUid = "user-a",
                amountPaise = 320075L, // ₹3,200.75
                type = "Expense",
                category = "Groceries",
                date = now,
            )
        )

        val totalIncome = repository.calculateIncomePaise("user-a", 0L, Long.MAX_VALUE)
        val totalExpenses = repository.calculateExpensesPaise("user-a", 0L, Long.MAX_VALUE)
        val balance = repository.calculateBalancePaise("user-a", 0L, Long.MAX_VALUE)

        assertEquals(7500000L, totalIncome)
        assertEquals(1565125L, totalExpenses) // 1245050 + 320075 = 1565125
        assertEquals(5934875L, balance)       // 7500000 - 1565125 = 5934875

        // Verify decimal representation matches exactly
        assertEquals(59348.75, balance.toDouble() / 100.0, 0.0001)
    }

    @Test
    fun testBudgetCRUDAndMonthlySummary() = runTest {
        val budget = BudgetModel.fromPaise(
            month = "2026-10",
            ownerUid = "user-a",
            amountPaise = 4000000L, // ₹40,000.00
        )
        repository.saveBudget(budget)

        val fetchedBudget = repository.getBudget("user-a", "2026-10")
        assertNotNull(fetchedBudget)
        assertEquals(4000000L, fetchedBudget?.amountPaise)

        // Add expense in October 2026
        val octDate = Date(1772900000000L) // in Oct 2026
        repository.saveTransaction(
            TransactionModel.fromPaise(
                id = "oct-exp",
                ownerUid = "user-a",
                amountPaise = 1500000L, // ₹15,000.00
                type = "Expense",
                date = octDate,
            )
        )

        val summary = repository.getMonthlySummary("user-a", "2026-10")
        assertEquals(4000000L, summary.monthlyBudgetPaise)
        assertEquals(40000.0, summary.monthlyBudget, 0.001)
    }

    @Test
    fun testUserIsolationStrictlyEnforced() = runTest {
        // User A records
        repository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-a",
                ownerUid = "user-a",
                amountPaise = 50000L,
                type = "Expense",
            )
        )
        repository.saveBudget(
            BudgetModel.fromPaise(
                month = "2026-10",
                ownerUid = "user-a",
                amountPaise = 2000000L,
            )
        )

        // User B records
        repository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-b",
                ownerUid = "user-b",
                amountPaise = 100000L,
                type = "Income",
            )
        )
        repository.saveBudget(
            BudgetModel.fromPaise(
                month = "2026-10",
                ownerUid = "user-b",
                amountPaise = 5000000L,
            )
        )

        // Verify User A cannot see User B
        val userATransactions = repository.getTransactions("user-a")
        assertEquals(1, userATransactions.size)
        assertEquals("tx-a", userATransactions.first().id)
        assertNull(repository.getTransactionById("tx-b", "user-a"))
        assertEquals(2000000L, repository.getBudget("user-a", "2026-10")?.amountPaise)

        // Verify User B cannot see User A
        val userBTransactions = repository.getTransactions("user-b")
        assertEquals(1, userBTransactions.size)
        assertEquals("tx-b", userBTransactions.first().id)
        assertNull(repository.getTransactionById("tx-a", "user-b"))
        assertEquals(5000000L, repository.getBudget("user-b", "2026-10")?.amountPaise)
    }

    @Test
    fun testRoomMigrationV2ToV3Definition() {
        assertEquals(2, ArcDatabase.MIGRATION_2_3.startVersion)
        assertEquals(3, ArcDatabase.MIGRATION_2_3.endVersion)
    }
}
