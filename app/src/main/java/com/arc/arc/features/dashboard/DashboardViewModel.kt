package com.arc.arc.features.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.arc.arc.core.auth.AuthState
import com.arc.arc.core.auth.IAuthRepository
import com.arc.arc.core.model.BudgetModel
import com.arc.arc.core.model.HabitModel
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.core.utilities.CurrencyFormatter
import com.arc.arc.features.habits.data.IHabitRepository
import com.arc.arc.features.habits.engine.HabitStreakEngine
import com.arc.arc.features.money.data.ITransactionRepository
import com.arc.arc.features.tasks.data.ITaskRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.roundToInt

enum class DashboardActivityType {
    TASK,
    HABIT,
    TRANSACTION,
}

data class DashboardActivityItem(
    val id: String,
    val type: DashboardActivityType,
    val title: String,
    val subtitle: String,
    val timestamp: Date,
    val isCompleted: Boolean,
)

data class DashboardHabitItem(
    val habit: HabitModel,
    val isCompletedToday: Boolean,
    val currentStreak: Int,
)

data class DashboardTaskItem(
    val task: TaskModel,
    val daysUntilDue: Long,
)

data class DashboardUiState(
    val productivityScore: Int = 0,
    val progressPercentage: Float = 0f,
    val completedTodayTasksCount: Int = 0,
    val totalTodayTasksCount: Int = 0,
    val completedTodayHabitsCount: Int = 0,
    val totalHabitsCount: Int = 0,
    val totalTasksCount: Int = 0,
    val completedTasksCount: Int = 0,
    val maxStreakDays: Int = 0,
    val monthlyBudgetPaise: Long = 0L,
    val monthlyExpensesPaise: Long = 0L,
    val remainingBudgetPaise: Long = 0L,
    val todayHabits: List<DashboardHabitItem> = emptyList(),
    val todayTasks: List<TaskModel> = emptyList(),
    val upcomingDeadlines: List<DashboardTaskItem> = emptyList(),
    val recentActivities: List<DashboardActivityItem> = emptyList(),
    val isLoading: Boolean = false,
    val userMessage: String? = null,
)

