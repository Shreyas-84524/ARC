package com.arc.arc.money

import com.arc.arc.core.model.BudgetModel
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.features.money.analytics.BudgetPaceStatus
import com.arc.arc.features.money.analytics.FinancialAnalyticsEngine
import com.arc.arc.features.money.analytics.FinancialHealthRating
import com.arc.arc.features.money.analytics.SpendingTrend
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate
import java.util.Calendar
import java.util.Date
import java.util.TimeZone

class FinancialAnalyticsTest {

    private fun createUtcDate(year: Int, month: Int, day: Int): Date {
        return Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(year, month - 1, day, 12, 0, 0)
        }.time
    }

    @Test
    fun generateReport_emptyTransactions_calculatesZeroTotalsAndNoBudget() {
        val report = FinancialAnalyticsEngine.generateReport(
            month = "2026-10",
            currentMonthTransactions = emptyList(),
            currentBudget = null,
            referenceDate = LocalDate.of(2026, 10, 15),
        )

        assertEquals(0L, report.totalIncomePaise)
        assertEquals(0L, report.totalExpensesPaise)
        assertEquals(0L, report.netSavingsPaise)
        assertEquals(0.0, report.savingsRate, 0.001)
        assertEquals(0L, report.monthlyBudgetPaise)
        assertEquals(BudgetPaceStatus.NO_BUDGET, report.budgetPaceStatus)
        assertTrue(report.categoryBreakdown.isEmpty())
        assertNull(report.topSpendingCategory)
        assertEquals(31, report.daysInMonth)
        assertEquals(15, report.daysElapsed)
    }

    @Test
    fun generateReport_cashflowMetrics_exactPaiseMathAndSavingsRate() {
        val transactions = listOf(
            TransactionModel.fromPaise(
                id = "inc-1",
                amountPaise = 10000000L, // ₹1,00,000.00
                type = "Income",
                date = createUtcDate(2026, 10, 1),
            ),
            TransactionModel.fromPaise(
                id = "exp-1",
                amountPaise = 1500000L, // ₹15,000.00
                type = "Expense",
                category = "Rent",
                date = createUtcDate(2026, 10, 2),
            ),
            TransactionModel.fromPaise(
                id = "exp-2",
                amountPaise = 500000L, // ₹5,000.00
                type = "Expense",
                category = "Food",
                date = createUtcDate(2026, 10, 5),
            ),
        )

        val budget = BudgetModel.fromPaise(
            month = "2026-10",
            amountPaise = 7000000L, // ₹70,000.00
        )

        val report = FinancialAnalyticsEngine.generateReport(
            month = "2026-10",
            currentMonthTransactions = transactions,
            currentBudget = budget,
            referenceDate = LocalDate.of(2026, 10, 10),
        )

        assertEquals(10000000L, report.totalIncomePaise)
        assertEquals(2000000L, report.totalExpensesPaise)
        assertEquals(8000000L, report.netSavingsPaise)
        assertEquals(0.80, report.savingsRate, 0.001) // 80% savings
        assertEquals(7000000L, report.monthlyBudgetPaise)
        assertEquals(5000000L, report.remainingBudgetPaise) // 70k - 20k = 50k
        assertEquals(2000000.0 / 7000000.0, report.budgetUtilizationRate, 0.001)
        assertEquals(FinancialHealthRating.EXCELLENT, report.healthRating)
    }

    @Test
    fun generateReport_budgetPace_marksAtRiskWhenProjectedOverBudget() {
        // Spent 60,000 in 10 days out of 30-day month -> 6,000/day -> projected 180,000 against budget 100,000
        val transactions = listOf(
            TransactionModel.fromPaise(
                id = "exp-1",
                amountPaise = 6000000L,
                type = "Expense",
                date = createUtcDate(2026, 9, 5),
            )
        )
        val budget = BudgetModel.fromPaise(
            month = "2026-09",
            amountPaise = 10000000L, // Budget ₹1,00,000.00
        )

        val report = FinancialAnalyticsEngine.generateReport(
            month = "2026-09",
            currentMonthTransactions = transactions,
            currentBudget = budget,
            referenceDate = LocalDate.of(2026, 9, 10),
        )

        assertEquals(BudgetPaceStatus.AT_RISK, report.budgetPaceStatus)
        assertEquals(600000L, report.dailyAverageSpendPaise) // ₹6,000.00 per day
        assertEquals(18000000L, report.projectedMonthEndSpendPaise) // ₹1,80,000.00
    }

    @Test
    fun generateReport_budgetPace_marksExceededWhenTotalExceedsBudget() {
        val transactions = listOf(
            TransactionModel.fromPaise(
                id = "exp-1",
                amountPaise = 15000000L, // ₹1,50,000.00
                type = "Expense",
                date = createUtcDate(2026, 10, 5),
            )
        )
        val budget = BudgetModel.fromPaise(
            month = "2026-10",
            amountPaise = 10000000L, // Budget ₹1,00,000.00
        )

        val report = FinancialAnalyticsEngine.generateReport(
            month = "2026-10",
            currentMonthTransactions = transactions,
            currentBudget = budget,
            referenceDate = LocalDate.of(2026, 10, 10),
        )

        assertEquals(BudgetPaceStatus.EXCEEDED, report.budgetPaceStatus)
        assertEquals(-5000000L, report.remainingBudgetPaise)
        assertEquals(FinancialHealthRating.CRITICAL, report.healthRating)
    }

    @Test
    fun generateReport_categoryBreakdown_sortsByHighestPaiseAndCalculatesPercentages() {
        val transactions = listOf(
            TransactionModel.fromPaise(
                id = "e1",
                amountPaise = 200000L, // 2,000
                type = "Expense",
                category = "Food",
                date = createUtcDate(2026, 10, 2),
            ),
            TransactionModel.fromPaise(
                id = "e2",
                amountPaise = 500000L, // 5,000
                type = "Expense",
                category = "Travel",
                date = createUtcDate(2026, 10, 3),
            ),
            TransactionModel.fromPaise(
                id = "e3",
                amountPaise = 300000L, // 3,000
                type = "Expense",
                category = "Food",
                date = createUtcDate(2026, 10, 4),
            ),
        )

        val report = FinancialAnalyticsEngine.generateReport(
            month = "2026-10",
            currentMonthTransactions = transactions,
            currentBudget = null,
        )

        // Total expense = 10,000. Food = 5,000 (50%), Travel = 5,000 (50%)
        assertEquals(2, report.categoryBreakdown.size)
        val top = report.topSpendingCategory
        assertNotNull(top)
        assertEquals(500000L, top?.amountPaise)
        assertEquals(50.0, top?.percentageOfTotal ?: 0.0, 0.001)
    }

    @Test
    fun generateReport_dailyAndDayOfWeekDistribution_mapsCorrectly() {
        val date1 = createUtcDate(2026, 10, 5) // 2026-10-05 was Monday
        val date2 = createUtcDate(2026, 10, 5)
        val date3 = createUtcDate(2026, 10, 12) // 2026-10-12 was Monday

        val transactions = listOf(
            TransactionModel.fromPaise(id = "1", amountPaise = 100000L, type = "Expense", date = date1),
            TransactionModel.fromPaise(id = "2", amountPaise = 200000L, type = "Expense", date = date2),
            TransactionModel.fromPaise(id = "3", amountPaise = 400000L, type = "Expense", date = date3),
        )

        val report = FinancialAnalyticsEngine.generateReport(
            month = "2026-10",
            currentMonthTransactions = transactions,
            currentBudget = null,
        )

        assertEquals(300000L, report.dailySpending[5])
        assertEquals(400000L, report.dailySpending[12])
        assertEquals(12, report.peakSpendingDayOfMonth)
        assertEquals(700000L, report.dayOfWeekSpending[DayOfWeek.MONDAY])
    }

    @Test
    fun generateReport_monthOverMonthComparison_calculatesTrendAndPercentages() {
        val currentTx = listOf(
            TransactionModel.fromPaise(id = "c1", amountPaise = 12000000L, type = "Expense", date = createUtcDate(2026, 10, 1)),
            TransactionModel.fromPaise(id = "c2", amountPaise = 20000000L, type = "Income", date = createUtcDate(2026, 10, 1)),
        )

        val prevTx = listOf(
            TransactionModel.fromPaise(id = "p1", amountPaise = 10000000L, type = "Expense", date = createUtcDate(2026, 9, 1)),
            TransactionModel.fromPaise(id = "p2", amountPaise = 15000000L, type = "Income", date = createUtcDate(2026, 9, 1)),
        )

        val report = FinancialAnalyticsEngine.generateReport(
            month = "2026-10",
            currentMonthTransactions = currentTx,
            currentBudget = null,
            previousMonthTransactions = prevTx,
        )

        val mom = report.monthOverMonthComparison
        assertNotNull(mom)
        assertEquals("2026-09", mom?.previousMonth)
        assertEquals(10000000L, mom?.previousExpensePaise)
        assertEquals(20.0, mom?.expenseChangePercentage ?: 0.0, 0.001) // 120k vs 100k = +20%
        assertEquals(33.333, mom?.incomeChangePercentage ?: 0.0, 0.01) // 200k vs 150k = +33.33%
        assertEquals(SpendingTrend.INCREASED, mom?.expenseTrend)
    }
}
