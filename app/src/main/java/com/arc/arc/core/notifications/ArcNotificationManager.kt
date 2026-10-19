package com.arc.arc.core.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat
import com.arc.arc.core.datastore.AppPreferences
import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import com.arc.arc.core.model.TaskModel
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

interface IAlarmScheduler {
    fun schedule(
        notificationId: Int,
        triggerAtMillis: Long,
        title: String,
        message: String,
        channelId: String,
        destination: String,
        entityId: String,
    )
    fun cancel(notificationId: Int)
    fun cancelAll()
}

class SystemAlarmScheduler(private val context: Context) : IAlarmScheduler {
    override fun schedule(
        notificationId: Int,
        triggerAtMillis: Long,
        title: String,
        message: String,
        channelId: String,
        destination: String,
        entityId: String,
    ) {
        if (triggerAtMillis <= System.currentTimeMillis()) return

        val intent = Intent(context, ArcReminderReceiver::class.java).apply {
            action = ArcReminderReceiver.ACTION_REMINDER
            putExtra(ArcReminderReceiver.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(ArcReminderReceiver.EXTRA_TITLE, title)
            putExtra(ArcReminderReceiver.EXTRA_MESSAGE, message)
            putExtra(ArcReminderReceiver.EXTRA_CHANNEL_ID, channelId)
            putExtra(ArcReminderReceiver.EXTRA_DESTINATION, destination)
            putExtra(ArcReminderReceiver.EXTRA_ENTITY_ID, entityId)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return

        try {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        } catch (_: SecurityException) {
            try {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            } catch (_: Exception) {}
        }
    }

    override fun cancel(notificationId: Int) {
        val intent = Intent(context, ArcReminderReceiver::class.java).apply {
            action = ArcReminderReceiver.ACTION_REMINDER
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pendingIntent != null) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            alarmManager?.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    override fun cancelAll() {
        val notificationManager = NotificationManagerCompat.from(context)
        notificationManager.cancelAll()
    }
}

interface IArcNotificationManager {
    fun areNotificationsEnabled(): Boolean
    fun scheduleTaskReminders(task: TaskModel)
    fun cancelTaskReminders(taskId: String)
    fun scheduleHabitReminders(habit: HabitModel, completedToday: Boolean, remTime: String)
    fun cancelHabitReminders(habitId: String)
    fun scheduleEveningReminder(incompleteCount: Int, eveningTime: String)
    fun cancelEveningReminder()
    fun scheduleDailyMoneyReminder(remTime: String)
    fun cancelMoneyReminders()
    fun cancelAllUserNotifications()
    fun reconcile(
        ownerUid: String,
        preferences: AppPreferences,
        tasks: List<TaskModel>,
        habits: List<HabitModel>,
        habitEntries: List<HabitEntryModel>,
    )
}

/**
 * Production notification engine managing native notification channels, inexact alarm scheduling,
 * and multi-entity reconciliation.
 *
 * Security & Platform Rules:
 * 1. Zero-Cloud Vault: Secret Notes are NEVER passed to, scheduled by, or exposed in notifications.
 * 2. Exact Alarms: Complies with Google Play policy by using inexact alarms (setAndAllowWhileIdle with fallback)
 *    and NEVER declaring USE_EXACT_ALARM.
 * 3. Android 13+: Respects POST_NOTIFICATIONS permission gracefully.
 */
class ArcNotificationManager(
    private val scheduler: IAlarmScheduler,
    private val isNotificationsEnabledProvider: () -> Boolean = { true },
) : IArcNotificationManager {

    constructor(context: Context) : this(
        scheduler = SystemAlarmScheduler(context),
        isNotificationsEnabledProvider = { NotificationManagerCompat.from(context).areNotificationsEnabled() }
    ) {
        ArcNotificationChannels.createNotificationChannels(context)
    }

    companion object {
        const val MONEY_REMINDER_ID = 888888
        const val EVENING_HABIT_REMINDER_ID = 999999

        private const val TASK_PRE_DEADLINE_MIN = 10000000
        private const val TASK_PRE_DEADLINE_RANGE = 390000000

        private const val TASK_DEADLINE_MIN = 400000000
        private const val TASK_DEADLINE_RANGE = 400000000

        private const val HABIT_DEADLINE_MIN = 800000000
        private const val HABIT_DEADLINE_RANGE = 300000000

        private const val HABIT_REMTIME_MIN = 1100000000
        private const val HABIT_REMTIME_RANGE = 300000000

        /**
         * 31-bit positive DJB2 hash matching Flutter getStableHash implementation.
         */
        fun getStableHash(input: String): Int {
            var hash = 5381
            for (ch in input) {
                hash = ((hash shl 5) + hash) + ch.code
                hash = hash and 0x7FFFFFFF
            }
            return hash
        }

        fun getTaskNotificationId5m(taskId: String): Int {
            return TASK_PRE_DEADLINE_MIN + (getStableHash("task_pre_$taskId") % TASK_PRE_DEADLINE_RANGE)
        }

        fun getTaskNotificationIdDeadline(taskId: String): Int {
            return TASK_DEADLINE_MIN + (getStableHash("task_dead_$taskId") % TASK_DEADLINE_RANGE)
        }

        fun getHabitNotificationIdDeadline(habitId: String): Int {
            return HABIT_DEADLINE_MIN + (getStableHash("habit_dead_$habitId") % HABIT_DEADLINE_RANGE)
        }

        fun getHabitNotificationIdRemTime(habitId: String): Int {
            return HABIT_REMTIME_MIN + (getStableHash("habit_rem_$habitId") % HABIT_REMTIME_RANGE)
        }
    }

    override fun areNotificationsEnabled(): Boolean {
        return isNotificationsEnabledProvider()
    }

    override fun scheduleTaskReminders(task: TaskModel) {
        if (task.completed || task.dueDate == null || task.dueTime.isNullOrBlank()) {
            cancelTaskReminders(task.id)
            return
        }

        val parts = task.dueTime.split(":")
        if (parts.size != 2) return
        val hour = parts[0].toIntOrNull() ?: return
        val minute = parts[1].toIntOrNull() ?: return

        val cal = Calendar.getInstance().apply {
            time = task.dueDate
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val dueMillis = cal.timeInMillis
        val nowMillis = System.currentTimeMillis()

        cancelTaskReminders(task.id)

        // 1. 5 minutes before deadline
        val preMillis = dueMillis - (5 * 60 * 1000L)
        if (preMillis > nowMillis) {
            scheduler.schedule(
                notificationId = getTaskNotificationId5m(task.id),
                triggerAtMillis = preMillis,
                title = "Task due soon",
                message = "${task.title} is due in 5 minutes.",
                channelId = ArcNotificationChannels.CHANNEL_TASKS,
                destination = "tasks",
                entityId = task.id
            )
        }

        // 2. Deadline reached
        if (dueMillis > nowMillis) {
            scheduler.schedule(
                notificationId = getTaskNotificationIdDeadline(task.id),
                triggerAtMillis = dueMillis,
                title = "Task deadline reached",
                message = "${task.title} is due now.",
                channelId = ArcNotificationChannels.CHANNEL_TASKS,
                destination = "tasks",
                entityId = task.id
            )
        }
    }

    override fun cancelTaskReminders(taskId: String) {
        scheduler.cancel(getTaskNotificationId5m(taskId))
        scheduler.cancel(getTaskNotificationIdDeadline(taskId))
    }

    override fun scheduleHabitReminders(habit: HabitModel, completedToday: Boolean, remTime: String) {
        cancelHabitReminders(habit.id)
        if (completedToday) return

        val nowMillis = System.currentTimeMillis()

        // 1. Specific Habit reminderTime
        if (!habit.reminderTime.isNullOrBlank()) {
            val parts = habit.reminderTime.split(":")
            if (parts.size == 2) {
                val hour = parts[0].toIntOrNull()
                val minute = parts[1].toIntOrNull()
                if (hour != null && minute != null) {
                    val habitMillis = calculateTodayMillis(hour, minute)
                    if (habitMillis > nowMillis) {
                        scheduler.schedule(
                            notificationId = getHabitNotificationIdDeadline(habit.id),
                            triggerAtMillis = habitMillis,
                            title = "Habit reminder",
                            message = "Time to complete: ${habit.name}",
                            channelId = ArcNotificationChannels.CHANNEL_HABITS,
                            destination = "habits",
                            entityId = habit.id
                        )
                    }
                }
            }
        }

        // 2. Global remTime reminder
        if (remTime.isNotBlank()) {
            val parts = remTime.split(":")
            if (parts.size == 2) {
                val hour = parts[0].toIntOrNull()
                val minute = parts[1].toIntOrNull()
                if (hour != null && minute != null) {
                    val remTimeMillis = calculateTodayMillis(hour, minute)
                    if (remTimeMillis > nowMillis) {
                        scheduler.schedule(
                            notificationId = getHabitNotificationIdRemTime(habit.id),
                            triggerAtMillis = remTimeMillis,
                            title = "Habit still pending",
                            message = "You haven't completed ${habit.name} today.",
                            channelId = ArcNotificationChannels.CHANNEL_HABITS,
                            destination = "habits",
                            entityId = habit.id
                        )
                    }
                }
            }
        }
    }

    override fun cancelHabitReminders(habitId: String) {
        scheduler.cancel(getHabitNotificationIdDeadline(habitId))
        scheduler.cancel(getHabitNotificationIdRemTime(habitId))
    }

    override fun scheduleEveningReminder(incompleteCount: Int, eveningTime: String) {
        cancelEveningReminder()
        if (incompleteCount <= 0) return

        val parts = eveningTime.split(":")
        val hour = parts.getOrNull(0)?.toIntOrNull() ?: 20
        val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0

        var triggerMillis = calculateTodayMillis(hour, minute)
        if (triggerMillis <= System.currentTimeMillis()) {
            triggerMillis += (24 * 60 * 60 * 1000L) // Next day
        }

        scheduler.schedule(
            notificationId = EVENING_HABIT_REMINDER_ID,
            triggerAtMillis = triggerMillis,
            title = "Habit reminder",
            message = "Don't forget today's habits. You have $incompleteCount incomplete habits left for today.",
            channelId = ArcNotificationChannels.CHANNEL_HABITS,
            destination = "habits",
            entityId = "evening_checkin"
        )
    }

    override fun cancelEveningReminder() {
        scheduler.cancel(EVENING_HABIT_REMINDER_ID)
    }

    override fun scheduleDailyMoneyReminder(remTime: String) {
        cancelMoneyReminders()

        val parts = remTime.split(":")
        val hour = parts.getOrNull(0)?.toIntOrNull() ?: 22
        val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0

        var triggerMillis = calculateTodayMillis(hour, minute)
        if (triggerMillis <= System.currentTimeMillis()) {
            triggerMillis += (24 * 60 * 60 * 1000L)
        }

        scheduler.schedule(
            notificationId = MONEY_REMINDER_ID,
            triggerAtMillis = triggerMillis,
            title = "Update today's spending",
            message = "Don't forget to add today's expenses to ARC.",
            channelId = ArcNotificationChannels.CHANNEL_MONEY,
            destination = "money",
            entityId = "daily_money"
        )
    }

    override fun cancelMoneyReminders() {
        scheduler.cancel(MONEY_REMINDER_ID)
    }

    override fun cancelAllUserNotifications() {
        scheduler.cancel(EVENING_HABIT_REMINDER_ID)
        scheduler.cancel(MONEY_REMINDER_ID)
        scheduler.cancelAll()
    }

    override fun reconcile(
        ownerUid: String,
        preferences: AppPreferences,
        tasks: List<TaskModel>,
        habits: List<HabitModel>,
        habitEntries: List<HabitEntryModel>,
    ) {
        if (ownerUid.isBlank() || !preferences.masterNotificationsEnabled) {
            cancelAllUserNotifications()
            return
        }

        // 1. Reconcile Tasks
        if (preferences.taskRemindersEnabled) {
            tasks.filter { it.ownerUid == ownerUid }.forEach { task ->
                if (task.completed || task.dueDate == null || task.dueTime.isNullOrBlank()) {
                    cancelTaskReminders(task.id)
                } else {
                    scheduleTaskReminders(task)
                }
            }
        } else {
            tasks.filter { it.ownerUid == ownerUid }.forEach { task ->
                cancelTaskReminders(task.id)
            }
        }

        // 2. Reconcile Habits
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val userHabits = habits.filter { it.ownerUid == ownerUid }
        if (preferences.habitRemindersEnabled) {
            var incompleteCount = 0
            userHabits.forEach { habit ->
                val completedToday = habitEntries.any {
                    it.habitId == habit.id && it.dateStr == todayStr && it.completed
                }
                if (!completedToday) incompleteCount++
                scheduleHabitReminders(habit, completedToday, preferences.remTime)
            }

            if (incompleteCount > 0) {
                scheduleEveningReminder(incompleteCount, preferences.eveningCheckinTime)
            } else {
                cancelEveningReminder()
            }
        } else {
            userHabits.forEach { habit ->
                cancelHabitReminders(habit.id)
            }
            cancelEveningReminder()
        }

        // 3. Reconcile Money
        if (preferences.expenseRemindersEnabled) {
            scheduleDailyMoneyReminder(preferences.expenseReminderTime)
        } else {
            cancelMoneyReminders()
        }
    }

    private fun calculateTodayMillis(hour: Int, minute: Int): Long {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }
}
