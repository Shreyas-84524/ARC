package com.arc.arc.core.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

object ArcNotificationChannels {
    const val CHANNEL_TASKS = "arc_tasks_channel"
    const val CHANNEL_HABITS = "arc_habits_channel"
    const val CHANNEL_MONEY = "arc_money_channel"

    // Legacy Flutter channel IDs for backward compatibility
    const val CHANNEL_REMINDERS_LEGACY = "arc_reminders_channel"
    const val CHANNEL_MONEY_LEGACY = "arc_money_reminder_channel"

    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return

            val tasksChannel = NotificationChannel(
                CHANNEL_TASKS,
                "Task Reminders",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Due date and upcoming deadline alerts for tasks"
                enableVibration(true)
            }

            val habitsChannel = NotificationChannel(
                CHANNEL_HABITS,
                "Habit Reminders",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Daily habit schedule and evening streak check-in alerts"
                enableVibration(true)
            }

            val moneyChannel = NotificationChannel(
                CHANNEL_MONEY,
                "Money & Budget Alerts",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Daily alerts to log transaction entries and track spending"
                enableVibration(true)
            }

            // Legacy channels
            val legacyReminders = NotificationChannel(
                CHANNEL_REMINDERS_LEGACY,
                "Project Arc Reminders",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Legacy task and habit reminder channel"
                enableVibration(true)
            }

            val legacyMoney = NotificationChannel(
                CHANNEL_MONEY_LEGACY,
                "Money Reminders",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Legacy transaction reminder channel"
                enableVibration(true)
            }

            notificationManager.createNotificationChannels(
                listOf(tasksChannel, habitsChannel, moneyChannel, legacyReminders, legacyMoney)
            )
        }
    }
}
