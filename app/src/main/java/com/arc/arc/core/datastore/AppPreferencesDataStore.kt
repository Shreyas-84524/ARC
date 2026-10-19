package com.arc.arc.core.datastore

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import java.io.IOException

val Context.arcDataStore: DataStore<Preferences> by preferencesDataStore(name = "arc_settings")

data class AppPreferences(
    val themeMode: String = "dark", // "dark", "light", "system"
    val onboardingCompleted: Boolean = true,
    val remTime: String = "09:00",
    val masterNotificationsEnabled: Boolean = true,
    val taskRemindersEnabled: Boolean = true,
    val habitRemindersEnabled: Boolean = true,
    val expenseRemindersEnabled: Boolean = true,
    val eveningCheckinTime: String = "20:00",
    val expenseReminderTime: String = "22:00",
    val activeTaskSort: String = "DueDate",
    val activeTaskCategoryFilter: String? = null,
    val activeTaskStatusFilter: String = "All",
    val activeTaskDateFilter: String = "All",
    val isMoneyDetectionEnabled: Boolean = false,
    val isMoneyAutoSaveEnabled: Boolean = false,
    val hasSeenMoneyPrivacyNotice: Boolean = false,
)

/**
 * DataStore foundation for non-sensitive user preferences and application settings.
 * Sensitive data (credentials, cryptographic keys) must NEVER be stored here.
 */
