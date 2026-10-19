package com.arc.arc.core.notifications

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.arc.arc.MainActivity
import com.arc.arc.R

/**
 * BroadcastReceiver responsible for posting scheduled native notifications.
 * Enforces Zero-Cloud Vault isolation: rejects any payload attempting to broadcast vault contents.
 */
class ArcReminderReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_REMINDER = "com.arc.arc.action.REMINDER"

        const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_MESSAGE = "extra_message"
        const val EXTRA_CHANNEL_ID = "extra_channel_id"
        const val EXTRA_DESTINATION = "extra_destination"
        const val EXTRA_ENTITY_ID = "extra_entity_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_REMINDER) return

        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "ARC Reminder"
        val message = intent.getStringExtra(EXTRA_MESSAGE) ?: ""
        val channelId = intent.getStringExtra(EXTRA_CHANNEL_ID) ?: ArcNotificationChannels.CHANNEL_TASKS
        val destination = intent.getStringExtra(EXTRA_DESTINATION) ?: "dashboard"
        val entityId = intent.getStringExtra(EXTRA_ENTITY_ID) ?: ""

        // Privacy Invariant: Secret Notes are strictly prohibited from notification dispatch
        if (destination.equals("vault", ignoreCase = true) || destination.equals("secret_notes", ignoreCase = true)) {
            return
        }

        // Check runtime permission on Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permissionStatus = ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.POST_NOTIFICATIONS
            )
            if (permissionStatus != PackageManager.PERMISSION_GRANTED) {
                return
            }
        }

        val notificationManager = NotificationManagerCompat.from(context)
        if (!notificationManager.areNotificationsEnabled()) {
            return
        }

        // Tap action opens MainActivity to specific destination
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("extra_nav_destination", destination)
            putExtra("extra_entity_id", entityId)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        try {
            notificationManager.notify(notificationId, notification)
        } catch (_: SecurityException) {
            // Handled safely without crashing when permissions are revoked mid-dispatch
        }
    }
}
