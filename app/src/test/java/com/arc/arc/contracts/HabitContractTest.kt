package com.arc.arc.contracts

import com.arc.arc.core.model.DateTimeUtils
import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

/**
 * Data contract tests verifying Habit and HabitEntry models compatibility
 * with Flutter Hive Type 1 & 2 and Firestore `users/{uid}/habits` and `habitEntries`.
 */
class HabitContractTest {

    @Test
    fun testHabitSerializationRoundTrip() {
        val now = Date(1773000000000L)
        val habit = HabitModel(
            id = "habit-uuid-101",
            ownerUid = "uid-user-1",
            name = "Morning Exercise",
            category = "Fitness",
            colorValue = 0xFFD7FF2FL,
            reminderTime = "07:00",
            createdAt = now,
            updatedAt = now,
        )

        val map = habit.toMap()
        assertEquals("habit-uuid-101", map["id"])
        assertEquals("Morning Exercise", map["name"])
        assertEquals("Fitness", map["category"])
        assertEquals(0xFFD7FF2FL, map["colorValue"])
        assertEquals("07:00", map["reminderTime"])
        assertEquals(DateTimeUtils.formatIso(now), map["createdAt"])
        assertEquals(DateTimeUtils.formatIso(now), map["updatedAt"])

        val restored = HabitModel.fromMap(map, ownerUid = "uid-user-1")
        assertEquals(habit.id, restored.id)
        assertEquals(habit.ownerUid, restored.ownerUid)
        assertEquals(habit.name, restored.name)
        assertEquals(habit.category, restored.category)
        assertEquals(habit.colorValue, restored.colorValue)
        assertEquals(habit.reminderTime, restored.reminderTime)
    }

    @Test
    fun testHabitEntryCompositeKeyAndSerialization() {
        val habitId = "habit-123"
        val dateStr = "2026-07-20"
        val expectedKey = "habit-123_2026-07-20"

        val entry = HabitEntryModel(
            id = expectedKey,
            ownerUid = "uid-user-1",
            habitId = habitId,
            dateStr = dateStr,
            completed = true,
        )

        assertEquals(expectedKey, entry.id)

        val map = entry.toMap()
        assertEquals(expectedKey, map["id"])
        assertEquals(habitId, map["habitId"])
        assertEquals(dateStr, map["dateStr"])
        assertEquals(true, map["completed"])

        val restored = HabitEntryModel.fromMap(map, ownerUid = "uid-user-1")
        assertEquals(entry.id, restored.id)
        assertEquals(entry.ownerUid, restored.ownerUid)
        assertEquals(entry.habitId, restored.habitId)
        assertEquals(entry.dateStr, restored.dateStr)
        assertTrue(restored.completed)
    }

    @Test
    fun testHabitMissingFieldsHandling() {
        val sparseMap = mapOf<String, Any?>(
            "id" to "h-sparse",
            "name" to "Read Books",
        )

        val habit = HabitModel.fromMap(sparseMap, ownerUid = "uid-test")
        assertEquals("h-sparse", habit.id)
        assertEquals("Read Books", habit.name)
        assertEquals("Other", habit.category)
        assertEquals(0xFFFFFFFFL, habit.colorValue)
        assertNull(habit.reminderTime)
        assertNotNull(habit.createdAt)
        assertNotNull(habit.updatedAt)
    }

    @Test
    fun testHabitEntryDuplicateIdDeterminism() {
        val habitId = "habit-uuid-999"
        val dateStr = "2026-10-18"
        val id1 = HabitEntryModel.createId(habitId, dateStr)
        val id2 = HabitEntryModel.createId(habitId, dateStr)
        assertEquals("habit-uuid-999_2026-10-18", id1)
        assertEquals(id1, id2)
    }

    @Test
    fun testColorValueSignedVsUnsignedConversion() {
        // In Flutter Hive, 0xffccff00 (ARGB lime accent) can be serialized as signed 32-bit integer -3342592
        val signedColorInt = -3342592 // 0xFFCCFF00 as signed 32-bit int
        val mapWithSigned = mapOf<String, Any?>(
            "id" to "h-color",
            "name" to "Hydration",
            "colorValue" to signedColorInt,
        )

        val habit = HabitModel.fromMap(mapWithSigned, ownerUid = "uid-1")
        assertEquals(-3342592L, habit.colorValue)

        // Test with unsigned long representation
        val mapWithUnsigned = mapOf<String, Any?>(
            "id" to "h-color-unsigned",
            "name" to "Meditation",
            "colorValue" to 0xFFCCFF00L,
        )
        val habitUnsigned = HabitModel.fromMap(mapWithUnsigned, ownerUid = "uid-1")
        assertEquals(0xFFCCFF00L, habitUnsigned.colorValue)
    }

    @Test
    fun testDateStrSemanticsAcrossDateBoundaries() {
        // Month end transition
        val monthEnd = "2026-02-28"
        val monthStart = "2026-03-01"
        val entry1 = HabitEntryModel.fromMap(mapOf("habitId" to "h1", "dateStr" to monthEnd, "completed" to true))
        val entry2 = HabitEntryModel.fromMap(mapOf("habitId" to "h1", "dateStr" to monthStart, "completed" to true))
        assertEquals("h1_2026-02-28", entry1.id)
        assertEquals("h1_2026-03-01", entry2.id)

        // Year boundary transition
        val yearEnd = "2026-12-31"
        val newYear = "2027-01-01"
        val entryYearEnd = HabitEntryModel.fromMap(mapOf("habitId" to "h1", "dateStr" to yearEnd, "completed" to true))
        val entryNewYear = HabitEntryModel.fromMap(mapOf("habitId" to "h1", "dateStr" to newYear, "completed" to true))
        assertEquals("h1_2026-12-31", entryYearEnd.id)
        assertEquals("h1_2027-01-01", entryNewYear.id)
    }

    @Test
    fun testHabitEntrySparseAndNullHandling() {
        val sparseEntryMap = mapOf<String, Any?>(
            "habitId" to "h-sparse-entry",
            "dateStr" to "2026-10-18",
        )
        val entry = HabitEntryModel.fromMap(sparseEntryMap, ownerUid = "uid-1")
        assertEquals("h-sparse-entry_2026-10-18", entry.id)
        assertFalse(entry.completed)
    }
}
