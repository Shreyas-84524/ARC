package com.arc.arc.features.money.analytics

import com.arc.arc.core.model.BudgetModel
import com.arc.arc.core.model.TransactionModel
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.util.Calendar
import java.util.Date
import java.util.TimeZone

enum class BudgetPaceStatus {
    ON_TRACK,
    AT_RISK,
    EXCEEDED,
    NO_BUDGET,
}

enum class SpendingTrend {
    INCREASED,
    DECREASED,
    STABLE,
}

enum class FinancialHealthRating {
    EXCELLENT,
    HEALTHY,
    MODERATE,
    CRITICAL,
}

data class CategorySpendingItem(
    val category: String,
    val amountPaise: Long,
    val percentageOfTotal: Double,
    val transactionCount: Int,
)

data class MonthOverMonthComparison(
    val previousMonth: String,
    val previousExpensePaise: Long,
    val previousIncomePaise: Long,
    val expenseChangePercentage: Double,
    val incomeChangePercentage: Double,
    val expenseTrend: SpendingTrend,
)

data class FinancialAnalyticsReport(
    val month: String,
    val totalIncomePaise: Long,
    val totalExpensesPaise: Long,
    val netSavingsPaise: Long,
    val savingsRate: Double,
    val monthlyBudgetPaise: Long,
    val remainingBudgetPaise: Long,
    val budgetUtilizationRate: Double,
    val daysInMonth: Int,
    val daysElapsed: Int,
    val dailyAverageSpendPaise: Long,
    val projectedMonthEndSpendPaise: Long,
    val budgetPaceStatus: BudgetPaceStatus,
    val categoryBreakdown: List<CategorySpendingItem>,
    val topSpendingCategory: CategorySpendingItem?,
    val dailySpending: Map<Int, Long>,
    val dayOfWeekSpending: Map<DayOfWeek, Long>,
    val peakSpendingDayOfMonth: Int?,
    val monthOverMonthComparison: MonthOverMonthComparison?,
    val healthRating: FinancialHealthRating,
    val healthSummary: String,
)

object FinancialAnalyticsEngine {

