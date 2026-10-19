package com.arc.arc.tasks

import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.auth.UserSession
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TaskPriority
import com.arc.arc.features.tasks.TaskSort
import com.arc.arc.features.tasks.TaskStatusFilter
import com.arc.arc.features.tasks.TasksViewModel
import com.arc.arc.features.tasks.data.ITaskRepository
import com.arc.arc.features.tasks.data.SyncResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.test.StandardTestDispatcher
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
import java.util.Calendar
import java.util.Date

/**
 * In-memory test repository for isolating Tasks business logic, filters,
 * sorting, statistics, and user isolation in unit test suites.
 */
class InMemoryTaskRepository : ITaskRepository {
    private val store = MutableStateFlow<Map<String, TaskModel>>(emptyMap())

    override fun getTasksFlow(ownerUid: String): Flow<List<TaskModel>> {
        return store.map { map ->
            map.values.filter { it.ownerUid == ownerUid }
        }
    }

    override suspend fun getTasks(ownerUid: String): List<TaskModel> {
        return store.value.values.filter { it.ownerUid == ownerUid }
    }

    override suspend fun getTaskById(id: String, ownerUid: String): TaskModel? {
        return store.value[id]?.takeIf { it.ownerUid == ownerUid }
    }

    override suspend fun saveTask(task: TaskModel): Result<Unit> {
        if (task.title.isBlank()) {
            return Result.failure(IllegalArgumentException("Task title cannot be empty"))
        }
        val current = store.value.toMutableMap()
        current[task.id] = task
        store.value = current
        return Result.success(Unit)
    }

    override suspend fun toggleTaskCompletion(taskId: String, ownerUid: String): Result<TaskModel> {
        val existing = getTaskById(taskId, ownerUid)
            ?: return Result.failure(NoSuchElementException("Task not found"))

        val isNowCompleted = !existing.completed
        val now = Date()
        val updated = existing.copy(
            completed = isNowCompleted,
            completedAt = if (isNowCompleted) now else null,
            updatedAt = now,
        )
        val current = store.value.toMutableMap()
        current[taskId] = updated
        store.value = current
        return Result.success(updated)
    }

    override suspend fun deleteTask(taskId: String, ownerUid: String): Result<Unit> {
        val current = store.value.toMutableMap()
        val removed = current.remove(taskId)
        return if (removed != null && removed.ownerUid == ownerUid) {
            store.value = current
            Result.success(Unit)
        } else {
            Result.failure(NoSuchElementException("Task not found"))
        }
    }