class AppPreferencesDataStore(
    private val dataStore: DataStore<Preferences>
) {
    companion object {
        val KEY_THEME_MODE = stringPreferencesKey("theme_mode")
        val KEY_ONBOARDING_COMPLETED = booleanPreferencesKey("onboarding_completed")
        val KEY_REM_TIME = stringPreferencesKey("rem_time")
        val KEY_MASTER_NOTIFICATIONS = booleanPreferencesKey("master_notifications_enabled")
        val KEY_TASK_REMINDERS_ENABLED = booleanPreferencesKey("task_reminders_enabled")
        val KEY_HABIT_REMINDERS_ENABLED = booleanPreferencesKey("habit_reminders_enabled")
        val KEY_EXPENSE_REMINDERS_ENABLED = booleanPreferencesKey("expense_reminders_enabled")
        val KEY_EVENING_CHECKIN_TIME = stringPreferencesKey("evening_checkin_time")
        val KEY_EXPENSE_REMINDER_TIME = stringPreferencesKey("expense_reminder_time")
        val KEY_TASK_SORT = stringPreferencesKey("task_sort")
        val KEY_TASK_CATEGORY_FILTER = stringPreferencesKey("task_category_filter")
        val KEY_TASK_STATUS_FILTER = stringPreferencesKey("task_status_filter")
        val KEY_TASK_DATE_FILTER = stringPreferencesKey("task_date_filter")
        val KEY_MONEY_DETECTION_ENABLED = booleanPreferencesKey("money_detection_enabled")
        val KEY_MONEY_AUTOSAVE_ENABLED = booleanPreferencesKey("money_autosave_enabled")
        val KEY_MONEY_PRIVACY_NOTICE_SEEN = booleanPreferencesKey("money_privacy_notice_seen")
    }

    val preferencesFlow: Flow<AppPreferences> = dataStore.data
        .catch { exception ->
            if (exception is IOException) {
                emit(emptyPreferences())
            } else {
                throw exception
            }
        }
        .map { prefs ->
            AppPreferences(
                themeMode = prefs[KEY_THEME_MODE] ?: "dark",
                onboardingCompleted = prefs[KEY_ONBOARDING_COMPLETED] ?: true,
                remTime = prefs[KEY_REM_TIME] ?: "09:00",
                masterNotificationsEnabled = prefs[KEY_MASTER_NOTIFICATIONS] ?: true,
                taskRemindersEnabled = prefs[KEY_TASK_REMINDERS_ENABLED] ?: true,
                habitRemindersEnabled = prefs[KEY_HABIT_REMINDERS_ENABLED] ?: true,
                expenseRemindersEnabled = prefs[KEY_EXPENSE_REMINDERS_ENABLED] ?: true,
                eveningCheckinTime = prefs[KEY_EVENING_CHECKIN_TIME] ?: "20:00",
                expenseReminderTime = prefs[KEY_EXPENSE_REMINDER_TIME] ?: "22:00",
                activeTaskSort = prefs[KEY_TASK_SORT] ?: "DueDate",
                activeTaskCategoryFilter = prefs[KEY_TASK_CATEGORY_FILTER]?.takeIf { it != "ALL" },
                activeTaskStatusFilter = prefs[KEY_TASK_STATUS_FILTER] ?: "All",
                activeTaskDateFilter = prefs[KEY_TASK_DATE_FILTER] ?: "All",
                isMoneyDetectionEnabled = prefs[KEY_MONEY_DETECTION_ENABLED] ?: false,
                isMoneyAutoSaveEnabled = prefs[KEY_MONEY_AUTOSAVE_ENABLED] ?: false,
                hasSeenMoneyPrivacyNotice = prefs[KEY_MONEY_PRIVACY_NOTICE_SEEN] ?: false,
            )
        }

    suspend fun setThemeMode(mode: String) {
        dataStore.edit { prefs ->
            prefs[KEY_THEME_MODE] = mode
        }
    }

    suspend fun setOnboardingCompleted(completed: Boolean) {
        dataStore.edit { prefs ->
            prefs[KEY_ONBOARDING_COMPLETED] = completed
        }
    }

    suspend fun setRemTime(time: String) {
        dataStore.edit { prefs ->
            prefs[KEY_REM_TIME] = time
        }
    }

    suspend fun setMasterNotifications(enabled: Boolean) {
        dataStore.edit { prefs ->
            prefs[KEY_MASTER_NOTIFICATIONS] = enabled
        }
    }

    suspend fun setTaskSort(sort: String) {
        dataStore.edit { prefs ->
            prefs[KEY_TASK_SORT] = sort
        }
    }

    suspend fun setTaskCategoryFilter(category: String?) {
        dataStore.edit { prefs ->
            if (category == null) {
                prefs.remove(KEY_TASK_CATEGORY_FILTER)
            } else {
                prefs[KEY_TASK_CATEGORY_FILTER] = category
            }
        }
    }

    suspend fun setTaskStatusFilter(status: String) {
        dataStore.edit { prefs ->
            prefs[KEY_TASK_STATUS_FILTER] = status
        }
    }

    suspend fun setTaskDateFilter(dateFilter: String) {
        dataStore.edit { prefs ->
            prefs[KEY_TASK_DATE_FILTER] = dateFilter
        }
    }

    suspend fun setMoneyDetectionEnabled(enabled: Boolean) {
        dataStore.edit { prefs ->
            prefs[KEY_MONEY_DETECTION_ENABLED] = enabled
        }
    }

    suspend fun setMoneyAutoSaveEnabled(enabled: Boolean) {
        dataStore.edit { prefs ->
            prefs[KEY_MONEY_AUTOSAVE_ENABLED] = enabled
        }
    }

    suspend fun setMoneyPrivacyNoticeSeen(seen: Boolean) {
        dataStore.edit { prefs ->
            prefs[KEY_MONEY_PRIVACY_NOTICE_SEEN] = seen
        }
    }

    suspend fun setTaskRemindersEnabled(enabled: Boolean) {
        dataStore.edit { prefs ->
            prefs[KEY_TASK_REMINDERS_ENABLED] = enabled
        }
    }

    suspend fun setHabitRemindersEnabled(enabled: Boolean) {
        dataStore.edit { prefs ->
            prefs[KEY_HABIT_REMINDERS_ENABLED] = enabled
        }
    }

    suspend fun setExpenseRemindersEnabled(enabled: Boolean) {
        dataStore.edit { prefs ->
            prefs[KEY_EXPENSE_REMINDERS_ENABLED] = enabled
        }
    }

    suspend fun setEveningCheckinTime(time: String) {
        dataStore.edit { prefs ->
            prefs[KEY_EVENING_CHECKIN_TIME] = time
        }
    }

    suspend fun setExpenseReminderTime(time: String) {
        dataStore.edit { prefs ->
            prefs[KEY_EXPENSE_REMINDER_TIME] = time
        }
    }
}

