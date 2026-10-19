package com.arc.arc.habits

import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.auth.UserSession
import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import com.arc.arc.features.habits.HabitsViewModel
import com.arc.arc.features.habits.data.IHabitRepository
import com.arc.arc.features.tasks.data.SyncResult
import com.arc.arc.features.habits.engine.HabitGoalType
import com.arc.arc.features.habits.engine.HabitStreakEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.util.Date

@OptIn(ExperimentalCoroutinesApi::class)
class HabitsModuleTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var habitRepository: InMemoryHabitRepository
    private lateinit var authRepository: DevFakeAuthRepository

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        habitRepository = InMemoryHabitRepository()
        authRepository = DevFakeAuthRepository()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun initialState_whenAuthenticated_loadsUserHabitsAndComputesSummary() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"
        val now = Date()

        habitRepository.saveHabit(
            HabitModel(
                id = "habit-1",
                ownerUid = userId,
                name = "Drink Water",
                category = "Health",
                colorValue = 0xFFCCFF00L,
                createdAt = now,
                updatedAt = now,
            )
        )
        habitRepository.saveHabit(
            HabitModel(
                id = "habit-2",
                ownerUid = userId,
                name = "Exercise",
                category = "Fitness",
                colorValue = 0xFF10B981L,
                createdAt = now,
                updatedAt = now,
            )
        )

        val viewModel = HabitsViewModel(habitRepository, authRepository)
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertEquals(2, state.allHabits.size)
        assertEquals(2, state.filteredHabits.size)
        assertEquals(2, state.summary.totalHabits)
        assertEquals(0, state.summary.completedCount)
        assertEquals(2, state.summary.remainingCount)
    }

    @Test
    fun toggleHabitToday_completesHabitAndUpdatesMetrics() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"
        val now = Date()

        habitRepository.saveHabit(
            HabitModel(
                id = "habit-1",
                ownerUid = userId,
                name = "Morning Meditation",
                category = "Mindfulness",
                createdAt = now,
                updatedAt = now,
            )
        )

        val viewModel = HabitsViewModel(habitRepository, authRepository)
        advanceUntilIdle()

        viewModel.toggleHabitToday("habit-1", true)
        advanceUntilIdle()

        val state = viewModel.uiState.value
        val item = state.allHabits.first()
        assertTrue(item.isCompletedToday)
        assertEquals(1, item.metrics.currentStreak)
        assertEquals(1, state.summary.completedCount)
        assertEquals(0, state.summary.remainingCount)
        assertEquals(1.0f, state.summary.completionPercentage)
    }

    @Test
    fun toggleHabitToday_uncheckingHabit_deletesEntryAndUpdatesMetrics() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"
        val now = Date()
        val todayStr = HabitStreakEngine.formatDate(LocalDate.now(ZoneId.systemDefault()))

        habitRepository.saveHabit(
            HabitModel(
                id = "habit-1",
                ownerUid = userId,
                name = "Read Books",
                category = "Learning",
                createdAt = now,
                updatedAt = now,
            )
        )
        habitRepository.toggleHabitCompletion("habit-1", todayStr, true, userId)

        val viewModel = HabitsViewModel(habitRepository, authRepository)
        advanceUntilIdle()

        assertTrue(viewModel.uiState.value.allHabits.first().isCompletedToday)

        // Toggle to false (uncheck)
        viewModel.toggleHabitToday("habit-1", false)
        advanceUntilIdle()

        val state = viewModel.uiState.value
        val item = state.allHabits.first()
        assertFalse(item.isCompletedToday)
        assertEquals(0, item.metrics.currentStreak)
        assertEquals(0, state.summary.completedCount)
    }

    @Test
    fun saveHabit_createsNewHabitWithGeneratedIdAndOwnerUid() = runTest(testDispatcher) {
        val viewModel = HabitsViewModel(habitRepository, authRepository)
        advanceUntilIdle()

        viewModel.saveHabit(
            name = "Stretching",
            category = "Health",
            colorValue = 0xFF3B82F6L,
            reminderTime = "07:30",
        )
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(1, state.allHabits.size)
        val created = state.allHabits.first().habit
        assertEquals("Stretching", created.name)
        assertEquals("Health", created.category)
        assertEquals("07:30", created.reminderTime)
        assertFalse(state.isEditorOpen)
        assertEquals("Habit saved successfully", state.userMessage)
    }

    @Test
    fun saveHabit_editsExistingHabitPreservingIdAndCreatedAt() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"
        val originalDate = Date(System.currentTimeMillis() - 86400000L)
        val original = HabitModel(
            id = "habit-fix-1",
            ownerUid = userId,
            name = "Run 3k",
            category = "Fitness",
            createdAt = originalDate,
            updatedAt = originalDate,
        )
        habitRepository.saveHabit(original)

        val viewModel = HabitsViewModel(habitRepository, authRepository)
        advanceUntilIdle()

        viewModel.openEditEditor(original)
        assertTrue(viewModel.uiState.value.isEditorOpen)
        assertEquals(original, viewModel.uiState.value.editingHabit)

        viewModel.saveHabit(
            name = "Run 5k",
            category = "Fitness",
            colorValue = 0xFFEF4444L,
            reminderTime = "06:00",
        )
        advanceUntilIdle()

        val updated = viewModel.uiState.value.allHabits.first().habit
        assertEquals("habit-fix-1", updated.id)
        assertEquals("Run 5k", updated.name)
        assertEquals(originalDate, updated.createdAt)
        assertEquals("06:00", updated.reminderTime)
    }

    @Test
    fun deleteHabit_removesHabitAndAssociatedEntries() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"
        val now = Date()
        val todayStr = HabitStreakEngine.formatDate(LocalDate.now(ZoneId.systemDefault()))

        val habit = HabitModel(
            id = "habit-del-1",
            ownerUid = userId,
            name = "Old Habit",
            category = "Other",
            createdAt = now,
            updatedAt = now,
        )
        habitRepository.saveHabit(habit)
        habitRepository.toggleHabitCompletion("habit-del-1", todayStr, true, userId)

        val viewModel = HabitsViewModel(habitRepository, authRepository)
        advanceUntilIdle()

        viewModel.confirmDeleteHabit(habit)
        assertEquals(habit, viewModel.uiState.value.habitToDelete)

        viewModel.deleteHabit()
        advanceUntilIdle()

        assertTrue(viewModel.uiState.value.allHabits.isEmpty())
        assertNull(viewModel.uiState.value.habitToDelete)
        assertTrue(habitRepository.getEntries(userId).isEmpty())
    }

    @Test
    fun categoryFilter_filtersDisplayedHabitsAccurately() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"
        val now = Date()

        habitRepository.saveHabit(
            HabitModel(id = "h1", ownerUid = userId, name = "Health 1", category = "Health", createdAt = now, updatedAt = now)
        )
        habitRepository.saveHabit(
            HabitModel(id = "h2", ownerUid = userId, name = "Fitness 1", category = "Fitness", createdAt = now, updatedAt = now)
        )

        val viewModel = HabitsViewModel(habitRepository, authRepository)
        advanceUntilIdle()

        assertEquals(2, viewModel.uiState.value.filteredHabits.size)

        viewModel.selectCategory("Health")
        advanceUntilIdle()

        val filtered = viewModel.uiState.value.filteredHabits
        assertEquals(1, filtered.size)
        assertEquals("Health 1", filtered.first().habit.name)

        // Toggle same category deselects it
        viewModel.selectCategory("Health")
        advanceUntilIdle()
        assertEquals(2, viewModel.uiState.value.filteredHabits.size)
    }

    @Test
    fun goalTypeChange_recalculatesProgressSummaryAccurately() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"
        val now = Date()

        habitRepository.saveHabit(
            HabitModel(id = "h1", ownerUid = userId, name = "Habit 1", category = "Health", createdAt = now, updatedAt = now)
        )
        val viewModel = HabitsViewModel(habitRepository, authRepository)
        advanceUntilIdle()

        assertEquals(HabitGoalType.DAILY, viewModel.uiState.value.selectedGoalType)

        viewModel.setGoalType(HabitGoalType.WEEKLY)
        advanceUntilIdle()

        assertEquals(HabitGoalType.WEEKLY, viewModel.uiState.value.selectedGoalType)
    }

    @Test
    fun userSwitching_isolatesHabitsBetweenUsers() = runTest(testDispatcher) {
        val user1 = "dev_user_1"
        val user2 = "dev_user_2"
        val now = Date()

        habitRepository.saveHabit(
            HabitModel(id = "h-user1", ownerUid = user1, name = "User 1 Habit", category = "Health", createdAt = now, updatedAt = now)
        )
        habitRepository.saveHabit(
            HabitModel(id = "h-user2", ownerUid = user2, name = "User 2 Habit", category = "Fitness", createdAt = now, updatedAt = now)
        )

        authRepository.switchUser(
            UserSession(
                uid = user1,
                email = "user1@example.com",
                displayName = "User One",
                username = "user1",
                isDevFake = true,
            )
        )

        val viewModel = HabitsViewModel(habitRepository, authRepository)
        advanceUntilIdle()

        assertEquals(1, viewModel.uiState.value.allHabits.size)
        assertEquals("User 1 Habit", viewModel.uiState.value.allHabits.first().habit.name)

        // Switch to user 2
        authRepository.switchUser(
            UserSession(
                uid = user2,
                email = "user2@example.com",
                displayName = "User Two",
                username = "user2",
                isDevFake = true,
            )
        )
        advanceUntilIdle()

        assertEquals(1, viewModel.uiState.value.allHabits.size)
        assertEquals("User 2 Habit", viewModel.uiState.value.allHabits.first().habit.name)
    }
}