    override suspend fun syncPending(ownerUid: String): SyncResult {
        return SyncResult.PendingOffline(0, "Local-first active")
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class TasksModuleTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var taskRepository: InMemoryTaskRepository
    private lateinit var authRepository: DevFakeAuthRepository

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        taskRepository = InMemoryTaskRepository()
        authRepository = DevFakeAuthRepository(
            initialSession = UserSession(
                uid = "uid_user_a",
                email = "user_a@arc.app",
                displayName = "User A",
                username = "UserA",
            )
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testTaskCreationAndPersistence() = runTest {
        val task = TaskModel(
            id = "task_001",
            ownerUid = "uid_user_a",
            title = "Test Create Task",
            description = "Detailed description",
            priority = "High",
            category = "Work",
            labels = listOf("feature", "tests"),
            dueDate = Date(),
            dueTime = "10:00",
        )

        val saveResult = taskRepository.saveTask(task)
        assertTrue(saveResult.isSuccess)

        val retrieved = taskRepository.getTaskById("task_001", "uid_user_a")
        assertNotNull(retrieved)
        assertEquals("Test Create Task", retrieved!!.title)
        assertEquals("High", retrieved.priority)
        assertEquals(2, retrieved.labels.size)
        assertFalse(retrieved.completed)
    }

    @Test
    fun testTaskCompletionToggleLifecycle() = runTest {
        val task = TaskModel(
            id = "task_toggle",
            ownerUid = "uid_user_a",
            title = "Toggle Me",
            completed = false,
            completedAt = null,
        )
        taskRepository.saveTask(task)

        // Complete the task
        val toggle1 = taskRepository.toggleTaskCompletion("task_toggle", "uid_user_a")
        assertTrue(toggle1.isSuccess)
        val completedTask = toggle1.getOrThrow()
        assertTrue(completedTask.completed)
        assertNotNull(completedTask.completedAt)

        // Uncomplete the task
        val toggle2 = taskRepository.toggleTaskCompletion("task_toggle", "uid_user_a")
        assertTrue(toggle2.isSuccess)
        val uncompletedTask = toggle2.getOrThrow()
        assertFalse(uncompletedTask.completed)
        assertNull(uncompletedTask.completedAt)
    }

    @Test
    fun testUserIsolationEnforcement() = runTest {
        val userATask = TaskModel(
            id = "task_private_a",
            ownerUid = "uid_user_a",
            title = "User A Private Task",
        )
        val userBTask = TaskModel(
            id = "task_private_b",
            ownerUid = "uid_user_b",
            title = "User B Private Task",
        )

        taskRepository.saveTask(userATask)
        taskRepository.saveTask(userBTask)

        // User A must only see their own tasks
        val tasksForA = taskRepository.getTasks("uid_user_a")
        assertEquals(1, tasksForA.size)
        assertEquals("task_private_a", tasksForA.first().id)

        // User B cannot read or delete User A's task
        val crossRead = taskRepository.getTaskById("task_private_a", "uid_user_b")
        assertNull(crossRead)

        val deleteAttempt = taskRepository.deleteTask("task_private_a", "uid_user_b")
        assertFalse(deleteAttempt.isSuccess)
        assertNotNull(taskRepository.getTaskById("task_private_a", "uid_user_a"))
    }

    @Test
    fun testTaskFilteringLogic() {
        val now = Date(1773000000000L) // Fixed baseline
        val overdueDate = Date(1772900000000L) // 1 day before
        val upcomingDate = Date(1773200000000L) // 2 days after

        val tasks = listOf(
            TaskModel(id = "1", title = "Pending Normal", completed = false, dueDate = upcomingDate),
            TaskModel(id = "2", title = "Overdue Task", completed = false, dueDate = overdueDate, dueTime = "08:00"),
            TaskModel(id = "3", title = "Completed Task", completed = true, dueDate = overdueDate),
            TaskModel(id = "4", title = "Health Task", category = "Health", completed = false, dueDate = upcomingDate),
        )

        // Pending filter (excludes completed and overdue)
        val pending = TasksViewModel.applyFiltersAndSort(
            tasks = tasks,
            status = TaskStatusFilter.PENDING,
            category = null,
            sort = TaskSort.CREATION_DATE,
            query = "",
            now = now,
        )
        assertEquals(2, pending.size)
        assertTrue(pending.any { it.id == "1" })
        assertTrue(pending.any { it.id == "4" })

        // Overdue filter
        val overdue = TasksViewModel.applyFiltersAndSort(
            tasks = tasks,
            status = TaskStatusFilter.OVERDUE,
            category = null,
            sort = TaskSort.CREATION_DATE,
            query = "",
            now = now,
        )
        assertEquals(1, overdue.size)
        assertEquals("2", overdue.first().id)

        // Completed filter
        val completed = TasksViewModel.applyFiltersAndSort(
            tasks = tasks,
            status = TaskStatusFilter.COMPLETED,
            category = null,
            sort = TaskSort.CREATION_DATE,
            query = "",
            now = now,
        )
        assertEquals(1, completed.size)
        assertEquals("3", completed.first().id)

        // Category filter
        val healthOnly = TasksViewModel.applyFiltersAndSort(
            tasks = tasks,
            status = TaskStatusFilter.ALL,
            category = "Health",
            sort = TaskSort.CREATION_DATE,
            query = "",
            now = now,
        )
        assertEquals(1, healthOnly.size)
        assertEquals("4", healthOnly.first().id)
    }

    @Test
    fun testSortingOrders() {
        val date1 = Date(1773100000000L)
        val date2 = Date(1773200000000L)

        val tasks = listOf(
            TaskModel(id = "c", title = "Charlie", priority = "Low", dueDate = date2, createdAt = Date(100)),
            TaskModel(id = "a", title = "Alpha", priority = "High", dueDate = date1, createdAt = Date(300)),
            TaskModel(id = "b", title = "Bravo", priority = "Must", dueDate = null, createdAt = Date(200)),
        )

        // Priority sort (High -> Must -> Low)
        val byPriority = TasksViewModel.applyFiltersAndSort(
            tasks, TaskStatusFilter.ALL, null, TaskSort.PRIORITY, ""
        )
        assertEquals(listOf("a", "b", "c"), byPriority.map { it.id })

        // Alphabetical sort (Alpha -> Bravo -> Charlie)
        val byAlpha = TasksViewModel.applyFiltersAndSort(
            tasks, TaskStatusFilter.ALL, null, TaskSort.ALPHABETICAL, ""
        )
        assertEquals(listOf("a", "b", "c"), byAlpha.map { it.id })

        // Creation date sort (newest first: 300 -> 200 -> 100)
        val byCreation = TasksViewModel.applyFiltersAndSort(
            tasks, TaskStatusFilter.ALL, null, TaskSort.CREATION_DATE, ""
        )
        assertEquals(listOf("a", "b", "c"), byCreation.map { it.id })

        // Due date sort (nulls last)
        val byDueDate = TasksViewModel.applyFiltersAndSort(
            tasks, TaskStatusFilter.ALL, null, TaskSort.DUE_DATE, ""
        )
        assertEquals(listOf("a", "c", "b"), byDueDate.map { it.id })
    }

    @Test
    fun testStatisticsCalculation() {
        val now = Date(1773000000000L)
        val overdueDate = Date(1772900000000L)
        val upcomingDate = Date(1773200000000L)

        val tasks = listOf(
            TaskModel(id = "1", title = "T1", completed = false, dueDate = upcomingDate),
            TaskModel(id = "2", title = "T2", completed = false, dueDate = overdueDate),
            TaskModel(id = "3", title = "T3", completed = true),
            TaskModel(id = "4", title = "T4", completed = true),
        )

        val stats = TasksViewModel.computeStatistics(tasks, now = now)
        assertEquals(4, stats.totalTasks)
        assertEquals(2, stats.completedTasks)
        assertEquals(1, stats.pendingTasks)
        assertEquals(1, stats.overdueTasks)
        assertEquals(1, stats.upcomingTasks)
        assertEquals(50, stats.completionPercentage) // 2 / 4 = 50%
    }
}
