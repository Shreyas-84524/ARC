package com.arc.arc.features.tasks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.arc.arc.core.auth.IAuthRepository
import com.arc.arc.core.datastore.AppPreferencesDataStore
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TaskPriority
import com.arc.arc.features.tasks.data.ITaskRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.Calendar
import java.util.Date
import java.util.UUID

enum class TaskStatusFilter(val displayName: String) {
    ALL("All Tasks"),
    PENDING("Pending"),
    UPCOMING("Upcoming"),
    OVERDUE("Overdue"),
    COMPLETED("Completed"),
}

enum class TaskSort(val displayName: String) {
    DUE_DATE("Due Date"),
    PRIORITY("Priority"),
    CREATION_DATE("Creation Date"),
    ALPHABETICAL("Alphabetical"),
}

data class TaskStatistics(
    val totalTasks: Int = 0,
    val completedTasks: Int = 0,
    val pendingTasks: Int = 0,
    val overdueTasks: Int = 0,
    val upcomingTasks: Int = 0,
    val todayTasks: Int = 0,
    val completionPercentage: Int = 0,
)

data class TasksUiState(
    val rawTasks: List<TaskModel> = emptyList(),
    val filteredTasks: List<TaskModel> = emptyList(),
    val statistics: TaskStatistics = TaskStatistics(),
    val statusFilter: TaskStatusFilter = TaskStatusFilter.PENDING,
    val categoryFilter: String? = null,
    val sortOption: TaskSort = TaskSort.DUE_DATE,
    val searchQuery: String = "",
    val editingTask: TaskModel? = null,
    val isEditorOpen: Boolean = false,
    val deletingTask: TaskModel? = null,
    val isDeleteDialogOpen: Boolean = false,
    val lastToggledTaskId: String? = null,
    val lastToggledWasCompleted: Boolean = false,
    val isLoading: Boolean = false,
    val userFeedbackMessage: String? = null,
)

