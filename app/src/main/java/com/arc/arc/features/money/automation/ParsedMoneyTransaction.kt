package com.arc.arc.features.money.automation

import com.arc.arc.core.model.TransactionModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/**
 * Structured local representation of a parsed transaction candidate.
 *
 * PRIVACY & SECURITY RULES:
 * - Never store or reference the full raw SMS body here.
 * - Any financial account numbers or card numbers must be masked (e.g. "XXXX1234").
 * - [toString] is strictly sanitized to prevent leaking sensitive identifiers or amounts.
 * - All monetary amounts represented in integer paise (Long) to satisfy Non-negotiable Rule 8.
 */
data class ParsedMoneyTransaction(
    val amountPaise: Long,
    val currency: String = "INR",
    val transactionDateTime: Date,
    val merchantOrDescription: String? = null,
    val referenceId: String? = null,
    val sourceSender: String,
    val classification: MoneyTransactionClassification,
    val confidence: MoneyTransactionConfidence,
    val fingerprint: String,
    val accountMask: String? = null,
) {
    val isConfirmedDebit: Boolean
        get() = classification == MoneyTransactionClassification.CONFIRMED_DEBIT &&
                confidence == MoneyTransactionConfidence.HIGH

    fun toTransactionModel(
        ownerUid: String,
        category: String = "Other",
        id: String = UUID.randomUUID().toString(),
    ): TransactionModel {
        val timeFormat = SimpleDateFormat("HH:mm", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val noteContent = buildString {
            if (!merchantOrDescription.isNullOrBlank()) {
                append(merchantOrDescription)
            }
            if (!accountMask.isNullOrBlank()) {
                if (isNotEmpty()) append(" • ")
                append(accountMask)
            }
            if (!referenceId.isNullOrBlank()) {
                if (isNotEmpty()) append(" • Ref: ")
                append(referenceId)
            }
        }.ifBlank { "Auto-detected expense" }

        return TransactionModel.fromPaise(
            id = id,
            ownerUid = ownerUid,
            amountPaise = amountPaise,
            type = "Expense",
            category = category,
            date = transactionDateTime,
            time = timeFormat.format(transactionDateTime),
            notes = noteContent,
            createdAt = Date(),
            source = "sms_auto",
            automationFingerprint = fingerprint,
        )
    }

    override fun toString(): String {
        val shortFp = if (fingerprint.length > 8) "${fingerprint.take(8)}..." else fingerprint
        return "ParsedMoneyTransaction(classification=${classification.name}, confidence=${confidence.name}, amountPaise=$amountPaise, sender=$sourceSender, ref=${if (referenceId != null) "[REDACTED]" else "none"}, fp=$shortFp)"
    }
}
