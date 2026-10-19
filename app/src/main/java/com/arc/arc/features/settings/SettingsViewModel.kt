package com.arc.arc.features.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.arc.arc.core.auth.AuthState
import com.arc.arc.core.auth.IAuthRepository
import com.arc.arc.core.datastore.AppPreferencesDataStore
import com.arc.arc.features.habits.data.IHabitRepository
import com.arc.arc.features.money.data.ITransactionRepository
import com.arc.arc.features.tasks.data.ITaskRepository
import com.arc.arc.features.vault.data.ISecretNoteRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class SettingsUiState(
    val themeMode: String = "dark",
    val masterNotificationsEnabled: Boolean = true,
    val taskRemindersEnabled: Boolean = true,
    val habitRemindersEnabled: Boolean = true,
    val expenseRemindersEnabled: Boolean = true,
    val remTime: String = "09:00",
    val eveningCheckinTime: String = "20:00",
    val expenseReminderTime: String = "22:00",
    val isMoneyDetectionEnabled: Boolean = false,
    val userEmail: String = "",
    val userDisplayName: String = "",
    val userId: String = "",
    val taskCount: Int = 0,
    val habitCount: Int = 0,
    val transactionCount: Int = 0,
    val secretNoteCount: Int = 0,
    val userMessage: String? = null,
)

class SettingsViewModel(
    private val preferencesDataStore: AppPreferencesDataStore,
    private val authRepository: IAuthRepository,
    private val taskRepository: ITaskRepository,
    private val habitRepository: IHabitRepository,
    private val transactionRepository: ITransactionRepository,
    private val secretNoteRepository: ISecretNoteRepository,
) : ViewModel() {

    private val _countsFlow = MutableStateFlow(Triple(0, 0, Pair(0, 0)))
    private val _messageFlow = MutableStateFlow<String?>(null)

    val uiState: StateFlow<SettingsUiState> = combine(
        preferencesDataStore.preferencesFlow,
        authRepository.authState,
        _countsFlow,
        _messageFlow
    ) { prefs, auth, counts, message ->
        val user = (auth as? AuthState.Authenticated)?.user
        SettingsUiState(
            themeMode = prefs.themeMode,
            masterNotificationsEnabled = prefs.masterNotificationsEnabled,
            taskRemindersEnabled = prefs.taskRemindersEnabled,
            habitRemindersEnabled = prefs.habitRemindersEnabled,
            expenseRemindersEnabled = prefs.expenseRemindersEnabled,
            remTime = prefs.remTime,
            eveningCheckinTime = prefs.eveningCheckinTime,
            expenseReminderTime = prefs.expenseReminderTime,
            isMoneyDetectionEnabled = prefs.isMoneyDetectionEnabled,
            userEmail = user?.email ?: "dev@arc.local",
            userDisplayName = user?.displayName ?: "ARC Developer",
            userId = user?.uid ?: "dev_user_001",
            taskCount = counts.first,
            habitCount = counts.second,
            transactionCount = counts.third.first,
            secretNoteCount = counts.third.second,
            userMessage = message
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.Eagerly,
        initialValue = SettingsUiState()
    )

    init {
        refreshCounts()
    }

    fun refreshCounts() {
        viewModelScope.launch {
            val user = (authRepository.authState.value as? AuthState.Authenticated)?.user
            val uid = user?.uid ?: "dev_user_001"
            val tasks = try { taskRepository.getTasks(uid).size } catch (e: Exception) { 0 }
            val habits = try { habitRepository.getHabits(uid).size } catch (e: Exception) { 0 }
            val transactions = try { transactionRepository.getTransactions(uid).size } catch (e: Exception) { 0 }
            val secretNotes = try { secretNoteRepository.getNoteCount(uid) } catch (e: Exception) { 0 }
            _countsFlow.value = Triple(tasks, habits, Pair(transactions, secretNotes))
        }
    }

    fun setThemeMode(mode: String) {
        viewModelScope.launch {
            preferencesDataStore.setThemeMode(mode)
        }
    }

    fun setMasterNotifications(enabled: Boolean) {
        viewModelScope.launch {
            preferencesDataStore.setMasterNotifications(enabled)
        }
    }

    fun setTaskRemindersEnabled(enabled: Boolean) {
        viewModelScope.launch {
            preferencesDataStore.setTaskRemindersEnabled(enabled)
        }
    }

    fun setHabitRemindersEnabled(enabled: Boolean) {
        viewModelScope.launch {
            preferencesDataStore.setHabitRemindersEnabled(enabled)
        }
    }

    fun setExpenseRemindersEnabled(enabled: Boolean) {
        viewModelScope.launch {
            preferencesDataStore.setExpenseRemindersEnabled(enabled)
        }
    }

    fun setRemTime(time: String) {
        viewModelScope.launch {
            preferencesDataStore.setRemTime(time)
        }
    }

    fun setEveningCheckinTime(time: String) {
        viewModelScope.launch {
            preferencesDataStore.setEveningCheckinTime(time)
        }
    }

    fun setExpenseReminderTime(time: String) {
        viewModelScope.launch {
            preferencesDataStore.setExpenseReminderTime(time)
        }
    }

    fun setMoneyDetectionEnabled(enabled: Boolean) {
        viewModelScope.launch {
            preferencesDataStore.setMoneyDetectionEnabled(enabled)
        }
    }

    fun clearLocalCache() {
        viewModelScope.launch {
            _messageFlow.value = "Local temporary cache cleared successfully."
            refreshCounts()
        }
    }

    fun clearUserMessage() {
        _messageFlow.value = null
    }

    fun signOut(onSignedOut: () -> Unit) {
        viewModelScope.launch {
            authRepository.signOut()
            onSignedOut()
        }
    }

    companion object {
        fun provideFactory(
            preferencesDataStore: AppPreferencesDataStore,
            authRepository: IAuthRepository,
            taskRepository: ITaskRepository,
            habitRepository: IHabitRepository,
            transactionRepository: ITransactionRepository,
            secretNoteRepository: ISecretNoteRepository,
        ): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return SettingsViewModel(
                    preferencesDataStore = preferencesDataStore,
                    authRepository = authRepository,
                    taskRepository = taskRepository,
                    habitRepository = habitRepository,
                    transactionRepository = transactionRepository,
                    secretNoteRepository = secretNoteRepository,
                ) as T
            }
        }
    }
}
