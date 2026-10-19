package com.arc.arc.habits

import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import com.arc.arc.features.habits.engine.HabitGoalType
import com.arc.arc.features.habits.engine.HabitStreakEngine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.util.Date

class HabitStreakEngineTest {

    private val fixedToday = LocalDate.of(2026, 10, 18)
    private val fixedCreatedAt = Date.from(
        LocalDate.of(2026, 10, 1).atStartOfDay(ZoneId.systemDefault()).toInstant()
    )

    @Test
    fun testEmptyEntriesYieldsZeroStreaks() {
        val metrics = HabitStreakEngine.computeHabitMetrics(
            habitId = "h1",
            entries = emptyList(),
            createdAt = fixedCreatedAt,
            targetDate = fixedToday,
        )

        assertEquals(0, metrics.currentStreak)
        assertEquals(0, metrics.longestStreak)
        assertEquals(0.0f, metrics.completionRate, 0.001f)
        assertEquals(0, metrics.totalCompletions)
        assertFalse(metrics.isCompletedToday)
    }

    @Test
    fun testCompletedTodayOnly() {
        val entries = listOf(
            HabitEntryModel(id = "h1_2026-10-18", habitId = "h1", dateStr = "2026-10-18", completed = true)
        )

        val metrics = HabitStreakEngine.computeHabitMetrics("h1", entries, fixedCreatedAt, fixedToday)
        assertEquals(1, metrics.currentStreak)
        assertEquals(1, metrics.longestStreak)
        assertTrue(metrics.isCompletedToday)
    }

    @Test
    fun testCompletedYesterdayActiveStreak() {
        // If yesterday is completed but today is not yet checked in, streak is still active at 1
        val entries = listOf(
            HabitEntryModel(id = "h1_2026-10-17", habitId = "h1", dateStr = "2026-10-17", completed = true)
        )

        val metrics = HabitStreakEngine.computeHabitMetrics("h1", entries, fixedCreatedAt, fixedToday)
        assertEquals(1, metrics.currentStreak)
        assertEquals(1, metrics.longestStreak)
        assertFalse(metrics.isCompletedToday)
    }

    @Test
    fun testNeitherTodayNorYesterdayResetsCurrentStreak() {
        // Completed 2 days ago (Oct 16), but neither Oct 17 nor Oct 18 completed -> current streak is 0
        val entries = listOf(
            HabitEntryModel(id = "h1_2026-10-14", habitId = "h1", dateStr = "2026-10-14", completed = true),
            HabitEntryModel(id = "h1_2026-10-15", habitId = "h1", dateStr = "2026-10-15", completed = true),
            HabitEntryModel(id = "h1_2026-10-16", habitId = "h1", dateStr = "2026-10-16", completed = true),
        )

        val metrics = HabitStreakEngine.computeHabitMetrics("h1", entries, fixedCreatedAt, fixedToday)
        assertEquals(0, metrics.currentStreak)
        assertEquals(3, metrics.longestStreak) // Historical longest preserved
        assertFalse(metrics.isCompletedToday)
    }

    @Test
    fun testConsecutiveMultiDayStreak() {
        // Oct 14, 15, 16, 17, 18 completed -> 5 days
        val dates = listOf("2026-10-14", "2026-10-15", "2026-10-16", "2026-10-17", "2026-10-18")
        val entries = dates.map {
            HabitEntryModel(id = "h1_$it", habitId = "h1", dateStr = it, completed = true)
        }

        val metrics = HabitStreakEngine.computeHabitMetrics("h1", entries, fixedCreatedAt, fixedToday)
        assertEquals(5, metrics.currentStreak)
        assertEquals(5, metrics.longestStreak)
        assertTrue(metrics.isCompletedToday)
    }

    @Test
    fun testLongestStreakAcrossMultipleGappedRuns() {
        // Run 1: Oct 1, 2, 3 (3 days)
        // Gap: Oct 4
        // Run 2: Oct 5, 6, 7, 8, 9, 10 (6 days)
        // Gap: Oct 11, 12, 13, 14, 15, 16
        // Run 3: Oct 17, 18 (2 days - current streak)
        val dates = listOf(
            "2026-10-01", "2026-10-02", "2026-10-03",
            "2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09", "2026-10-10",
            "2026-10-17", "2026-10-18",
        )
        val entries = dates.map {
            HabitEntryModel(id = "h1_$it", habitId = "h1", dateStr = it, completed = true)
        }

        val metrics = HabitStreakEngine.computeHabitMetrics("h1", entries, fixedCreatedAt, fixedToday)
        assertEquals(2, metrics.currentStreak)
        assertEquals(6, metrics.longestStreak) // Run 2 had 6 days
        assertEquals(11, metrics.totalCompletions)
    }

