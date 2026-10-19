package com.arc.arc.core.model

import java.util.Date
import java.util.UUID

/**
 * Native Kotlin representation of ARC's Transaction model.
 * Preserves 100% schema compatibility with Flutter Hive Type 3 and Firestore `users/{uid}/transactions`.
 *
 * Financial Accuracy:
 * Internally provides [amountPaise] (integer minor units in paise, 1 INR = 100 paise)
 * to strictly prevent floating-point rounding errors during financial calculations.
 */
data class TransactionModel(
    val id: String = UUID.randomUUID().toString(),
    val ownerUid: String = "",
    val amount: Double = 0.0,
    val type: String = "Expense",
    val category: String = "Other",
    val date: Date = Date(),
    val time: String = "",
    val notes: String = "",
    val createdAt: Date = Date(),
    val source: String = "manual",
    val automationFingerprint: String? = null,
    val amountPaise: Long = Math.round(amount * 100.0),
) {
    val isIncome: Boolean
        get() = type.equals("Income", ignoreCase = true)

    val isExpense: Boolean
        get() = !isIncome

    fun toMap(): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        map["id"] = id
        map["amount"] = amount
        map["type"] = type
        map["category"] = category
        map["date"] = DateTimeUtils.formatIso(date)
        map["time"] = time
        map["notes"] = notes
        map["createdAt"] = DateTimeUtils.formatIso(createdAt)
        map["source"] = source
        map["automationFingerprint"] = automationFingerprint
        return map
    }

    companion object {
        fun fromPaise(
            id: String = UUID.randomUUID().toString(),
            ownerUid: String = "",
            amountPaise: Long,
            type: String = "Expense",
            category: String = "Other",
            date: Date = Date(),
            time: String = "",
            notes: String = "",
            createdAt: Date = Date(),
            source: String = "manual",
            automationFingerprint: String? = null,
        ): TransactionModel {
            return TransactionModel(
                id = id,
                ownerUid = ownerUid,
                amount = amountPaise.toDouble() / 100.0,
                type = type,
                category = category,
                date = date,
                time = time,
                notes = notes,
                createdAt = createdAt,
                source = source,
                automationFingerprint = automationFingerprint,
                amountPaise = amountPaise,
            )
        }

        fun fromMap(map: Map<String, Any?>, ownerUid: String = ""): TransactionModel {
            val now = Date()
            val amountVal = when (val a = map["amount"]) {
                is Number -> a.toDouble()
                else -> 0.0
            }
            val amountPaiseVal = when (val p = map["amountPaise"]) {
                is Number -> p.toLong()
                else -> Math.round(amountVal * 100.0)
            }
            val dateParsed = (map["date"] as? String)?.let { DateTimeUtils.parseIso(it) } ?: now
            val createdAtDate = (map["createdAt"] as? String)?.let { DateTimeUtils.parseIso(it) } ?: now

            return TransactionModel(
                id = (map["id"] as? String)?.takeIf { it.isNotBlank() } ?: UUID.randomUUID().toString(),
                ownerUid = ownerUid,
                amount = amountVal,
                type = (map["type"] as? String) ?: "Expense",
                category = (map["category"] as? String) ?: "Other",
                date = dateParsed,
                time = (map["time"] as? String) ?: "",
                notes = (map["notes"] as? String) ?: "",
                createdAt = createdAtDate,
                source = (map["source"] as? String) ?: "manual",
                automationFingerprint = map["automationFingerprint"] as? String,
                amountPaise = amountPaiseVal,
            )
        }
    }
}
