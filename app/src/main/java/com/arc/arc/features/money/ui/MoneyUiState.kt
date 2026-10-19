package com.arc.arc.features.money.ui

import com.arc.arc.core.model.BudgetModel
import com.arc.arc.core.model.TransactionModel

/**
 * Immutable UI State for the Money Manager screen.
 */
data class MoneyUiState(
    val selectedMonth: String = "", // e.g. "2026-10"
    val selectedTab: Int = 0, // 0 = Transactions, 1 = Analytics
    val monthlyBudget: BudgetModel? = null,
    val monthlyBudgetPaise: Long = 0L,
    val totalIncomePaise: Long = 0L,
    val totalExpensesPaise: Long = 0L,
    val remainingBudgetPaise: Long = 0L,
    val savingsPaise: Long = 0L,
    val savingsRate: Double = 0.0,
    val transactions: List<TransactionModel> = emptyList(),
    val filteredTransactions: List<TransactionModel> = emptyList(),
    val filterType: String = "All", // "All", "Expense", "Income"
    val filterCategory: String = "All",
    val searchQuery: String = "",
    val categoryExpenses: Map<String, Long> = emptyMap(),
    val dailySpending: Map<Int, Long> = emptyMap(),
    val analyticsReport: com.arc.arc.features.money.analytics.FinancialAnalyticsReport? = null,
    val isLoading: Boolean = false,
    val userMessage: String? = null,
    val isAutomationPromptVisible: Boolean = false,
) {
    val hasBudget: Boolean
        get() = monthlyBudgetPaise > 0L

    val isBudgetExceeded: Boolean
        get() = hasBudget && remainingBudgetPaise < 0L

    val budgetUtilizationRate: Double
        get() = if (monthlyBudgetPaise > 0L) {
            (totalExpensesPaise.toDouble() / monthlyBudgetPaise.toDouble()).coerceIn(0.0, 2.0)
        } else {
            0.0
        }
}