    @Test
    fun testDuplicateAndUncompletedEntriesHandledSafely() {
        val entries = listOf(
            HabitEntryModel(id = "h1_2026-10-18_1", habitId = "h1", dateStr = "2026-10-18", completed = true),
            HabitEntryModel(id = "h1_2026-10-18_2", habitId = "h1", dateStr = "2026-10-18", completed = true), // Duplicate
            HabitEntryModel(id = "h1_2026-10-17", habitId = "h1", dateStr = "2026-10-17", completed = false), // Uncompleted entry
        )

        val metrics = HabitStreakEngine.computeHabitMetrics("h1", entries, fixedCreatedAt, fixedToday)
        assertEquals(1, metrics.currentStreak)
        assertEquals(1, metrics.longestStreak)
        assertEquals(1, metrics.totalCompletions)
    }

    @Test
    fun testFutureDatedEntriesIgnored() {
        val entries = listOf(
            HabitEntryModel(id = "h1_2026-10-18", habitId = "h1", dateStr = "2026-10-18", completed = true),
            HabitEntryModel(id = "h1_2026-10-25", habitId = "h1", dateStr = "2026-10-25", completed = true), // Future
        )

        val metrics = HabitStreakEngine.computeHabitMetrics("h1", entries, fixedCreatedAt, fixedToday)
        assertEquals(1, metrics.currentStreak)
        assertEquals(1, metrics.longestStreak)
        assertEquals(1, metrics.totalCompletions)
    }

    @Test
    fun testYearBoundaryStreakTransition() {
        val targetNewYear = LocalDate.of(2027, 1, 2)
        val created = Date.from(LocalDate.of(2026, 12, 1).atStartOfDay(ZoneId.systemDefault()).toInstant())
        val dates = listOf("2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02")
        val entries = dates.map {
            HabitEntryModel(id = "h1_$it", habitId = "h1", dateStr = it, completed = true)
        }

        val metrics = HabitStreakEngine.computeHabitMetrics("h1", entries, created, targetNewYear)
        assertEquals(4, metrics.currentStreak)
        assertEquals(4, metrics.longestStreak)
    }

    @Test
    fun testMonthBoundaryLeapYearTransition() {
        // 2028 is a leap year (Feb 29 exists)
        val targetDate = LocalDate.of(2028, 3, 2)
        val created = Date.from(LocalDate.of(2028, 2, 1).atStartOfDay(ZoneId.systemDefault()).toInstant())
        val dates = listOf("2028-02-28", "2028-02-29", "2028-03-01", "2028-03-02")
        val entries = dates.map {
            HabitEntryModel(id = "h1_$it", habitId = "h1", dateStr = it, completed = true)
        }

        val metrics = HabitStreakEngine.computeHabitMetrics("h1", entries, created, targetDate)
        assertEquals(4, metrics.currentStreak)
        assertEquals(4, metrics.longestStreak)
    }

    @Test
    fun testHabitsSummaryDailyWeeklyMonthly() {
        val habits = listOf(
            HabitModel(id = "h1", name = "Habit 1"),
            HabitModel(id = "h2", name = "Habit 2"),
        )

        val entries = listOf(
            HabitEntryModel(id = "h1_2026-10-18", habitId = "h1", dateStr = "2026-10-18", completed = true),
            HabitEntryModel(id = "h2_2026-10-17", habitId = "h2", dateStr = "2026-10-17", completed = true),
        )

        // Daily
        val daily = HabitStreakEngine.computeHabitsSummary(habits, entries, HabitGoalType.DAILY, fixedToday)
        assertEquals(1, daily.completedCount)
        assertEquals(2, daily.totalHabits)
        assertEquals(1, daily.remainingCount)
        assertEquals(0.5f, daily.completionPercentage, 0.001f)

        // Weekly (both entries fall in the last 7 days)
        val weekly = HabitStreakEngine.computeHabitsSummary(habits, entries, HabitGoalType.WEEKLY, fixedToday)
        assertEquals(2, weekly.completedCount)
        assertEquals(14, weekly.totalHabits * 7)
        assertEquals(12, weekly.remainingCount)
        assertEquals(2f / 14f, weekly.completionPercentage, 0.001f)

        // Monthly (October has 31 days)
        val monthly = HabitStreakEngine.computeHabitsSummary(habits, entries, HabitGoalType.MONTHLY, fixedToday)
        assertEquals(2, monthly.completedCount)
        assertEquals(60, monthly.remainingCount) // 2 habits * 31 days - 2 completed = 60 remaining
        assertEquals(2f / 62f, monthly.completionPercentage, 0.001f)
    }
}
