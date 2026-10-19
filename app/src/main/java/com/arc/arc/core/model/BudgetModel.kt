package com.arc.arc.core.model

import java.util.Date

/**
 * Native Kotlin representation of ARC's monthly budget.
 * Matches Firestore `users/{uid}/budgets/{yyyy-MM}` and Flutter settings storage.
 */
data class BudgetModel(
    val month: String, // Format: "yyyy-MM", e.g. "2026-10"
    val ownerUid: String = "",
    val amount: Double = 0.0,
    val amountPaise: Long = Math.round(amount * 100.0),
    val updatedAt: Date = Date(),
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "month" to month,
            "amount" to amount,
            "updatedAt" to DateTimeUtils.formatIso(updatedAt),
        )
    }

    companion object {
        fun fromPaise(
            month: String,
            ownerUid: String = "",
            amountPaise: Long,
            updatedAt: Date = Date(),
        ): BudgetModel {
            return BudgetModel(
                month = month,
                ownerUid = ownerUid,
                amount = amountPaise.toDouble() / 100.0,
                amountPaise = amountPaise,
                updatedAt = updatedAt,
            )
        }

        fun fromMap(map: Map<String, Any?>, ownerUid: String = ""): BudgetModel {
            val monthStr = (map["month"] as? String) ?: ""
            val amt = when (val a = map["amount"]) {
                is Number -> a.toDouble()
                else -> 0.0
            }
            val amountPaiseVal = when (val p = map["amountPaise"]) {
                is Number -> p.toLong()
                else -> Math.round(amt * 100.0)
            }
            val updated = (map["updatedAt"] as? String)?.let { DateTimeUtils.parseIso(it) } ?: Date()

            return BudgetModel(
                month = monthStr,
                ownerUid = ownerUid,
                amount = amt,
                amountPaise = amountPaiseVal,
                updatedAt = updated,
            )
        }
    }
}
