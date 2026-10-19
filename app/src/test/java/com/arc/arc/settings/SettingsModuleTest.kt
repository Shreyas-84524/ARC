package com.arc.arc.settings

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.arc.arc.core.auth.AuthState
import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.database.SecretNoteEntity
import com.arc.arc.core.datastore.AppPreferencesDataStore
import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import com.arc.arc.core.model.MonthlySummaryModel
import com.arc.arc.core.model.SecretNoteModel
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.features.habits.data.IHabitRepository
import com.arc.arc.features.money.data.ITransactionRepository
import com.arc.arc.features.settings.SettingsViewModel
import com.arc.arc.features.tasks.data.ITaskRepository
import com.arc.arc.features.tasks.data.SyncResult
import com.arc.arc.features.vault.data.ISecretNoteRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsModuleTest {

    @get:Rule
    val tmpFolder: TemporaryFolder = TemporaryFolder()

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var testScope: CoroutineScope
    private lateinit var preferencesDataStore: AppPreferencesDataStore
    private lateinit var authRepository: DevFakeAuthRepository
    private lateinit var taskRepository: FakeSettingsTaskRepository
    private lateinit var habitRepository: FakeSettingsHabitRepository
    private lateinit var transactionRepository: FakeSettingsTransactionRepository
    private lateinit var secretNoteRepository: FakeSettingsSecretNoteRepository
    private lateinit var viewModel: SettingsViewModel

    private class FakeSettingsTaskRepository : ITaskRepository {
        var count = 5
        override fun getTasksFlow(ownerUid: String): Flow<List<TaskModel>> = flowOf(emptyList())
        override suspend fun getTasks(ownerUid: String): List<TaskModel> = List(count) {
            TaskModel(id = "task_$it", title = "Task $it", ownerUid = ownerUid)
        }
        override suspend fun getTaskById(id: String, ownerUid: String): TaskModel? = null
        override suspend fun saveTask(task: TaskModel): Result<Unit> = Result.success(Unit)
        override suspend fun toggleTaskCompletion(taskId: String, ownerUid: String): Result<TaskModel> = Result.failure(NotImplementedError())
        override suspend fun deleteTask(taskId: String, ownerUid: String): Result<Unit> = Result.success(Unit)
        override suspend fun syncPending(ownerUid: String): SyncResult = SyncResult.Success(0)
    }

    private class FakeSettingsHabitRepository : IHabitRepository {
        var count = 3
        override fun getHabitsFlow(ownerUid: String): Flow<List<HabitModel>> = flowOf(emptyList())
        override fun getEntriesFlow(ownerUid: String): Flow<List<HabitEntryModel>> = flowOf(emptyList())
        override fun getEntriesForDateFlow(ownerUid: String, dateStr: String): Flow<List<HabitEntryModel>> = flowOf(emptyList())
        override suspend fun getHabits(ownerUid: String): List<HabitModel> = List(count) {
            HabitModel(id = "habit_$it", name = "Habit $it", ownerUid = ownerUid)
        }
        override suspend fun getHabitById(id: String, ownerUid: String): HabitModel? = null
        override suspend fun saveHabit(habit: HabitModel): Result<Unit> = Result.success(Unit)
        override suspend fun deleteHabit(id: String, ownerUid: String): Result<Unit> = Result.success(Unit)
        override suspend fun getEntries(ownerUid: String): List<HabitEntryModel> = emptyList()
        override suspend fun getEntriesForDate(ownerUid: String, dateStr: String): List<HabitEntryModel> = emptyList()
        override suspend fun toggleHabitCompletion(habitId: String, dateStr: String, completed: Boolean, ownerUid: String): Result<HabitEntryModel> = Result.failure(NotImplementedError())
        override suspend fun undoHabitCompletion(habitId: String, dateStr: String, ownerUid: String): Result<Unit> = Result.success(Unit)
        override suspend fun syncPending(ownerUid: String): SyncResult = SyncResult.Success(0)
    }

    private class FakeSettingsTransactionRepository : ITransactionRepository {
        var count = 12
        override fun getTransactionsFlow(ownerUid: String): Flow<List<TransactionModel>> = flowOf(emptyList())
        override fun getBudgetFlow(ownerUid: String, month: String): Flow<com.arc.arc.core.model.BudgetModel?> = flowOf(null)
        override fun getAllBudgetsFlow(ownerUid: String): Flow<List<com.arc.arc.core.model.BudgetModel>> = flowOf(emptyList())
        override suspend fun getTransactions(ownerUid: String): List<TransactionModel> = List(count) {
            TransactionModel(id = "tx_$it", ownerUid = ownerUid, amount = 10.0, type = "Expense")
        }
        override suspend fun getTransactionById(id: String, ownerUid: String): TransactionModel? = null
        override suspend fun saveTransaction(transaction: TransactionModel): Result<Unit> = Result.success(Unit)
        override suspend fun deleteTransaction(id: String, ownerUid: String): Result<Unit> = Result.success(Unit)
        override suspend fun getBudget(ownerUid: String, month: String): com.arc.arc.core.model.BudgetModel? = null
        override suspend fun saveBudget(budget: com.arc.arc.core.model.BudgetModel): Result<Unit> = Result.success(Unit)
        override suspend fun deleteBudget(ownerUid: String, month: String): Result<Unit> = Result.success(Unit)
        override suspend fun getMonthlySummary(ownerUid: String, month: String): MonthlySummaryModel =
            MonthlySummaryModel(month = "2026-03", ownerUid = ownerUid)
        override suspend fun calculateIncomePaise(ownerUid: String, startDate: Long, endDate: Long): Long = 0L
        override suspend fun calculateExpensesPaise(ownerUid: String, startDate: Long, endDate: Long): Long = 0L
        override suspend fun calculateBalancePaise(ownerUid: String, startDate: Long, endDate: Long): Long = 0L
        override suspend fun syncPending(ownerUid: String): SyncResult = SyncResult.Success(0)
    }

    private class FakeSettingsSecretNoteRepository : ISecretNoteRepository {
        var count = 4
        override fun getNotesFlow(ownerUid: String, dek: ByteArray): Flow<List<SecretNoteModel>> = flowOf(emptyList())
        override suspend fun getNotes(ownerUid: String, dek: ByteArray): List<SecretNoteModel> = emptyList()
        override suspend fun getNoteById(id: String, ownerUid: String, dek: ByteArray): SecretNoteModel? = null
        override suspend fun saveNote(note: SecretNoteModel, dek: ByteArray): Result<Unit> = Result.success(Unit)
        override suspend fun deleteNote(id: String, ownerUid: String): Result<Unit> = Result.success(Unit)
        override suspend fun deleteAllForUser(ownerUid: String): Result<Unit> = Result.success(Unit)
        override suspend fun getNoteCount(ownerUid: String): Int = count
        override suspend fun getRawEntities(ownerUid: String): List<SecretNoteEntity> = emptyList()
    }

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        testScope = CoroutineScope(testDispatcher + SupervisorJob())
        val dataStoreFile = File(tmpFolder.newFolder(), "settings_test.preferences_pb")
        val testDataStore = PreferenceDataStoreFactory.create(
            scope = testScope,
            produceFile = { dataStoreFile }
        )
        preferencesDataStore = AppPreferencesDataStore(testDataStore)
        authRepository = DevFakeAuthRepository()
        taskRepository = FakeSettingsTaskRepository()
        habitRepository = FakeSettingsHabitRepository()
        transactionRepository = FakeSettingsTransactionRepository()
        secretNoteRepository = FakeSettingsSecretNoteRepository()

        viewModel = SettingsViewModel(
            preferencesDataStore = preferencesDataStore,
            authRepository = authRepository,
            taskRepository = taskRepository,
            habitRepository = habitRepository,
            transactionRepository = transactionRepository,
            secretNoteRepository = secretNoteRepository,
        )
    }

    @After
    fun tearDown() {
        testScope.cancel()
        Dispatchers.resetMain()
    }

    @Test
    fun `theme mode updates and persists reactively`() = runTest(testDispatcher) {
        advanceUntilIdle()
        viewModel.setThemeMode("light")
        advanceUntilIdle()
        assertEquals("light", viewModel.uiState.value.themeMode)

        viewModel.setThemeMode("system")
        advanceUntilIdle()
        assertEquals("system", viewModel.uiState.value.themeMode)
    }

    @Test
    fun `notification reminder toggles update correctly`() = runTest(testDispatcher) {
        advanceUntilIdle()
        viewModel.setMasterNotifications(false)
        advanceUntilIdle()
        assertFalse(viewModel.uiState.value.masterNotificationsEnabled)

        viewModel.setTaskRemindersEnabled(false)
        advanceUntilIdle()
        assertFalse(viewModel.uiState.value.taskRemindersEnabled)

        viewModel.setHabitRemindersEnabled(false)
        advanceUntilIdle()
        assertFalse(viewModel.uiState.value.habitRemindersEnabled)

        viewModel.setExpenseRemindersEnabled(false)
        advanceUntilIdle()
        assertFalse(viewModel.uiState.value.expenseRemindersEnabled)
    }

    @Test
    fun `reminder times update correctly`() = runTest(testDispatcher) {
        advanceUntilIdle()
        viewModel.setRemTime("08:30")
        advanceUntilIdle()
        assertEquals("08:30", viewModel.uiState.value.remTime)

        viewModel.setEveningCheckinTime("21:15")
        advanceUntilIdle()
        assertEquals("21:15", viewModel.uiState.value.eveningCheckinTime)

        viewModel.setExpenseReminderTime("22:45")
        advanceUntilIdle()
        assertEquals("22:45", viewModel.uiState.value.expenseReminderTime)
    }

    @Test
    fun `database statistics reflect repository counts accurately`() = runTest(testDispatcher) {
        advanceUntilIdle()
        assertEquals(5, viewModel.uiState.value.taskCount)
        assertEquals(3, viewModel.uiState.value.habitCount)
        assertEquals(12, viewModel.uiState.value.transactionCount)
        assertEquals(4, viewModel.uiState.value.secretNoteCount)
    }

    @Test
    fun `sign out delegates to auth repository`() = runTest(testDispatcher) {
        advanceUntilIdle()
        var signedOutTriggered = false
        viewModel.signOut { signedOutTriggered = true }
        advanceUntilIdle()
        assertTrue(signedOutTriggered)
        assertEquals(AuthState.Unauthenticated, authRepository.authState.value)
    }
}
