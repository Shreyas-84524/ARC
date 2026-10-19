package com.arc.arc.features.money.data

import com.arc.arc.core.database.RoomTransactionDataSource
import com.arc.arc.core.model.BudgetModel
import com.arc.arc.core.model.MonthlySummaryModel
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.features.tasks.data.SyncResult
import kotlinx.coroutines.flow.Flow
import java.time.YearMonth
import java.time.ZoneOffset
import java.util.Date

interface ITransactionRepository {
    fun getTransactionsFlow(ownerUid: String): Flow<List<TransactionModel>>
    fun getBudgetFlow(ownerUid: String, month: String): Flow<BudgetModel?>
    fun getAllBudgetsFlow(ownerUid: String): Flow<List<BudgetModel>>
    suspend fun getTransactions(ownerUid: String): List<TransactionModel>
    suspend fun getTransactionById(id: String, ownerUid: String): TransactionModel?
    suspend fun saveTransaction(transaction: TransactionModel): Result<Unit>
    suspend fun deleteTransaction(id: String, ownerUid: String): Result<Unit>
    suspend fun getBudget(ownerUid: String, month: String): BudgetModel?
    suspend fun saveBudget(budget: BudgetModel): Result<Unit>
    suspend fun deleteBudget(ownerUid: String, month: String): Result<Unit>
    suspend fun getMonthlySummary(ownerUid: String, month: String): MonthlySummaryModel
    suspend fun calculateIncomePaise(ownerUid: String, startDate: Long, endDate: Long): Long
    suspend fun calculateExpensesPaise(ownerUid: String, startDate: Long, endDate: Long): Long
    suspend fun calculateBalancePaise(ownerUid: String, startDate: Long, endDate: Long): Long
    suspend fun syncPending(ownerUid: String): SyncResult
}

/**
 * Offline-first Transaction and Budget repository.
 * Room SQLite is the immediate, single source of truth.
 *
 * Financial Precision:
 * All internal arithmetic operates strictly on integer minor units ([amountPaise] in Long).
 */
class OfflineFirstTransactionRepository(
    private val localDataSource: RoomTransactionDataSource
) : ITransactionRepository {

    override fun getTransactionsFlow(ownerUid: String): Flow<List<TransactionModel>> {
        return localDataSource.observeTransactions(ownerUid)
    }

    override fun getBudgetFlow(ownerUid: String, month: String): Flow<BudgetModel?> {
        return localDataSource.observeBudget(ownerUid, month)
    }

    override fun getAllBudgetsFlow(ownerUid: String): Flow<List<BudgetModel>> {
        return localDataSource.observeAllBudgets(ownerUid)
    }

    override suspend fun getTransactions(ownerUid: String): List<TransactionModel> {
        return localDataSource.getTransactions(ownerUid)
    }

    override suspend fun getTransactionById(id: String, ownerUid: String): TransactionModel? {
        return localDataSource.getTransaction(id, ownerUid)
    }

    override suspend fun saveTransaction(transaction: TransactionModel): Result<Unit> {
        if (transaction.amountPaise <= 0L && transaction.amount <= 0.0) {
            return Result.failure(IllegalArgumentException("Transaction amount must be greater than zero"))
        }
        val updated = if (transaction.createdAt.time == 0L) {
            transaction.copy(createdAt = Date())
        } else {
            transaction
        }
        localDataSource.saveTransaction(updated)
        return Result.success(Unit)
    }

    override suspend fun deleteTransaction(id: String, ownerUid: String): Result<Unit> {
        val deleted = localDataSource.deleteTransaction(id, ownerUid)
        return if (deleted) {
            Result.success(Unit)
        } else {
            Result.failure(NoSuchElementException("Transaction not found or not deleted: $id"))
        }
    }

    override suspend fun getBudget(ownerUid: String, month: String): BudgetModel? {
        return localDataSource.getBudget(ownerUid, month)
    }

    override suspend fun saveBudget(budget: BudgetModel): Result<Unit> {
        if (budget.month.isBlank()) {
            return Result.failure(IllegalArgumentException("Budget month cannot be blank"))
        }
        val updated = budget.copy(updatedAt = Date())
        localDataSource.saveBudget(updated)
        return Result.success(Unit)
    }

    override suspend fun deleteBudget(ownerUid: String, month: String): Result<Unit> {
        val deleted = localDataSource.deleteBudget(ownerUid, month)
        return if (deleted) {
            Result.success(Unit)
        } else {
            Result.failure(NoSuchElementException("Budget not found or not deleted for month: $month"))
        }
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
        return localDataSource.getTotalPaiseForTypeAndRange(ownerUid, "Income", startDate, endDate)
    }

    override suspend fun calculateExpensesPaise(ownerUid: String, startDate: Long, endDate: Long): Long {
        return localDataSource.getTotalPaiseForTypeAndRange(ownerUid, "Expense", startDate, endDate)
    }

    override suspend fun calculateBalancePaise(ownerUid: String, startDate: Long, endDate: Long): Long {
        val income = calculateIncomePaise(ownerUid, startDate, endDate)
        val expenses = calculateExpensesPaise(ownerUid, startDate, endDate)
        return income - expenses
    }

    override suspend fun syncPending(ownerUid: String): SyncResult {
        return SyncResult.PendingOffline(
            pendingCount = 0,
            reason = "Local-first storage active. Cloud sync pending Firebase project configuration in later phase."
        )
    }
}
