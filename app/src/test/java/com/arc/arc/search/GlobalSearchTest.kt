package com.arc.arc.search

import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.auth.UserSession
import com.arc.arc.core.database.SecretNoteEntity
import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import com.arc.arc.core.model.MonthlySummaryModel
import com.arc.arc.core.model.SecretNoteModel
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TaskPriority
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.features.habits.data.IHabitRepository
import com.arc.arc.features.money.data.ITransactionRepository
import com.arc.arc.features.search.GlobalSearchRepository
import com.arc.arc.features.search.GlobalSearchViewModel
import com.arc.arc.features.search.SearchFilter
import com.arc.arc.features.tasks.data.ITaskRepository
import com.arc.arc.features.tasks.data.SyncResult
import com.arc.arc.features.vault.data.ISecretNoteRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class GlobalSearchTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var authRepository: DevFakeAuthRepository
    private lateinit var taskRepository: FakeSearchTaskRepository
    private lateinit var habitRepository: FakeSearchHabitRepository
    private lateinit var transactionRepository: FakeSearchTransactionRepository
    private lateinit var secretNoteRepository: FakeSearchSecretNoteRepository
    private lateinit var searchRepository: GlobalSearchRepository
    private lateinit var viewModel: GlobalSearchViewModel

    private val userA = "user_shreyas"
    private val userB = "user_other"

    private class FakeSearchTaskRepository : ITaskRepository {
        val tasks = mutableListOf<TaskModel>()
        override fun getTasksFlow(ownerUid: String): Flow<List<TaskModel>> = flowOf(tasks.filter { it.ownerUid == ownerUid })
        override suspend fun getTasks(ownerUid: String): List<TaskModel> = tasks.filter { it.ownerUid == ownerUid }
        override suspend fun getTaskById(id: String, ownerUid: String): TaskModel? = tasks.find { it.id == id && it.ownerUid == ownerUid }
        override suspend fun saveTask(task: TaskModel): Result<Unit> {
            tasks.removeAll { it.id == task.id }
            tasks.add(task)
            return Result.success(Unit)
        }
        override suspend fun toggleTaskCompletion(taskId: String, ownerUid: String): Result<TaskModel> = Result.failure(NotImplementedError())
        override suspend fun deleteTask(taskId: String, ownerUid: String): Result<Unit> {
            tasks.removeAll { it.id == taskId && it.ownerUid == ownerUid }
            return Result.success(Unit)
        }
        override suspend fun syncPending(ownerUid: String): SyncResult = SyncResult.Success(0)
    }

    private class FakeSearchHabitRepository : IHabitRepository {
        val habits = mutableListOf<HabitModel>()
        override fun getHabitsFlow(ownerUid: String): Flow<List<HabitModel>> = flowOf(habits.filter { it.ownerUid == ownerUid })
        override fun getEntriesFlow(ownerUid: String): Flow<List<HabitEntryModel>> = flowOf(emptyList())
        override fun getEntriesForDateFlow(ownerUid: String, dateStr: String): Flow<List<HabitEntryModel>> = flowOf(emptyList())
        override suspend fun getHabits(ownerUid: String): List<HabitModel> = habits.filter { it.ownerUid == ownerUid }
        override suspend fun getHabitById(id: String, ownerUid: String): HabitModel? = habits.find { it.id == id && it.ownerUid == ownerUid }
        override suspend fun saveHabit(habit: HabitModel): Result<Unit> {
            habits.removeAll { it.id == habit.id }
            habits.add(habit)
            return Result.success(Unit)
        }
        override suspend fun deleteHabit(id: String, ownerUid: String): Result<Unit> {
            habits.removeAll { it.id == id && it.ownerUid == ownerUid }
            return Result.success(Unit)
        }
        override suspend fun getEntries(ownerUid: String): List<HabitEntryModel> = emptyList()
        override suspend fun getEntriesForDate(ownerUid: String, dateStr: String): List<HabitEntryModel> = emptyList()
        override suspend fun toggleHabitCompletion(habitId: String, dateStr: String, completed: Boolean, ownerUid: String): Result<HabitEntryModel> = Result.failure(NotImplementedError())
        override suspend fun undoHabitCompletion(habitId: String, dateStr: String, ownerUid: String): Result<Unit> = Result.success(Unit)
        override suspend fun syncPending(ownerUid: String): SyncResult = SyncResult.Success(0)
    }

    private class FakeSearchTransactionRepository : ITransactionRepository {
        val transactions = mutableListOf<TransactionModel>()
        override fun getTransactionsFlow(ownerUid: String): Flow<List<TransactionModel>> = flowOf(transactions.filter { it.ownerUid == ownerUid })
        override fun getBudgetFlow(ownerUid: String, month: String): Flow<com.arc.arc.core.model.BudgetModel?> = flowOf(null)
        override fun getAllBudgetsFlow(ownerUid: String): Flow<List<com.arc.arc.core.model.BudgetModel>> = flowOf(emptyList())
        override suspend fun getTransactions(ownerUid: String): List<TransactionModel> = transactions.filter { it.ownerUid == ownerUid }
        override suspend fun getTransactionById(id: String, ownerUid: String): TransactionModel? = transactions.find { it.id == id && it.ownerUid == ownerUid }
        override suspend fun saveTransaction(transaction: TransactionModel): Result<Unit> {
            transactions.removeAll { it.id == transaction.id }
            transactions.add(transaction)
            return Result.success(Unit)
        }
        override suspend fun deleteTransaction(id: String, ownerUid: String): Result<Unit> {
            transactions.removeAll { it.id == id && it.ownerUid == ownerUid }
            return Result.success(Unit)
        }
        override suspend fun getBudget(ownerUid: String, month: String): com.arc.arc.core.model.BudgetModel? = null
        override suspend fun saveBudget(budget: com.arc.arc.core.model.BudgetModel): Result<Unit> = Result.success(Unit)
        override suspend fun deleteBudget(ownerUid: String, month: String): Result<Unit> = Result.success(Unit)
        override suspend fun getMonthlySummary(ownerUid: String, month: String): MonthlySummaryModel = MonthlySummaryModel("2026-03", ownerUid)
        override suspend fun calculateIncomePaise(ownerUid: String, startDate: Long, endDate: Long): Long = 0L
        override suspend fun calculateExpensesPaise(ownerUid: String, startDate: Long, endDate: Long): Long = 0L
        override suspend fun calculateBalancePaise(ownerUid: String, startDate: Long, endDate: Long): Long = 0L
        override suspend fun syncPending(ownerUid: String): SyncResult = SyncResult.Success(0)
    }

    private class FakeSearchSecretNoteRepository : ISecretNoteRepository {
        val notes = mutableListOf<SecretNoteModel>()
        override fun getNotesFlow(ownerUid: String, dek: ByteArray): Flow<List<SecretNoteModel>> = flowOf(notes.filter { it.ownerUid == ownerUid })
        override suspend fun getNotes(ownerUid: String, dek: ByteArray): List<SecretNoteModel> = notes.filter { it.ownerUid == ownerUid }
        override suspend fun getNoteById(id: String, ownerUid: String, dek: ByteArray): SecretNoteModel? = notes.find { it.id == id && it.ownerUid == ownerUid }
        override suspend fun saveNote(note: SecretNoteModel, dek: ByteArray): Result<Unit> {
            notes.removeAll { it.id == note.id }
            notes.add(note)
            return Result.success(Unit)
        }
        override suspend fun deleteNote(id: String, ownerUid: String): Result<Unit> = Result.success(Unit)
        override suspend fun deleteAllForUser(ownerUid: String): Result<Unit> = Result.success(Unit)
        override suspend fun getNoteCount(ownerUid: String): Int = notes.count { it.ownerUid == ownerUid }
        override suspend fun getRawEntities(ownerUid: String): List<SecretNoteEntity> = emptyList()
    }

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        authRepository = DevFakeAuthRepository()
        authRepository.switchUser(UserSession(uid = userA, email = "shreyas@arc.local", displayName = "Shreyas", username = "shreyas", isDevFake = true))

        taskRepository = FakeSearchTaskRepository()
        habitRepository = FakeSearchHabitRepository()
        transactionRepository = FakeSearchTransactionRepository()
        secretNoteRepository = FakeSearchSecretNoteRepository()

        // Seed data for User A
        taskRepository.tasks.addAll(
            listOf(
                TaskModel(id = "t1", ownerUid = userA, title = "Design crypto vault", category = "Work", priority = "High"),
                TaskModel(id = "t2", ownerUid = userA, title = "Buy groceries", category = "Personal", labels = listOf("shopping")),
                TaskModel(id = "t3", ownerUid = userA, title = "Pay electricity bill", category = "Finance", priority = "Medium")
            )
        )

        habitRepository.habits.addAll(
            listOf(
                HabitModel(id = "h1", ownerUid = userA, name = "Daily crypto study", category = "Learning"),
                HabitModel(id = "h2", ownerUid = userA, name = "Drink 2L water", category = "Health")
            )
        )

        transactionRepository.transactions.addAll(
            listOf(
                TransactionModel(id = "tx1", ownerUid = userA, category = "Electricity Bill", amount = 1200.0, type = "Expense", notes = "Online payment"),
                TransactionModel(id = "tx2", ownerUid = userA, category = "Freelance", amount = 25000.0, type = "Income", notes = "Crypto contract")
            )
        )

        // Seed Secret Note containing "crypto"
        secretNoteRepository.notes.add(
            SecretNoteModel(id = "sn1", ownerUid = userA, title = "Top Secret Crypto Seed Phrase", description = "word1 word2 word3")
        )

        // Seed data for User B
        taskRepository.tasks.add(
            TaskModel(id = "t_userB", ownerUid = userB, title = "User B Secret Project", category = "Work")
        )

        searchRepository = GlobalSearchRepository(taskRepository, habitRepository, transactionRepository)
        viewModel = GlobalSearchViewModel(searchRepository, authRepository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `multi-entity search across tasks, habits, and transactions`() = runTest(testDispatcher) {
        viewModel.onQueryChanged("crypto")
        advanceTimeBy(300)
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals("crypto", state.query)
        assertEquals(3, state.totalMatches)
        assertEquals(1, state.matchedTasks.size)
        assertEquals("t1", state.matchedTasks.first().id)
        assertEquals(1, state.matchedHabits.size)
        assertEquals("h1", state.matchedHabits.first().id)
        assertEquals(1, state.matchedTransactions.size)
        assertEquals("tx2", state.matchedTransactions.first().id)
    }

    @Test
    fun `filtering by entity category filters view without mutating raw counts`() = runTest(testDispatcher) {
        viewModel.onQueryChanged("crypto")
        advanceTimeBy(300)
        advanceUntilIdle()

        // Filter to TASKS
        viewModel.onFilterSelected(SearchFilter.TASKS)
        advanceUntilIdle()

        var state = viewModel.uiState.value
        assertEquals(SearchFilter.TASKS, state.activeFilter)
        assertEquals(1, state.matchedTasks.size)
        assertEquals(0, state.matchedHabits.size)
        assertEquals(0, state.matchedTransactions.size)
        assertEquals(1, state.rawTaskCount)
        assertEquals(1, state.rawHabitCount)
        assertEquals(1, state.rawTransactionCount)
        assertEquals(3, state.totalMatches)

        // Filter to HABITS
        viewModel.onFilterSelected(SearchFilter.HABITS)
        advanceUntilIdle()

        state = viewModel.uiState.value
        assertEquals(0, state.matchedTasks.size)
        assertEquals(1, state.matchedHabits.size)
        assertEquals(0, state.matchedTransactions.size)

        // Filter to TRANSACTIONS
        viewModel.onFilterSelected(SearchFilter.TRANSACTIONS)
        advanceUntilIdle()

        state = viewModel.uiState.value
        assertEquals(0, state.matchedTasks.size)
        assertEquals(0, state.matchedHabits.size)
        assertEquals(1, state.matchedTransactions.size)
    }

    @Test
    fun `privacy invariant - secret notes are strictly excluded and never indexed`() = runTest(testDispatcher) {
        // Query string specifically targeting the secret note title and content
        viewModel.onQueryChanged("Top Secret Crypto Seed")
        advanceTimeBy(300)
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(0, state.totalMatches)
        assertEquals(0, state.matchedTasks.size)
        assertEquals(0, state.matchedHabits.size)
        assertEquals(0, state.matchedTransactions.size)

        // Also query "word1" from the secret note content
        viewModel.onQueryChanged("word1")
        advanceTimeBy(300)
        advanceUntilIdle()

        val contentState = viewModel.uiState.value
        assertEquals(0, contentState.totalMatches)
    }

    @Test
    fun `user data isolation - cannot access or view another users records`() = runTest(testDispatcher) {
        // User A searches for User B's task title
        viewModel.onQueryChanged("User B")
        advanceTimeBy(300)
        advanceUntilIdle()

        assertEquals(0, viewModel.uiState.value.totalMatches)

        // Switch to User B
        authRepository.switchUser(UserSession(uid = userB, email = "userb@arc.local", displayName = "User B", username = "userb", isDevFake = true))
        viewModel.onQueryChanged("User B")
        advanceTimeBy(300)
        advanceUntilIdle()

        val userBState = viewModel.uiState.value
        assertEquals(1, userBState.totalMatches)
        assertEquals("t_userB", userBState.matchedTasks.first().id)
    }

    @Test
    fun `empty query clears search results immediately`() = runTest(testDispatcher) {
        viewModel.onQueryChanged("bill")
        advanceTimeBy(300)
        advanceUntilIdle()

        assertTrue(viewModel.uiState.value.totalMatches > 0)

        // Clear query
        viewModel.clearQuery()
        advanceUntilIdle()

        val clearedState = viewModel.uiState.value
        assertEquals("", clearedState.query)
        assertEquals(0, clearedState.totalMatches)
        assertEquals(0, clearedState.matchedTasks.size)
        assertFalse(clearedState.isSearching)
    }
}