class TasksViewModel(
    private val taskRepository: ITaskRepository,
    private val authRepository: IAuthRepository,
    private val preferencesDataStore: AppPreferencesDataStore,
) : ViewModel() {

    private val _uiState = MutableStateFlow(TasksUiState())
    val uiState: StateFlow<TasksUiState> = _uiState.asStateFlow()

    private val currentOwnerUid: String
        get() = authRepository.currentUserId ?: "dev_uid_shreyas"

    init {
        observeTasks()
    }

    private fun observeTasks() {
        viewModelScope.launch {
            authRepository.authState.collectLatest { _ ->
                taskRepository.getTasksFlow(currentOwnerUid).collectLatest { tasks ->
                    _uiState.update { current ->
                        val stats = computeStatistics(tasks)
                        val filtered = applyFiltersAndSort(
                            tasks = tasks,
                            status = current.statusFilter,
                            category = current.categoryFilter,
                            sort = current.sortOption,
                            query = current.searchQuery
                        )
                        current.copy(
                            rawTasks = tasks,
                            filteredTasks = filtered,
                            statistics = stats,
                        )
                    }
                }
            }
        }
    }

    fun setStatusFilter(filter: TaskStatusFilter) {
        _uiState.update { current ->
            val filtered = applyFiltersAndSort(
                tasks = current.rawTasks,
                status = filter,
                category = current.categoryFilter,
                sort = current.sortOption,
                query = current.searchQuery
            )
            current.copy(statusFilter = filter, filteredTasks = filtered)
        }
    }

    fun setCategoryFilter(category: String?) {
        _uiState.update { current ->
            val filtered = applyFiltersAndSort(
                tasks = current.rawTasks,
                status = current.statusFilter,
                category = category,
                sort = current.sortOption,
                query = current.searchQuery
            )
            current.copy(categoryFilter = category, filteredTasks = filtered)
        }
    }

    fun setSortOption(sort: TaskSort) {
        _uiState.update { current ->
            val filtered = applyFiltersAndSort(
                tasks = current.rawTasks,
                status = current.statusFilter,
                category = current.categoryFilter,
                sort = sort,
                query = current.searchQuery
            )
            current.copy(sortOption = sort, filteredTasks = filtered)
        }
    }

    fun setSearchQuery(query: String) {
        _uiState.update { current ->
            val filtered = applyFiltersAndSort(
                tasks = current.rawTasks,
                status = current.statusFilter,
                category = current.categoryFilter,
                sort = current.sortOption,
                query = query
            )
            current.copy(searchQuery = query, filteredTasks = filtered)
        }
    }

    fun openCreateTask() {
        _uiState.update { it.copy(editingTask = null, isEditorOpen = true) }
    }

    fun openEditTask(task: TaskModel) {
        _uiState.update { it.copy(editingTask = task, isEditorOpen = true) }
    }

    fun closeEditor() {
        _uiState.update { it.copy(editingTask = null, isEditorOpen = false) }
    }

    fun saveTask(
        title: String,
        description: String,
        category: String,
        priority: String,
        labels: List<String>,
        dueDate: Date?,
        dueTime: String?,
        reminder: Date?,
    ) {
        val currentEdit = _uiState.value.editingTask
        val now = Date()

        val taskToSave = currentEdit?.copy(
            title = title.trim(),
            description = description.trim(),
            category = category,
            priority = priority,
            labels = labels,
            dueDate = dueDate,
            dueTime = dueTime,
            reminder = reminder,
            updatedAt = now,
        ) ?: TaskModel(
            id = UUID.randomUUID().toString(),
            ownerUid = currentOwnerUid,
            title = title.trim(),
            description = description.trim(),
            category = category,
            priority = priority,
            labels = labels,
            dueDate = dueDate,
            dueTime = dueTime,
            reminder = reminder,
            completed = false,
            createdAt = now,
            updatedAt = now,
        )

        viewModelScope.launch {
            taskRepository.saveTask(taskToSave)
            closeEditor()
        }
    }

    fun toggleTask(taskId: String) {
        viewModelScope.launch {
            val task = _uiState.value.rawTasks.find { it.id == taskId } ?: return@launch
            val wasCompleted = task.completed
            val result = taskRepository.toggleTaskCompletion(taskId, currentOwnerUid)
            if (result.isSuccess) {
                _uiState.update {
                    it.copy(
                        lastToggledTaskId = taskId,
                        lastToggledWasCompleted = wasCompleted,
                        userFeedbackMessage = if (wasCompleted) "Task marked incomplete" else "Task completed",
                    )
                }
            }
        }
    }

    fun undoToggle() {
        val taskId = _uiState.value.lastToggledTaskId ?: return
        toggleTask(taskId)
        _uiState.update { it.copy(lastToggledTaskId = null, userFeedbackMessage = null) }
    }

    fun clearFeedbackMessage() {
        _uiState.update { it.copy(userFeedbackMessage = null) }
    }

    fun requestDelete(task: TaskModel) {
        _uiState.update { it.copy(deletingTask = task, isDeleteDialogOpen = true) }
    }

    fun dismissDeleteDialog() {
        _uiState.update { it.copy(deletingTask = null, isDeleteDialogOpen = false) }
    }

    fun confirmDelete() {
        val task = _uiState.value.deletingTask ?: return
        viewModelScope.launch {
            taskRepository.deleteTask(task.id, currentOwnerUid)
            dismissDeleteDialog()
        }
    }

    // --- Helper calculations matching Flutter ARC logic ---

    companion object {
        fun isTaskOverdue(task: TaskModel, now: Date = Date()): Boolean {
            if (task.completed || task.dueDate == null) return false

            val dueCal = Calendar.getInstance().apply {
                time = task.dueDate
                if (task.dueTime != null && task.dueTime.contains(":")) {
                    val parts = task.dueTime.split(":")
                    set(Calendar.HOUR_OF_DAY, parts.getOrNull(0)?.toIntOrNull() ?: 23)
                    set(Calendar.MINUTE, parts.getOrNull(1)?.toIntOrNull() ?: 59)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                } else {
                    set(Calendar.HOUR_OF_DAY, 23)
                    set(Calendar.MINUTE, 59)
                    set(Calendar.SECOND, 59)
                    set(Calendar.MILLISECOND, 999)
                }
            }
            return now.after(dueCal.time)
        }

        fun isTaskToday(task: TaskModel, now: Date = Date()): Boolean {
            if (task.dueDate == null) return false
            val startOfToday = Calendar.getInstance().apply {
                time = now
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.time

            val endOfToday = Calendar.getInstance().apply {
                time = now
                set(Calendar.HOUR_OF_DAY, 23)
                set(Calendar.MINUTE, 59)
                set(Calendar.SECOND, 59)
                set(Calendar.MILLISECOND, 999)
            }.time

            return !task.dueDate.before(startOfToday) && !task.dueDate.after(endOfToday)
        }

        fun isTaskUpcoming(task: TaskModel, now: Date = Date()): Boolean {
            if (task.dueDate == null) return false
            val endOfToday = Calendar.getInstance().apply {
                time = now
                set(Calendar.HOUR_OF_DAY, 23)
                set(Calendar.MINUTE, 59)
                set(Calendar.SECOND, 59)
                set(Calendar.MILLISECOND, 999)
            }.time
            return task.dueDate.after(endOfToday)
        }

        fun computeStatistics(tasks: List<TaskModel>, now: Date = Date()): TaskStatistics {
            val total = tasks.size
            val completed = tasks.count { it.completed }
            val overdue = tasks.count { isTaskOverdue(it, now) }
            val pending = tasks.count { !it.completed && !isTaskOverdue(it, now) }
            val today = tasks.count { !it.completed && isTaskToday(it, now) && !isTaskOverdue(it, now) }
            val upcoming = tasks.count { !it.completed && isTaskUpcoming(it, now) && !isTaskOverdue(it, now) }
            val percentage = if (total == 0) 0 else ((completed.toDouble() / total.toDouble()) * 100).toInt()

            return TaskStatistics(
                totalTasks = total,
                completedTasks = completed,
                pendingTasks = pending,
                overdueTasks = overdue,
                upcomingTasks = upcoming,
                todayTasks = today,
                completionPercentage = percentage,
            )
        }

        fun applyFiltersAndSort(
            tasks: List<TaskModel>,
            status: TaskStatusFilter,
            category: String?,
            sort: TaskSort,
            query: String,
            now: Date = Date(),
        ): List<TaskModel> {
            var filtered = tasks

            // Search query filter
            if (query.isNotBlank()) {
                val q = query.trim().lowercase()
                filtered = filtered.filter {
                    it.title.lowercase().contains(q) ||
                    it.description.lowercase().contains(q) ||
                    it.labels.any { l -> l.lowercase().contains(q) }
                }
            }

            // Category filter
            if (!category.isNullOrBlank()) {
                filtered = filtered.filter { it.category.equals(category, ignoreCase = true) }
            }

            // Status filter
            filtered = when (status) {
                TaskStatusFilter.ALL -> filtered
                TaskStatusFilter.PENDING -> filtered.filter { !it.completed && !isTaskOverdue(it, now) }
                TaskStatusFilter.UPCOMING -> filtered.filter { !it.completed && isTaskUpcoming(it, now) && !isTaskOverdue(it, now) }
                TaskStatusFilter.OVERDUE -> filtered.filter { !it.completed && isTaskOverdue(it, now) }
                TaskStatusFilter.COMPLETED -> filtered.filter { it.completed }
            }

            // Sorting
            filtered = when (sort) {
                TaskSort.DUE_DATE -> filtered.sortedWith(
                    compareBy<TaskModel> { it.dueDate == null }
                        .thenBy { it.dueDate }
                        .thenBy { it.dueTime ?: "" }
                )
                TaskSort.PRIORITY -> filtered.sortedByDescending { it.priorityEnum.level }
                TaskSort.CREATION_DATE -> filtered.sortedByDescending { it.createdAt.time }
                TaskSort.ALPHABETICAL -> filtered.sortedBy { it.title.lowercase() }
            }

            return filtered
        }

        fun factory(
            taskRepository: ITaskRepository,
            authRepository: IAuthRepository,
            preferencesDataStore: AppPreferencesDataStore,
        ): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return TasksViewModel(taskRepository, authRepository, preferencesDataStore) as T
            }
        }
    }
}
