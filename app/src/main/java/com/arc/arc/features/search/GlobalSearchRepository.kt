package com.arc.arc.features.search

import com.arc.arc.core.model.HabitModel
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.features.habits.data.IHabitRepository
import com.arc.arc.features.money.data.ITransactionRepository
import com.arc.arc.features.tasks.data.ITaskRepository

/**
 * Aggregated domain search results across productivity and financial modules.
 * Note: Secret Notes and Vault records are intentionally and strictly excluded from search.
 */
data class SearchResults(
    val tasks: List<TaskModel> = emptyList(),
    val habits: List<HabitModel> = emptyList(),
    val transactions: List<TransactionModel> = emptyList(),
) {
    val totalCount: Int
        get() = tasks.size + habits.size + transactions.size
}

/**
 * Interface for privacy-aware global searching.
 */
interface IGlobalSearchRepository {
    suspend fun search(ownerUid: String, query: String): SearchResults
}

/**
 * Production implementation of [IGlobalSearchRepository].
 * Enforces user isolation by querying only records belonging to [ownerUid].
 * Cryptographically and architecturally isolates Secret Notes by avoiding any references to Vault repositories.
 */
class GlobalSearchRepository(
    private val taskRepository: ITaskRepository,
    private val habitRepository: IHabitRepository,
    private val transactionRepository: ITransactionRepository,
) : IGlobalSearchRepository {

    override suspend fun search(ownerUid: String, query: String): SearchResults {
        val cleanQuery = query.trim().lowercase()
        if (cleanQuery.isBlank() || ownerUid.isBlank()) {
            return SearchResults()
        }

        val allTasks = taskRepository.getTasks(ownerUid)
        val allHabits = habitRepository.getHabits(ownerUid)
        val allTransactions = transactionRepository.getTransactions(ownerUid)

        val matchedTasks = allTasks.filter { t ->
            t.title.lowercase().contains(cleanQuery) ||
                t.description.lowercase().contains(cleanQuery) ||
                t.category.lowercase().contains(cleanQuery) ||
                t.labels.any { it.lowercase().contains(cleanQuery) }
        }

        val matchedHabits = allHabits.filter { h ->
            h.name.lowercase().contains(cleanQuery) ||
                h.category.lowercase().contains(cleanQuery)
        }

        val matchedTransactions = allTransactions.filter { tx ->
            tx.category.lowercase().contains(cleanQuery) ||
                tx.notes.lowercase().contains(cleanQuery) ||
                tx.amount.toString().contains(cleanQuery) ||
                tx.type.lowercase().contains(cleanQuery)
        }

        return SearchResults(
            tasks = matchedTasks,
            habits = matchedHabits,
            transactions = matchedTransactions,
        )
    }
}