    fun generateReport(
        month: String,
        currentMonthTransactions: List<TransactionModel>,
        currentBudget: BudgetModel?,
        previousMonthTransactions: List<TransactionModel>? = null,
        referenceDate: LocalDate = LocalDate.now(ZoneId.systemDefault()),
    ): FinancialAnalyticsReport {
        val ym = try {
            YearMonth.parse(month)
        } catch (_: Exception) {
            YearMonth.now()
        }

        val daysInMonth = ym.lengthOfMonth()
        val referenceYearMonth = YearMonth.from(referenceDate)

        val daysElapsed = when {
            ym.isBefore(referenceYearMonth) -> daysInMonth
            ym.isAfter(referenceYearMonth) -> 1
            else -> referenceDate.dayOfMonth.coerceIn(1, daysInMonth)
        }

        val expenses = currentMonthTransactions.filter { it.isExpense }
        val incomes = currentMonthTransactions.filter { it.isIncome }

        val totalExpensesPaise = expenses.sumOf { it.amountPaise }
        val totalIncomePaise = incomes.sumOf { it.amountPaise }
        val netSavingsPaise = totalIncomePaise - totalExpensesPaise

        val savingsRate = if (totalIncomePaise > 0L) {
            (netSavingsPaise.toDouble() / totalIncomePaise.toDouble()).coerceIn(-1.0, 1.0)
        } else {
            0.0
        }

        val monthlyBudgetPaise = currentBudget?.amountPaise ?: 0L
        val remainingBudgetPaise = monthlyBudgetPaise - totalExpensesPaise
        val budgetUtilizationRate = if (monthlyBudgetPaise > 0L) {
            totalExpensesPaise.toDouble() / monthlyBudgetPaise.toDouble()
        } else {
            0.0
        }

        val dailyAverageSpendPaise = if (daysElapsed > 0) {
            totalExpensesPaise / daysElapsed
        } else {
            0L
        }

        val projectedMonthEndSpendPaise = dailyAverageSpendPaise * daysInMonth

        val budgetPaceStatus = when {
            monthlyBudgetPaise <= 0L -> BudgetPaceStatus.NO_BUDGET
            totalExpensesPaise > monthlyBudgetPaise -> BudgetPaceStatus.EXCEEDED
            projectedMonthEndSpendPaise > monthlyBudgetPaise -> BudgetPaceStatus.AT_RISK
            else -> BudgetPaceStatus.ON_TRACK
        }

        // Category breakdown
        val categoryBreakdown = expenses
            .groupBy { it.category }
            .map { (cat, txs) ->
                val sumPaise = txs.sumOf { it.amountPaise }
                val pct = if (totalExpensesPaise > 0L) {
                    (sumPaise.toDouble() / totalExpensesPaise.toDouble()) * 100.0
                } else {
                    0.0
                }
                CategorySpendingItem(
                    category = cat,
                    amountPaise = sumPaise,
                    percentageOfTotal = pct,
                    transactionCount = txs.size,
                )
            }
            .sortedByDescending { it.amountPaise }

        val topCategory = categoryBreakdown.firstOrNull()

        // Daily spending map & Day of week
        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        val dailyMap = mutableMapOf<Int, Long>()
        val dowMap = mutableMapOf<DayOfWeek, Long>()

        expenses.forEach { tx ->
            cal.time = tx.date
            val dayOfMonth = cal.get(Calendar.DAY_OF_MONTH)
            dailyMap[dayOfMonth] = (dailyMap[dayOfMonth] ?: 0L) + tx.amountPaise

            // Day of week mapping
            val dow = when (cal.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> DayOfWeek.MONDAY
                Calendar.TUESDAY -> DayOfWeek.TUESDAY
                Calendar.WEDNESDAY -> DayOfWeek.WEDNESDAY
                Calendar.THURSDAY -> DayOfWeek.THURSDAY
                Calendar.FRIDAY -> DayOfWeek.FRIDAY
                Calendar.SATURDAY -> DayOfWeek.SATURDAY
                else -> DayOfWeek.SUNDAY
            }
            dowMap[dow] = (dowMap[dow] ?: 0L) + tx.amountPaise
        }

        val peakDay = dailyMap.maxByOrNull { it.value }?.key

        // Month-over-month comparison
        val momComparison = if (previousMonthTransactions != null) {
            val prevMonthStr = ym.minusMonths(1).toString()
            val prevExpenses = previousMonthTransactions.filter { it.isExpense }.sumOf { it.amountPaise }
            val prevIncome = previousMonthTransactions.filter { it.isIncome }.sumOf { it.amountPaise }

            val expChangePct = if (prevExpenses > 0L) {
                ((totalExpensesPaise - prevExpenses).toDouble() / prevExpenses.toDouble()) * 100.0
            } else {
                0.0
            }

            val incChangePct = if (prevIncome > 0L) {
                ((totalIncomePaise - prevIncome).toDouble() / prevIncome.toDouble()) * 100.0
            } else {
                0.0
            }

            val expTrend = when {
                expChangePct > 2.0 -> SpendingTrend.INCREASED
                expChangePct < -2.0 -> SpendingTrend.DECREASED
                else -> SpendingTrend.STABLE
            }

            MonthOverMonthComparison(
                previousMonth = prevMonthStr,
                previousExpensePaise = prevExpenses,
                previousIncomePaise = prevIncome,
                expenseChangePercentage = expChangePct,
                incomeChangePercentage = incChangePct,
                expenseTrend = expTrend,
            )
        } else {
            null
        }

        // Financial health rating
        val (healthRating, healthSummary) = evaluateHealth(
            monthlyBudgetPaise = monthlyBudgetPaise,
            totalExpensesPaise = totalExpensesPaise,
            savingsRate = savingsRate,
            budgetUtilizationRate = budgetUtilizationRate,
            budgetPace = budgetPaceStatus,
        )

        return FinancialAnalyticsReport(
            month = month,
            totalIncomePaise = totalIncomePaise,
            totalExpensesPaise = totalExpensesPaise,
            netSavingsPaise = netSavingsPaise,
            savingsRate = savingsRate,
            monthlyBudgetPaise = monthlyBudgetPaise,
            remainingBudgetPaise = remainingBudgetPaise,
            budgetUtilizationRate = budgetUtilizationRate,
            daysInMonth = daysInMonth,
            daysElapsed = daysElapsed,
            dailyAverageSpendPaise = dailyAverageSpendPaise,
            projectedMonthEndSpendPaise = projectedMonthEndSpendPaise,
            budgetPaceStatus = budgetPaceStatus,
            categoryBreakdown = categoryBreakdown,
            topSpendingCategory = topCategory,
            dailySpending = dailyMap,
            dayOfWeekSpending = dowMap,
            peakSpendingDayOfMonth = peakDay,
            monthOverMonthComparison = momComparison,
            healthRating = healthRating,
            healthSummary = healthSummary,
        )
    }

    private fun evaluateHealth(
        monthlyBudgetPaise: Long,
        totalExpensesPaise: Long,
        savingsRate: Double,
        budgetUtilizationRate: Double,
        budgetPace: BudgetPaceStatus,
    ): Pair<FinancialHealthRating, String> {
        if (monthlyBudgetPaise > 0L && totalExpensesPaise > monthlyBudgetPaise) {
            return Pair(FinancialHealthRating.CRITICAL, "Budget limit exceeded. Immediate spending reduction recommended.")
        }

        if (budgetPace == BudgetPaceStatus.AT_RISK) {
            return Pair(FinancialHealthRating.MODERATE, "Projected spending will exceed budget at current daily burn rate.")
        }

        if (savingsRate >= 0.30 && (monthlyBudgetPaise == 0L || budgetUtilizationRate <= 0.80)) {
            return Pair(FinancialHealthRating.EXCELLENT, "Superb financial discipline with strong savings and low budget utilization.")
        }

        if (savingsRate >= 0.15 && (monthlyBudgetPaise == 0L || budgetUtilizationRate <= 0.95)) {
            return Pair(FinancialHealthRating.HEALTHY, "Solid financial health with healthy positive cash flow.")
        }

        if (savingsRate >= 0.0) {
            return Pair(FinancialHealthRating.MODERATE, "Break-even or modest savings. Monitor discretionary categories.")
        }

        return Pair(FinancialHealthRating.CRITICAL, "Expenses currently outpace income. Spending review required.")
    }
}
