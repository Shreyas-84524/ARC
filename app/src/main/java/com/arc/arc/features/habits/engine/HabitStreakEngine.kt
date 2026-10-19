package com.arc.arc.features.habits.engine

import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Date

enum class HabitGoalType(val displayName: String) {
    DAILY("Daily"),
    WEEKLY("Weekly"),
    MONTHLY("Monthly"),
}

data class HabitMetrics(
    val habitId: String,
    val currentStreak: Int,
    val longestStreak: Int,
    val completionRate: Float, // 0.0 to 1.0
    val totalCompletions: Int,
    val isCompletedToday: Boolean,
)

data class HabitProgressSummary(
    val completedCount: Int,
    val totalHabits: Int,
    val remainingCount: Int,
    val completionPercentage: Float, // 0.0 to 1.0
    val maxCurrentStreak: Int,
    val maxLongestStreak: Int,
    val averageCompletionRate: Float, // 0.0 to 1.0
)

/**
 * Deterministic engine for Habit streaks, progress calculation, and completion metrics.
 * 100% compatible with Flutter's getHabitMetrics algorithms in lib/providers/global_providers.dart.
 */
object HabitStreakEngine {

    val DATE_FORMATTER: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    val MONTH_FORMATTER: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM")

    fun parseLocalDate(dateStr: String): LocalDate? {
        return try {
            LocalDate.parse(dateStr, DATE_FORMATTER)
        } catch (_: Exception) {
            null
        }
    }

    fun formatDate(date: LocalDate): String {
        return date.format(DATE_FORMATTER)
    }

    /**
     * Calculates deterministic metrics for a single habit.
     */
    fun computeHabitMetrics(
        habitId: String,
        entries: List<HabitEntryModel>,
        createdAt: Date,
        targetDate: LocalDate = LocalDate.now(ZoneId.systemDefault()),
    ): HabitMetrics {
        val habitEntries = entries.filter { it.habitId == habitId && it.completed }

        // Extract distinct local calendar dates, ignoring future dates
        val completedDates = habitEntries.mapNotNull { parseLocalDate(it.dateStr) }
            .filter { !it.isAfter(targetDate) }
            .distinct()
            .toSet()

        if (completedDates.isEmpty()) {
            return HabitMetrics(
                habitId = habitId,
                currentStreak = 0,
                longestStreak = 0,
                completionRate = 0.0f,
                totalCompletions = 0,
                isCompletedToday = false,
            )
        }

        val today = targetDate
        val yesterday = today.minusDays(1)
        val isCompletedToday = completedDates.contains(today)

        // Current Streak Calculation
        // Rule: If neither today nor yesterday was completed, current streak is 0.
        // If today is completed, count consecutive days backwards starting from today.
        // If today is not completed but yesterday is, count backwards starting from yesterday.
        val currentStreak: Int
        if (!completedDates.contains(today) && !completedDates.contains(yesterday)) {
            currentStreak = 0
        } else {
            val checkStart = if (completedDates.contains(today)) today else yesterday
            var streak = 0
            var check = checkStart
            while (completedDates.contains(check)) {
                streak++
                check = check.minusDays(1)
            }
            currentStreak = streak
        }

        // Longest Streak Calculation
        val sortedAsc = completedDates.sorted()
        var longestStreak = 0
        var currentRun = 0
        var prevDate: LocalDate? = null

        for (date in sortedAsc) {
            if (prevDate == null) {
                currentRun = 1
            } else {
                val diff = ChronoUnit.DAYS.between(prevDate, date)
                if (diff == 1L) {
                    currentRun++
                } else if (diff > 1L) {
                    if (currentRun > longestStreak) {
                        longestStreak = currentRun
                    }
                    currentRun = 1
                }
            }
            prevDate = date
        }
        if (currentRun > longestStreak) {
            longestStreak = currentRun
        }

        // Completion Rate Calculation
        val createdLocalDate = createdAt.toInstant().atZone(ZoneId.systemDefault()).toLocalDate()
        val totalDays = ChronoUnit.DAYS.between(createdLocalDate, today) + 1
        val effectiveTotalDays = if (totalDays <= 0) 1 else totalDays
        val rate = (completedDates.size.toFloat() / effectiveTotalDays).coerceIn(0.0f, 1.0f)

        return HabitMetrics(
            habitId = habitId,
            currentStreak = currentStreak,
            longestStreak = longestStreak,
            completionRate = rate,
            totalCompletions = completedDates.size,
            isCompletedToday = isCompletedToday,
        )
    }

    /**
     * Calculates aggregate progress summary across all habits for a selected goal type (Daily, Weekly, Monthly).
     */
    fun computeHabitsSummary(
        habits: List<HabitModel>,
        entries: List<HabitEntryModel>,
        goalType: HabitGoalType = HabitGoalType.DAILY,
        targetDate: LocalDate = LocalDate.now(ZoneId.systemDefault()),
    ): HabitProgressSummary {
        if (habits.isEmpty()) {
            return HabitProgressSummary(
                completedCount = 0,
                totalHabits = 0,
                remainingCount = 0,
                completionPercentage = 0.0f,
                maxCurrentStreak = 0,
                maxLongestStreak = 0,
                averageCompletionRate = 0.0f,
            )
        }

        val habitMetricsList = habits.map { h ->
            computeHabitMetrics(h.id, entries, h.createdAt, targetDate)
        }

        val maxCurrent = habitMetricsList.maxOfOrNull { it.currentStreak } ?: 0
        val maxLongest = habitMetricsList.maxOfOrNull { it.longestStreak } ?: 0
        val avgRate = habitMetricsList.map { it.completionRate }.average().toFloat()

        val completedCount: Int
        val totalPossible: Int

        when (goalType) {
            HabitGoalType.DAILY -> {
                val todayStr = formatDate(targetDate)
                completedCount = entries.count { it.dateStr == todayStr && it.completed }
                totalPossible = habits.size
            }
            HabitGoalType.WEEKLY -> {
                val last7DaysSet = (0..6).map { formatDate(targetDate.minusDays(it.toLong())) }.toSet()
                completedCount = entries.count { it.completed && it.dateStr in last7DaysSet }
                totalPossible = habits.size * 7
            }
            HabitGoalType.MONTHLY -> {
                val currentMonthStr = targetDate.format(MONTH_FORMATTER)
                completedCount = entries.count { it.completed && it.dateStr.startsWith(currentMonthStr) }
                totalPossible = habits.size * targetDate.lengthOfMonth()
            }
        }

        val remainingCount = (totalPossible - completedCount).coerceAtLeast(0)
        val percentage = if (totalPossible > 0) (completedCount.toFloat() / totalPossible).coerceIn(0.0f, 1.0f) else 0.0f

        return HabitProgressSummary(
            completedCount = completedCount,
            totalHabits = habits.size,
            remainingCount = remainingCount,
            completionPercentage = percentage,
            maxCurrentStreak = maxCurrent,
            maxLongestStreak = maxLongest,
            averageCompletionRate = avgRate,
        )
    }

    /**
     * Generates a date range of the last N calendar dates ending at targetDate.
     */
    fun getLastNDays(days: Int = 7, targetDate: LocalDate = LocalDate.now(ZoneId.systemDefault())): List<LocalDate> {
        return (days - 1 downTo 0).map { targetDate.minusDays(it.toLong()) }
    }
}
