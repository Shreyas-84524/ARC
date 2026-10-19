package com.arc.arc.integration

import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.auth.UserSession
import com.arc.arc.core.datastore.AppPreferencesDataStore
import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TaskPriority
import com.arc.arc.features.dashboard.DashboardViewModel
import com.arc.arc.features.habits.HabitsViewModel
import com.arc.arc.features.habits.engine.HabitStreakEngine
import com.arc.arc.features.tasks.data.SyncResult
import com.arc.arc.habits.InMemoryHabitRepository
import com.arc.arc.tasks.InMemoryTaskRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.util.Calendar
import java.util.Date

/**
 * End-to-end integration test suite verifying the reactive integration
 * between Tasks, Habits, Dashboard, Multi-User Isolation, and Cloud Sync readiness.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class OfflineProductivityIntegrationTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var taskRepository: InMemoryTaskRepository
    private lateinit var habitRepository: InMemoryHabitRepository
    private lateinit var authRepository: DevFakeAuthRepository

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        taskRepository = InMemoryTaskRepository()
        habitRepository = InMemoryHabitRepository()
        authRepository = DevFakeAuthRepository()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun getTodayDate(): Date {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time
    }

    @Test
    fun crossModule_whenTaskAndHabitCompleted_dashboardScoreAndProgressUpdateInSync() = runTest(testDispatcher) {
        val user = authRepository.currentUserSession!!
        val today = getTodayDate()

        // 1. Create a task scheduled for today
        taskRepository.saveTask(
            TaskModel(
                id = "task-integration-1",
                ownerUid = user.uid,
                title = "Ship Phase 2",
                category = "Productivity",
                dueDate = today,
                completed = false,
            )
        )

        // 2. Create a habit
        habitRepository.saveHabit(
            HabitModel(
                id = "habit-integration-1",
                ownerUid = user.uid,
                name = "Deep Work",
                category = "Productivity",
            )
        )

        val habitsViewModel = HabitsViewModel(habitRepository, authRepository)
        val dashboardViewModel = DashboardViewModel(taskRepository, habitRepository, authRepository)
        advanceUntilIdle()

        // Initial state: 0% completion, Score = 0
        assertEquals(0, dashboardViewModel.uiState.value.productivityScore)
        assertEquals(0f, dashboardViewModel.uiState.value.progressPercentage)
        assertEquals(1, dashboardViewModel.uiState.value.totalTodayTasksCount)
        assertEquals(1, dashboardViewModel.uiState.value.totalHabitsCount)

        // Complete the task from Tasks repository
        taskRepository.toggleTaskCompletion("task-integration-1", user.uid)
        advanceUntilIdle()

        // Dashboard immediately updates: task half is 50 pts
        assertEquals(50, dashboardViewModel.uiState.value.productivityScore)
        assertEquals(0.5f, dashboardViewModel.uiState.value.progressPercentage, 0.01f)
        assertEquals(1, dashboardViewModel.uiState.value.completedTodayTasksCount)

        // Complete habit from HabitsViewModel
        habitsViewModel.toggleHabitToday("habit-integration-1", true)
        advanceUntilIdle()

        // Dashboard immediately updates: total score is 100
        assertEquals(100, dashboardViewModel.uiState.value.productivityScore)
        assertEquals(1.0f, dashboardViewModel.uiState.value.progressPercentage, 0.01f)
        assertEquals(1, dashboardViewModel.uiState.value.completedTodayHabitsCount)
    }

    @Test
    fun crossModule_habitDeletionInHabits_cascadesEntriesAndReflectsInDashboard() = runTest(testDispatcher) {
        val user = authRepository.currentUserSession!!
        val todayStr = HabitStreakEngine.formatDate(LocalDate.now(ZoneId.systemDefault()))

        val habit = HabitModel(
            id = "habit-to-cascade",
            ownerUid = user.uid,
            name = "Morning Walk",
            category = "Health",
        )
        habitRepository.saveHabit(habit)
        habitRepository.toggleHabitCompletion("habit-to-cascade", todayStr, true, user.uid)

        val habitsViewModel = HabitsViewModel(habitRepository, authRepository)
        val dashboardViewModel = DashboardViewModel(taskRepository, habitRepository, authRepository)
        advanceUntilIdle()

        assertEquals(1, dashboardViewModel.uiState.value.totalHabitsCount)
        assertEquals(1, dashboardViewModel.uiState.value.completedTodayHabitsCount)
        assertEquals(50, dashboardViewModel.uiState.value.productivityScore)

        // Delete habit from HabitsViewModel
        habitsViewModel.confirmDeleteHabit(habit)
        habitsViewModel.deleteHabit()
        advanceUntilIdle()

        // Dashboard reflects 0 habits and 0 entries automatically
        assertEquals(0, dashboardViewModel.uiState.value.totalHabitsCount)
        assertEquals(0, dashboardViewModel.uiState.value.completedTodayHabitsCount)
        assertEquals(0, dashboardViewModel.uiState.value.productivityScore)
        assertTrue(habitRepository.getEntries(user.uid).isEmpty())
    }

    @Test
    fun multiUser_switchingUser_isolatesProductivityMetricsAcrossAllViewModels() = runTest(testDispatcher) {
        val userShreyas = UserSession(
            uid = "user_shreyas",
            email = "shreyas@arc.local",
            displayName = "Shreyas",
            username = "shreyas",
            isDevFake = true,
        )
        val userAman = UserSession(
            uid = "user_aman",
            email = "aman@arc.local",
            displayName = "Aman",
            username = "aman",
            isDevFake = true,
        )

        val today = getTodayDate()
        val todayStr = HabitStreakEngine.formatDate(LocalDate.now(ZoneId.systemDefault()))

        // Setup User Shreyas data (completed task + habit -> 100%)
        taskRepository.saveTask(
            TaskModel(id = "task-shreyas", ownerUid = userShreyas.uid, title = "Shreyas Task", dueDate = today, completed = true)
        )
        habitRepository.saveHabit(
            HabitModel(id = "habit-shreyas", ownerUid = userShreyas.uid, name = "Shreyas Habit")
        )
        habitRepository.toggleHabitCompletion("habit-shreyas", todayStr, true, userShreyas.uid)

        // Setup User Aman data (empty, 0%)
        authRepository.switchUser(userShreyas)

        val habitsViewModel = HabitsViewModel(habitRepository, authRepository)
        val dashboardViewModel = DashboardViewModel(taskRepository, habitRepository, authRepository)
        advanceUntilIdle()

        // User Shreyas sees 100% score
        assertEquals(100, dashboardViewModel.uiState.value.productivityScore)
        assertEquals(1, habitsViewModel.uiState.value.allHabits.size)

        // Switch to Aman
        authRepository.switchUser(userAman)
        advanceUntilIdle()

        // User Aman sees 0% score and 0 habits
        assertEquals(0, dashboardViewModel.uiState.value.productivityScore)
        assertEquals(0, dashboardViewModel.uiState.value.totalTodayTasksCount)
        assertEquals(0, dashboardViewModel.uiState.value.totalHabitsCount)
        assertEquals(0, habitsViewModel.uiState.value.allHabits.size)

        // Aman adds a habit
        habitRepository.saveHabit(
            HabitModel(id = "habit-aman", ownerUid = userAman.uid, name = "Aman Habit")
        )
        advanceUntilIdle()

        assertEquals(1, habitsViewModel.uiState.value.allHabits.size)
        assertEquals("Aman Habit", habitsViewModel.uiState.value.allHabits.first().habit.name)

        // Switch back to Shreyas
        authRepository.switchUser(userShreyas)
        advanceUntilIdle()

        // Shreyas still has his original 100% score and 1 habit
        assertEquals(100, dashboardViewModel.uiState.value.productivityScore)
        assertEquals(1, habitsViewModel.uiState.value.allHabits.size)
        assertEquals("Shreyas Habit", habitsViewModel.uiState.value.allHabits.first().habit.name)
    }

    @Test
    fun offlineCloudSyncReadiness_verifyFirestoreContractFidelity() = runTest(testDispatcher) {
        val user = authRepository.currentUserSession!!
        assertTrue(user.isDevFake)

        // 1. Repositories report PendingOffline with no actual network calls
        val taskSyncResult = taskRepository.syncPending(user.uid)
        assertTrue(taskSyncResult is SyncResult.PendingOffline)

        val habitSyncResult = habitRepository.syncPending(user.uid)
        assertTrue(habitSyncResult is SyncResult.PendingOffline)

        // 2. Verify Firestore document serialization fidelity
        val now = Date()
        val task = TaskModel(
            id = "task-sync-1",
            ownerUid = user.uid,
            title = "Test Task",
            description = "Test Desc",
            priority = "Must",
            category = "Work",
            dueDate = now,
            completed = true,
            createdAt = now,
            updatedAt = now,
        )
        val taskMap = task.toMap()
        assertEquals("task-sync-1", taskMap["id"])
        assertEquals("Test Task", taskMap["title"])
        assertEquals("Must", taskMap["priority"])
        assertEquals(true, taskMap["completed"])

        val habit = HabitModel(
            id = "habit-sync-1",
            ownerUid = user.uid,
            name = "Exercise",
            category = "Fitness",
            colorValue = 0xFFCCFF00L,
            createdAt = now,
            updatedAt = now,
        )
        val habitMap = habit.toMap()
        assertEquals("habit-sync-1", habitMap["id"])
        assertEquals("Exercise", habitMap["name"])
        assertEquals(0xFFCCFF00L, habitMap["colorValue"])

        val entry = HabitEntryModel(
            id = "habit-sync-1_2026-10-18",
            ownerUid = user.uid,
            habitId = "habit-sync-1",
            dateStr = "2026-10-18",
            completed = true,
        )
        val entryMap = entry.toMap()
        assertEquals("habit-sync-1_2026-10-18", entryMap["id"])
        assertEquals("habit-sync-1", entryMap["habitId"])
        assertEquals("2026-10-18", entryMap["dateStr"])
        assertEquals(true, entryMap["completed"])
    }
}
