package com.arc.arc.core.database

import androidx.room.InvalidationTracker
import com.arc.arc.core.database.TransactionMappers.toEntity
import com.arc.arc.core.database.TransactionMappers.toModel
import com.arc.arc.core.model.BudgetModel
import com.arc.arc.core.model.TransactionModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext

/**
 * Local Room data source implementation for Transaction and Budget persistence,
 * providing reactive Flow observation and asynchronous CRUD operations.
 *
 * Financial Precision:
 * All calculations and aggregations use integer minor units (paise in [Long]).
 */
class RoomTransactionDataSource(
    private val database: ArcDatabase,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    private val transactionDao: TransactionDao get() = database.transactionDao()
    private val budgetDao: BudgetDao get() = database.budgetDao()

    /**
     * Observes transactions reactively for the given user, ordered by date DESC.
     */
    fun observeTransactions(ownerUid: String): Flow<List<TransactionModel>> = callbackFlow {
        val observer = object : InvalidationTracker.Observer("transactions") {
            override fun onInvalidated(tables: Set<String>) {
                val current = transactionDao.getAllTransactionsForUser(ownerUid).map { it.toModel() }
                trySend(current)
            }
        }

        database.invalidationTracker.addObserver(observer)
        // Emit initial value
        val initial = transactionDao.getAllTransactionsForUser(ownerUid).map { it.toModel() }
        trySend(initial)

        awaitClose {
            database.invalidationTracker.removeObserver(observer)
        }
    }.flowOn(ioDispatcher)

    /**
     * Observes budget for a given month ("yyyy-MM") reactively for the given user.
     */
    fun observeBudget(ownerUid: String, month: String): Flow<BudgetModel?> = callbackFlow {
        val observer = object : InvalidationTracker.Observer("budgets") {
            override fun onInvalidated(tables: Set<String>) {
                val current = budgetDao.getBudgetForMonth(ownerUid, month)?.toModel()
                trySend(current)
            }
        }

        database.invalidationTracker.addObserver(observer)
        // Emit initial value
        val initial = budgetDao.getBudgetForMonth(ownerUid, month)?.toModel()
        trySend(initial)

        awaitClose {
            database.invalidationTracker.removeObserver(observer)
        }
    }.flowOn(ioDispatcher)

    /**
     * Observes all budgets reactively for the given user.
     */
    fun observeAllBudgets(ownerUid: String): Flow<List<BudgetModel>> = callbackFlow {
        val observer = object : InvalidationTracker.Observer("budgets") {
            override fun onInvalidated(tables: Set<String>) {
                val current = budgetDao.getAllBudgetsForUser(ownerUid).map { it.toModel() }
                trySend(current)
            }
        }

        database.invalidationTracker.addObserver(observer)
        val initial = budgetDao.getAllBudgetsForUser(ownerUid).map { it.toModel() }
        trySend(initial)

        awaitClose {
            database.invalidationTracker.removeObserver(observer)
        }
    }.flowOn(ioDispatcher)

    suspend fun getTransactions(ownerUid: String): List<TransactionModel> = withContext(ioDispatcher) {
        transactionDao.getAllTransactionsForUser(ownerUid).map { it.toModel() }
    }

    suspend fun getTransaction(id: String, ownerUid: String): TransactionModel? = withContext(ioDispatcher) {
        transactionDao.getTransactionById(id, ownerUid)?.toModel()
    }

    suspend fun saveTransaction(transaction: TransactionModel) = withContext(ioDispatcher) {
        transactionDao.insertTransaction(transaction.toEntity())
    }

    suspend fun saveTransactions(transactions: List<TransactionModel>) = withContext(ioDispatcher) {
        database.runInTransaction {
            transactionDao.insertAllTransactions(transactions.map { it.toEntity() })
        }
    }

    suspend fun deleteTransaction(id: String, ownerUid: String): Boolean = withContext(ioDispatcher) {
        transactionDao.deleteTransactionById(id, ownerUid) > 0
    }

    suspend fun deleteAllTransactionsForUser(ownerUid: String): Int = withContext(ioDispatcher) {
        transactionDao.deleteAllTransactionsForUser(ownerUid)
    }

    suspend fun getTransactionsForRange(
        ownerUid: String,
        startDate: Long,
        endDate: Long,
    ): List<TransactionModel> = withContext(ioDispatcher) {
        transactionDao.getTransactionsForDateRange(ownerUid, startDate, endDate).map { it.toModel() }
    }

    suspend fun getTransactionsByType(ownerUid: String, type: String): List<TransactionModel> = withContext(ioDispatcher) {
        transactionDao.getTransactionsByType(ownerUid, type).map { it.toModel() }
    }

    suspend fun getTransactionsByCategory(ownerUid: String, category: String): List<TransactionModel> = withContext(ioDispatcher) {
        transactionDao.getTransactionsByCategory(ownerUid, category).map { it.toModel() }
    }

    suspend fun getTransactionByFingerprint(ownerUid: String, fingerprint: String): TransactionModel? = withContext(ioDispatcher) {
        transactionDao.getTransactionByFingerprint(ownerUid, fingerprint)?.toModel()
    }

    suspend fun getTotalPaiseForTypeAndRange(
        ownerUid: String,
        type: String,
        startDate: Long,
        endDate: Long,
    ): Long = withContext(ioDispatcher) {
        transactionDao.getTotalAmountPaiseForTypeAndRange(ownerUid, type, startDate, endDate)
    }

    suspend fun getTransactionCountForUser(ownerUid: String): Int = withContext(ioDispatcher) {
        transactionDao.getTransactionCountForUser(ownerUid)
    }

    // Budget CRUD
    suspend fun getBudget(ownerUid: String, month: String): BudgetModel? = withContext(ioDispatcher) {
        budgetDao.getBudgetForMonth(ownerUid, month)?.toModel()
    }

    suspend fun saveBudget(budget: BudgetModel) = withContext(ioDispatcher) {
        budgetDao.insertBudget(budget.toEntity())
    }

    suspend fun deleteBudget(ownerUid: String, month: String): Boolean = withContext(ioDispatcher) {
        budgetDao.deleteBudgetForMonth(ownerUid, month) > 0
    }

    suspend fun getAllBudgets(ownerUid: String): List<BudgetModel> = withContext(ioDispatcher) {
        budgetDao.getAllBudgetsForUser(ownerUid).map { it.toModel() }
    }
}
