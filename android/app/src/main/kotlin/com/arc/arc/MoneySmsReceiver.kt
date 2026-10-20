package com.arc.arc

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage

/**
 * MoneySmsReceiver catches incoming SMS broadcasts on Android.
 *
 * PRIVACY GUARANTEES:
 * - If Automatic Spending Tracking is disabled ([MoneyAutomationBridge.isAutomationEnabled] == false),
 *   the receiver drops the intent immediately without parsing.
 * - Raw SMS bodies are never persisted to disk, databases, or cloud.
 * - The event is handed off only to the local in-memory bridge.
 */
class MoneySmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null || context == null) return

        // 1. Check if automation is active
        if (!MoneyAutomationBridge.isAutomationEnabled(context)) {
            return
        }

        // 2. Verify broadcast action
        val action = intent.action
        if (action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        try {
            val messages: Array<SmsMessage> = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
            if (messages.isEmpty()) return

            val firstMessage = messages[0]
            val sender = firstMessage.originatingAddress ?: "UNKNOWN"
            val timestamp = firstMessage.timestampMillis

            // Combine multi-part SMS messages into single string
            val bodyBuilder = StringBuilder()
            for (msg in messages) {
                val part = msg.displayMessageBody ?: msg.messageBody
                if (part != null) {
                    bodyBuilder.append(part)
                }
            }

            val fullBody = bodyBuilder.toString()
            if (fullBody.isNotEmpty()) {
                MoneyAutomationBridge.onSmsReceived(
                    context = context,
                    sender = sender,
                    body = fullBody,
                    timestamp = timestamp
                )
            }
        } catch (e: Exception) {
            // Suppress errors to avoid crashing broadcast queue
        }
    }
}