class DashboardViewModel(
    private val taskRepository: ITaskRepository,
    private val habitRepository: IHabitRepository,
    private val authRepository: IAuthRepository,
    private val transactionRepository: ITransactionRepository? = null,
) : ViewModel() {

    private val _uiState = MutableStateFlow(DashboardUiState(isLoading = true))
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    private var currentUserId: String = ""

    init {
        viewModelScope.launch {
            authRepository.authState.collectLatest { authState ->
                when (authState) {
                    is AuthState.Authenticated -> {
                        currentUserId = authState.user.uid
                        observeDashboard(currentUserId)
                    }
                    else -> {
                        currentUserId = ""
                        _uiState.update { DashboardUiState(isLoading = false) }
                    }
                }
            }
        }
    }

    private fun observeDashboard(userId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            val currentMonthStr = YearMonth.now().toString()
            val transactionsFlow = transactionRepository?.getTransactionsFlow(userId) ?: flowOf(emptyList())
            val budgetFlow = transactionRepository?.getBudgetFlow(userId, currentMonthStr) ?: flowOf(null)

            combine(
                taskRepository.getTasksFlow(userId),
                habitRepository.getHabitsFlow(userId),
                habitRepository.getEntriesFlow(userId),
                transactionsFlow,
                budgetFlow,
            ) { tasks, habits, entries, transactions, budget ->
                val today = LocalDate.now(ZoneId.systemDefault())
                val todayStr = HabitStreakEngine.formatDate(today)

                val (todayStart, todayEnd) = getTodayBounds()

                // 1. Tasks breakdown
                val totalTasks = tasks.size
                val completedTasks = tasks.count { it.completed }

                val todayTasks = tasks.filter { task ->
                    val due = task.dueDate
                    if (due == null) {
                        false
                    } else {
                        !due.before(todayStart) && !due.after(todayEnd)
                    }
                }
                val totalTodayTasks = todayTasks.size
                val completedTodayTasks = todayTasks.count { it.completed }

                // 2. Habits breakdown & streaks
                val totalHabits = habits.size
                val todayEntries = entries.filter { it.dateStr == todayStr && it.completed }
                val completedHabits = todayEntries.size

                var maxStreak = 0
                val dashboardHabits = habits.map { habit ->
                    val metrics = HabitStreakEngine.computeHabitMetrics(
                        habitId = habit.id,
                        entries = entries,
                        createdAt = habit.createdAt,
                        targetDate = today,
                    )
                    if (metrics.currentStreak > maxStreak) {
                        maxStreak = metrics.currentStreak
                    }
                    DashboardHabitItem(
                        habit = habit,
                        isCompletedToday = metrics.isCompletedToday,
                        currentStreak = metrics.currentStreak,
                    )
                }

                // 3. Finances breakdown
                val monthFormat = SimpleDateFormat("yyyy-MM", Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
                val monthlyExpenses = transactions.filter {
                    it.isExpense && monthFormat.format(it.date) == currentMonthStr
                }.sumOf { it.amountPaise }
                val monthlyBudget = budget?.amountPaise ?: 0L
                val remainingBudget = if (monthlyBudget > 0L) monthlyBudget - monthlyExpenses else 0L

                // 4. Productivity Score (0 - 100)
                val taskRate = if (totalTodayTasks > 0) {
                    (completedTodayTasks.toFloat() / totalTodayTasks).coerceIn(0f, 1f)
                } else {
                    0f
                }
                val habitRate = if (totalHabits > 0) {
                    (completedHabits.toFloat() / totalHabits).coerceIn(0f, 1f)
                } else {
                    0f
                }

                val productivityScore = ((taskRate * 50f) + (habitRate * 50f)).roundToInt().coerceIn(0, 100)
                val progressPercentage = productivityScore / 100f

                // 5. Upcoming Deadlines (pending tasks with dueDate > todayEnd)
                val upcomingDeadlines = tasks
                    .filter { !it.completed && it.dueDate != null && it.dueDate.after(todayEnd) }
                    .sortedBy { it.dueDate }
                    .take(3)
                    .map { task ->
                        val diffMillis = (task.dueDate?.time ?: todayEnd.time) - todayStart.time
                        val days = (diffMillis / (1000 * 60 * 60 * 24)).coerceAtLeast(1)
                        DashboardTaskItem(task = task, daysUntilDue = days)
                    }

                // 6. Recent Activity Feed (top 10 events)
                val activities = mutableListOf<DashboardActivityItem>()

                tasks.forEach { t ->
                    activities.add(
                        DashboardActivityItem(
                            id = "task-${t.id}",
                            type = DashboardActivityType.TASK,
                            title = t.title,
                            subtitle = if (t.completed) "Task Completed" else "Task Created (${t.category})",
                            timestamp = t.updatedAt,
                            isCompleted = t.completed,
                        )
                    )
                }

                entries.filter { it.completed }.forEach { e ->
                    val habit = habits.find { it.id == e.habitId }
                    if (habit != null) {
                        val date = HabitStreakEngine.parseLocalDate(e.dateStr)?.let {
                            Date.from(it.atStartOfDay(ZoneId.systemDefault()).toInstant())
                        } ?: habit.updatedAt

                        activities.add(
                            DashboardActivityItem(
                                id = "habit-${e.id}",
                                type = DashboardActivityType.HABIT,
                                title = habit.name,
                                subtitle = "Habit Checked-in",
                                timestamp = date,
                                isCompleted = true,
                            )
                        )
                    }
                }

                transactions.forEach { tx ->
                    activities.add(
                        DashboardActivityItem(
                            id = "tx-${tx.id}",
                            type = DashboardActivityType.TRANSACTION,
                            title = tx.category,
                            subtitle = "${if (tx.isIncome) "+" else "-"}${CurrencyFormatter.formatPaise(tx.amountPaise)} • ${tx.type}",
                            timestamp = tx.date,
                            isCompleted = true,
                        )
                    )
                }

                activities.sortByDescending { it.timestamp }
                val recentActivities = activities.take(10)

                DashboardUiState(
                    productivityScore = productivityScore,
                    progressPercentage = progressPercentage,
                    completedTodayTasksCount = completedTodayTasks,
                    totalTodayTasksCount = totalTodayTasks,
                    completedTodayHabitsCount = completedHabits,
                    totalHabitsCount = totalHabits,
                    totalTasksCount = totalTasks,
                    completedTasksCount = completedTasks,
                    maxStreakDays = maxStreak,
                    monthlyBudgetPaise = monthlyBudget,
                    monthlyExpensesPaise = monthlyExpenses,
                    remainingBudgetPaise = remainingBudget,
                    todayHabits = dashboardHabits,
                    todayTasks = todayTasks,
                    upcomingDeadlines = upcomingDeadlines,
                    recentActivities = recentActivities,
                    isLoading = false,
                )
            }.collectLatest { state ->
                _uiState.update { current ->
                    state.copy(userMessage = current.userMessage)
                }
            }
        }
    }

    fun toggleHabitToday(habitId: String, completed: Boolean) {
        val uid = currentUserId
        if (uid.isBlank()) return

        val todayStr = HabitStreakEngine.formatDate(LocalDate.now(ZoneId.systemDefault()))

        viewModelScope.launch {
            habitRepository.toggleHabitCompletion(habitId, todayStr, completed, uid)
        }
    }

    fun toggleTask(taskId: String) {
        val uid = currentUserId
        if (uid.isBlank()) return

        viewModelScope.launch {
            val result = taskRepository.toggleTaskCompletion(taskId, uid)
            if (result.isSuccess) {
                val task = result.getOrNull()
                val msg = if (task?.completed == true) "Task Completed" else "Task Marked Incomplete"
                _uiState.update { it.copy(userMessage = msg) }
            }
        }
    }

    fun clearUserMessage() {
        _uiState.update { it.copy(userMessage = null) }
    }

    private fun getTodayBounds(): Pair<Date, Date> {
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val start = calendar.time

        calendar.set(Calendar.HOUR_OF_DAY, 23)
        calendar.set(Calendar.MINUTE, 59)
        calendar.set(Calendar.SECOND, 59)
        calendar.set(Calendar.MILLISECOND, 999)
        val end = calendar.time

        return Pair(start, end)
    }

    companion object {
        fun factory(
            taskRepository: ITaskRepository,
            habitRepository: IHabitRepository,
            authRepository: IAuthRepository,
            transactionRepository: ITransactionRepository? = null,
        ): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return DashboardViewModel(taskRepository, habitRepository, authRepository, transactionRepository) as T
            }
        }
    }
}
