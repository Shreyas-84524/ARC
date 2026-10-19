package com.arc.arc.core.model

import java.util.Date

/**
 * Native Kotlin representation of ARC's monthly financial summary.
 * Matches Flutter `MonthlySummary` and Firestore `users/{uid}/monthlySummaries/{yyyy-MM}`.
 */
data class MonthlySummaryModel(
    val month: String, // "yyyy-MM"
    val ownerUid: String = "",
    val monthlyBudget: Double = 0.0,
    val totalIncome: Double = 0.0,
    val totalExpenses: Double = 0.0,
    val savings: Double = totalIncome - totalExpenses,
    val updatedAt: Date = Date(),
    val monthlyBudgetPaise: Long = Math.round(monthlyBudget * 100.0),
    val totalIncomePaise: Long = Math.round(totalIncome * 100.0),
    val totalExpensesPaise: Long = Math.round(totalExpenses * 100.0),
    val savingsPaise: Long = totalIncomePaise - totalExpensesPaise,
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "month" to month,
            "monthlyBudget" to monthlyBudget,
            "totalIncome" to totalIncome,
            "totalExpenses" to totalExpenses,
            "savings" to savings,
            "updatedAt" to DateTimeUtils.formatIso(updatedAt),
        )
    }

    companion object {
        fun fromPaise(
            month: String,
            ownerUid: String = "",
            monthlyBudgetPaise: Long,
            totalIncomePaise: Long,
            totalExpensesPaise: Long,
            updatedAt: Date = Date(),
        ): MonthlySummaryModel {
            val savingsPaise = totalIncomePaise - totalExpensesPaise
            return MonthlySummaryModel(
                month = month,
                ownerUid = ownerUid,
                monthlyBudget = monthlyBudgetPaise.toDouble() / 100.0,
                totalIncome = totalIncomePaise.toDouble() / 100.0,
                totalExpenses = totalExpensesPaise.toDouble() / 100.0,
                savings = savingsPaise.toDouble() / 100.0,
                updatedAt = updatedAt,
                monthlyBudgetPaise = monthlyBudgetPaise,
                totalIncomePaise = totalIncomePaise,
                totalExpensesPaise = totalExpensesPaise,
                savingsPaise = savingsPaise,
            )
        }

        fun fromMap(map: Map<String, Any?>, ownerUid: String = ""): MonthlySummaryModel {
            val m = (map["month"] as? String) ?: ""
            val b = (map["monthlyBudget"] as? Number)?.toDouble() ?: 0.0
            val i = (map["totalIncome"] as? Number)?.toDouble() ?: 0.0
            val e = (map["totalExpenses"] as? Number)?.toDouble() ?: 0.0
            val s = (map["savings"] as? Number)?.toDouble() ?: (i - e)
            val u = (map["updatedAt"] as? String)?.let { DateTimeUtils.parseIso(it) } ?: Date()

            val bPaise = (map["monthlyBudgetPaise"] as? Number)?.toLong() ?: Math.round(b * 100.0)
            val iPaise = (map["totalIncomePaise"] as? Number)?.toLong() ?: Math.round(i * 100.0)
            val ePaise = (map["totalExpensesPaise"] as? Number)?.toLong() ?: Math.round(e * 100.0)
            val sPaise = (map["savingsPaise"] as? Number)?.toLong() ?: (iPaise - ePaise)

            return MonthlySummaryModel(
                month = m,
                ownerUid = ownerUid,
                monthlyBudget = b,
                totalIncome = i,
                totalExpenses = e,
                savings = s,
                updatedAt = u,
                monthlyBudgetPaise = bPaise,
                totalIncomePaise = iPaise,
                totalExpensesPaise = ePaise,
                savingsPaise = sPaise,
            )
        }
    }
}
