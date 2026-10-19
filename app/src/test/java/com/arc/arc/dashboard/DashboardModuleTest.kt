package com.arc.arc.dashboard

import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.auth.UserSession
import com.arc.arc.core.model.HabitModel
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TaskPriority
import com.arc.arc.features.dashboard.DashboardActivityType
import com.arc.arc.features.dashboard.DashboardViewModel
import com.arc.arc.features.habits.engine.HabitStreakEngine
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

@OptIn(ExperimentalCoroutinesApi::class)
class DashboardModuleTest {

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

    private fun getTodayDate(hour: Int = 12): Date {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time
    }

    private fun getFutureDate(daysFromNow: Int): Date {
        return Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, daysFromNow)
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time
    }

    @Test
    fun productivityScore_whenAllTodayTasksAndHabitsCompleted_is100() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"
        val today = getTodayDate()
        val todayStr = HabitStreakEngine.formatDate(LocalDate.now(ZoneId.systemDefault()))

        // 2 tasks for today, both completed
        taskRepository.saveTask(
            TaskModel(id = "t1", ownerUid = userId, title = "Task 1", dueDate = today, completed = true)
        )
        taskRepository.saveTask(
            TaskModel(id = "t2", ownerUid = userId, title = "Task 2", dueDate = today, completed = true)
        )

        // 2 habits, both completed for today
        habitRepository.saveHabit(
            HabitModel(id = "h1", ownerUid = userId, name = "Habit 1")
        )
        habitRepository.saveHabit(
            HabitModel(id = "h2", ownerUid = userId, name = "Habit 2")
        )
        habitRepository.toggleHabitCompletion("h1", todayStr, true, userId)
        habitRepository.toggleHabitCompletion("h2", todayStr, true, userId)

        val viewModel = DashboardViewModel(taskRepository, habitRepository, authRepository)
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(100, state.productivityScore)
        assertEquals(1.0f, state.progressPercentage, 0.01f)
        assertEquals(2, state.completedTodayTasksCount)
        assertEquals(2, state.totalTodayTasksCount)
        assertEquals(2, state.completedTodayHabitsCount)
        assertEquals(2, state.totalHabitsCount)
    }

    @Test
    fun productivityScore_whenHalfCompleted_is50() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"
        val today = getTodayDate()
        val todayStr = HabitStreakEngine.formatDate(LocalDate.now(ZoneId.systemDefault()))

        // 2 tasks for today: 1 completed (50% of task half = 25 pts)
        taskRepository.saveTask(
            TaskModel(id = "t1", ownerUid = userId, title = "Task 1", dueDate = today, completed = true)
        )
        taskRepository.saveTask(
            TaskModel(id = "t2", ownerUid = userId, title = "Task 2", dueDate = today, completed = false)
        )

        // 2 habits: 1 completed (50% of habit half = 25 pts)
        habitRepository.saveHabit(
            HabitModel(id = "h1", ownerUid = userId, name = "Habit 1")
        )
        habitRepository.saveHabit(
            HabitModel(id = "h2", ownerUid = userId, name = "Habit 2")
        )
        habitRepository.toggleHabitCompletion("h1", todayStr, true, userId)

        val viewModel = DashboardViewModel(taskRepository, habitRepository, authRepository)
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(50, state.productivityScore)
        assertEquals(0.5f, state.progressPercentage, 0.01f)
    }

    @Test
    fun productivityScore_whenNoTasksOrHabits_isZero() = runTest(testDispatcher) {
        val viewModel = DashboardViewModel(taskRepository, habitRepository, authRepository)
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(0, state.productivityScore)
        assertEquals(0f, state.progressPercentage)
        assertEquals(0, state.totalTodayTasksCount)
        assertEquals(0, state.totalHabitsCount)
    }

    @Test
    fun todayHabits_listsAllHabitsWithAccurateCompletionStatus() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"
        val todayStr = HabitStreakEngine.formatDate(LocalDate.now(ZoneId.systemDefault()))

        habitRepository.saveHabit(
            HabitModel(id = "h1", ownerUid = userId, name = "Read")
        )
        habitRepository.saveHabit(
            HabitModel(id = "h2", ownerUid = userId, name = "Workout")
        )
        habitRepository.toggleHabitCompletion("h1", todayStr, true, userId)

        val viewModel = DashboardViewModel(taskRepository, habitRepository, authRepository)
        advanceUntilIdle()

        val habits = viewModel.uiState.value.todayHabits
        assertEquals(2, habits.size)

        val h1 = habits.first { it.habit.id == "h1" }
        assertTrue(h1.isCompletedToday)

        val h2 = habits.first { it.habit.id == "h2" }
        assertFalse(h2.isCompletedToday)
    }

    @Test
    fun toggleHabitToday_updatesHabitCompletionAndScoreReactively() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"

        habitRepository.saveHabit(
            HabitModel(id = "h1", ownerUid = userId, name = "Meditate")
        )

        val viewModel = DashboardViewModel(taskRepository, habitRepository, authRepository)
        advanceUntilIdle()

        assertEquals(0, viewModel.uiState.value.productivityScore)
        assertFalse(viewModel.uiState.value.todayHabits.first().isCompletedToday)

        // Toggle habit completed from dashboard
        viewModel.toggleHabitToday("h1", true)
        advanceUntilIdle()

        assertTrue(viewModel.uiState.value.todayHabits.first().isCompletedToday)
        assertEquals(50, viewModel.uiState.value.productivityScore) // 100% of habit score (50 pts)
    }

    @Test
    fun toggleTask_updatesTaskCompletionAndScoreReactively() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"
        val today = getTodayDate()

        taskRepository.saveTask(
            TaskModel(id = "t1", ownerUid = userId, title = "Write Code", dueDate = today, completed = false)
        )

        val viewModel = DashboardViewModel(taskRepository, habitRepository, authRepository)
        advanceUntilIdle()

        assertEquals(0, viewModel.uiState.value.productivityScore)
        assertFalse(viewModel.uiState.value.todayTasks.first().completed)

        // Toggle task
        viewModel.toggleTask("t1")
        advanceUntilIdle()

        assertTrue(viewModel.uiState.value.todayTasks.first().completed)
        assertEquals(50, viewModel.uiState.value.productivityScore) // 100% of task score (50 pts)
        assertEquals("Task Completed", viewModel.uiState.value.userMessage)
    }

    @Test
    fun upcomingDeadlines_identifiesFuturePendingTasksSortedByDate() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"

        val day3 = getFutureDate(3)
        val day5 = getFutureDate(5)
        val day1 = getFutureDate(1)

        taskRepository.saveTask(
            TaskModel(id = "t3", ownerUid = userId, title = "Task in 3 days", dueDate = day3, completed = false)
        )
        taskRepository.saveTask(
            TaskModel(id = "t5", ownerUid = userId, title = "Task in 5 days", dueDate = day5, completed = false)
        )
        taskRepository.saveTask(
            TaskModel(id = "t1", ownerUid = userId, title = "Task in 1 day", dueDate = day1, completed = false)
        )
        taskRepository.saveTask(
            TaskModel(id = "t-done", ownerUid = userId, title = "Completed Future", dueDate = day1, completed = true)
        )

        val viewModel = DashboardViewModel(taskRepository, habitRepository, authRepository)
        advanceUntilIdle()

        val deadlines = viewModel.uiState.value.upcomingDeadlines
        assertEquals(3, deadlines.size)
        // Earliest deadline first
        assertEquals("t1", deadlines[0].task.id)
        assertEquals("t3", deadlines[1].task.id)
        assertEquals("t5", deadlines[2].task.id)
    }

    @Test
    fun recentActivities_combinesTasksAndHabitsInReverseChronologicalOrder() = runTest(testDispatcher) {
        val userId = authRepository.currentUserId ?: "dev_uid_shreyas"
        val t1Date = Date(1000000000L)
        val t2Date = Date(3000000000L)

        taskRepository.saveTask(
            TaskModel(id = "t1", ownerUid = userId, title = "Older Task", updatedAt = t1Date)
        )
        taskRepository.saveTask(
            TaskModel(id = "t2", ownerUid = userId, title = "Newer Task", updatedAt = t2Date)
        )

        val viewModel = DashboardViewModel(taskRepository, habitRepository, authRepository)
        advanceUntilIdle()

        val activities = viewModel.uiState.value.recentActivities
        assertEquals(2, activities.size)
        assertEquals("Newer Task", activities[0].title)
        assertEquals(DashboardActivityType.TASK, activities[0].type)
        assertEquals("Older Task", activities[1].title)
    }

    @Test
    fun userIsolation_switchingUser_clearsAndLoadsNewUserData() = runTest(testDispatcher) {
        val user1 = "user_shreyas"
        val user2 = "user_aman"
        val today = getTodayDate()

        taskRepository.saveTask(
            TaskModel(id = "t-u1", ownerUid = user1, title = "Shreyas Task", dueDate = today)
        )
        taskRepository.saveTask(
            TaskModel(id = "t-u2", ownerUid = user2, title = "Aman Task", dueDate = today)
        )

        authRepository.switchUser(
            UserSession(uid = user1, email = "shreyas@arc.local", displayName = "Shreyas", username = "shreyas", isDevFake = true)
        )

        val viewModel = DashboardViewModel(taskRepository, habitRepository, authRepository)
        advanceUntilIdle()

        assertEquals(1, viewModel.uiState.value.todayTasks.size)
        assertEquals("Shreyas Task", viewModel.uiState.value.todayTasks.first().title)

        // Switch to Aman
        authRepository.switchUser(
            UserSession(uid = user2, email = "aman@arc.local", displayName = "Aman", username = "aman", isDevFake = true)
        )
        advanceUntilIdle()

        assertEquals(1, viewModel.uiState.value.todayTasks.size)
        assertEquals("Aman Task", viewModel.uiState.value.todayTasks.first().title)
    }
}
