package com.arc.arc.features.money.automation

import java.util.Date

/**
 * Transient, in-memory representation of an eligible incoming transaction event
 * captured locally on device.
 *
 * PRIVACY & SECURITY RULES:
 * - Raw event instances must exist ONLY in memory during transient handling.
 * - NEVER persist this object or its [body] to Room, Firestore, Firebase, or analytics.
 * - [toString] is strictly sanitized so that raw text, OTPs, amounts, or personal
 *   data are never printed to debug consoles or log files.
 */
data class MoneyAutomationRawEvent(
    val sender: String,
    val body: String,
    val timestamp: Date = Date(),
    val sourceType: String = "sms",
) {
    override fun toString(): String {
        // Sanitized output: NEVER print body to prevent leaking sensitive bank texts or OTPs
        return "MoneyAutomationRawEvent(sourceType=$sourceType, sender=$sender, length=${body.length}, timestamp=$timestamp)"
    }
}
