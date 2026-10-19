package com.arc.arc.features.habits

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.arc.arc.core.auth.AuthState
import com.arc.arc.core.auth.IAuthRepository
import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import com.arc.arc.features.habits.data.IHabitRepository
import com.arc.arc.features.habits.engine.HabitGoalType
import com.arc.arc.features.habits.engine.HabitMetrics
import com.arc.arc.features.habits.engine.HabitProgressSummary
import com.arc.arc.features.habits.engine.HabitStreakEngine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId
import java.util.Date
import java.util.UUID

data class HabitItemUiState(
    val habit: HabitModel,
    val metrics: HabitMetrics,
    val last7DaysStatus: List<Pair<LocalDate, Boolean>>,
    val isCompletedToday: Boolean,
)

data class HabitsUiState(
    val allHabits: List<HabitItemUiState> = emptyList(),
    val filteredHabits: List<HabitItemUiState> = emptyList(),
    val summary: HabitProgressSummary = HabitProgressSummary(0, 0, 0, 0f, 0, 0, 0f),
    val selectedGoalType: HabitGoalType = HabitGoalType.DAILY,
    val selectedCategory: String? = null,
    val isLoading: Boolean = false,
    val isEditorOpen: Boolean = false,
    val editingHabit: HabitModel? = null,
    val habitToDelete: HabitModel? = null,
    val userMessage: String? = null,
)

object HabitConstants {
    val CATEGORIES = listOf("Health", "Fitness", "Learning", "Mindfulness", "Productivity", "Other")
    val PRESET_COLORS = listOf(
        0xFFCCFF00L, // Neon Lime (ARC Accent)
        0xFF10B981L, // Emerald
        0xFF3B82F6L, // Blue
        0xFFEAB308L, // Amber
        0xFFEF4444L, // Rose
        0xFFA855F7L, // Purple
    )
}

class HabitsViewModel(
    private val habitRepository: IHabitRepository,
    private val authRepository: IAuthRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(HabitsUiState(isLoading = true))
    val uiState: StateFlow<HabitsUiState> = _uiState.asStateFlow()

    private var currentUserId: String = ""
    private val _selectedGoalType = MutableStateFlow(HabitGoalType.DAILY)
    private val _selectedCategory = MutableStateFlow<String?>(null)

    init {
        viewModelScope.launch {
            authRepository.authState.collectLatest { authState ->
                when (authState) {
                    is AuthState.Authenticated -> {
                        currentUserId = authState.user.uid
                        observeUserHabits(currentUserId)
                    }
                    else -> {
                        currentUserId = ""
                        _uiState.update { HabitsUiState(isLoading = false) }
                    }
                }
            }
        }
    }

    private fun observeUserHabits(userId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            combine(
                habitRepository.getHabitsFlow(userId),
                habitRepository.getEntriesFlow(userId),
                _selectedGoalType,
                _selectedCategory,
            ) { habits, entries, goalType, category ->
                val today = LocalDate.now(ZoneId.systemDefault())
                val last7Days = HabitStreakEngine.getLastNDays(7, today)

                val habitItemStates = habits.map { habit ->
                    val metrics = HabitStreakEngine.computeHabitMetrics(
                        habitId = habit.id,
                        entries = entries,
                        createdAt = habit.createdAt,
                        targetDate = today,
                    )

                    val habitEntries = entries.filter { it.habitId == habit.id && it.completed }
                    val completedDates = habitEntries.mapNotNull { HabitStreakEngine.parseLocalDate(it.dateStr) }.toSet()

                    val weekStatus = last7Days.map { date ->
                        Pair(date, completedDates.contains(date))
                    }

                    HabitItemUiState(
                        habit = habit,
                        metrics = metrics,
                        last7DaysStatus = weekStatus,
                        isCompletedToday = metrics.isCompletedToday,
                    )
                }

                val summary = HabitStreakEngine.computeHabitsSummary(
                    habits = habits,
                    entries = entries,
                    goalType = goalType,
                    targetDate = today,
                )

                val filtered = if (category.isNullOrBlank()) {
                    habitItemStates
                } else {
                    habitItemStates.filter { it.habit.category.equals(category, ignoreCase = true) }
                }

                Triple(habitItemStates, filtered, summary)
            }.collectLatest { (all, filtered, summary) ->
                _uiState.update { current ->
                    current.copy(
                        allHabits = all,
                        filteredHabits = filtered,
                        summary = summary,
                        isLoading = false,
                    )
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

    fun setGoalType(goalType: HabitGoalType) {
        _selectedGoalType.value = goalType
        _uiState.update { it.copy(selectedGoalType = goalType) }
    }

    fun selectCategory(category: String?) {
        val newCategory = if (_selectedCategory.value == category) null else category
        _selectedCategory.value = newCategory
        _uiState.update { it.copy(selectedCategory = newCategory) }
    }

    fun openCreateEditor() {
        _uiState.update { it.copy(isEditorOpen = true, editingHabit = null) }
    }

    fun openEditEditor(habit: HabitModel) {
        _uiState.update { it.copy(isEditorOpen = true, editingHabit = habit) }
    }

    fun closeEditor() {
        _uiState.update { it.copy(isEditorOpen = false, editingHabit = null) }
    }

    fun saveHabit(name: String, category: String, colorValue: Long, reminderTime: String?) {
        val uid = currentUserId
        if (uid.isBlank() || name.isBlank()) return

        val now = Date()
        val habitToSave = _uiState.value.editingHabit?.copy(
            name = name.trim(),
            category = category.trim().ifBlank { "Other" },
            colorValue = colorValue,
            reminderTime = reminderTime,
            updatedAt = now,
        ) ?: HabitModel(
            id = UUID.randomUUID().toString(),
            ownerUid = uid,
            name = name.trim(),
            category = category.trim().ifBlank { "Other" },
            colorValue = colorValue,
            reminderTime = reminderTime,
            createdAt = now,
            updatedAt = now,
        )

        viewModelScope.launch {
            val result = habitRepository.saveHabit(habitToSave)
            if (result.isSuccess) {
                _uiState.update { it.copy(isEditorOpen = false, editingHabit = null, userMessage = "Habit saved successfully") }
            } else {
                _uiState.update { it.copy(userMessage = result.exceptionOrNull()?.message ?: "Failed to save habit") }
            }
        }
    }

    fun confirmDeleteHabit(habit: HabitModel) {
        _uiState.update { it.copy(habitToDelete = habit) }
    }

    fun dismissDeleteDialog() {
        _uiState.update { it.copy(habitToDelete = null) }
    }

    fun deleteHabit() {
        val uid = currentUserId
        val habit = _uiState.value.habitToDelete ?: return
        if (uid.isBlank()) return

        viewModelScope.launch {
            val result = habitRepository.deleteHabit(habit.id, uid)
            if (result.isSuccess) {
                _uiState.update { it.copy(habitToDelete = null, userMessage = "Habit deleted") }
            } else {
                _uiState.update { it.copy(habitToDelete = null, userMessage = result.exceptionOrNull()?.message ?: "Failed to delete habit") }
            }
        }
    }

    fun clearUserMessage() {
        _uiState.update { it.copy(userMessage = null) }
    }

    companion object {
        fun factory(
            habitRepository: IHabitRepository,
            authRepository: IAuthRepository,
        ): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return HabitsViewModel(habitRepository, authRepository) as T
            }
        }
    }
}
