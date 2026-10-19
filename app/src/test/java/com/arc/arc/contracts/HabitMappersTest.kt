package com.arc.arc.contracts

import com.arc.arc.core.database.HabitEntity
import com.arc.arc.core.database.HabitEntryEntity
import com.arc.arc.core.database.HabitMappers.toEntity
import com.arc.arc.core.database.HabitMappers.toModel
import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

class HabitMappersTest {

    @Test
    fun testHabitEntityAndModelBidirectionalMapping() {
        val now = Date(1773000000000L)
        val model = HabitModel(
            id = "habit-uuid-42",
            ownerUid = "uid-101",
            name = "Read 30 mins",
            category = "Learning",
            colorValue = 0xFF3B82F6L,
            reminderTime = "21:00",
            createdAt = now,
            updatedAt = now,
        )

        val entity = model.toEntity()
        assertEquals("habit-uuid-42", entity.id)
        assertEquals("uid-101", entity.ownerUid)
        assertEquals("Read 30 mins", entity.name)
        assertEquals("Learning", entity.category)
        assertEquals(0xFF3B82F6L, entity.colorValue)
        assertEquals("21:00", entity.reminderTime)
        assertEquals(now.time, entity.createdAt)
        assertEquals(now.time, entity.updatedAt)

        val restored = entity.toModel()
        assertEquals(model.id, restored.id)
        assertEquals(model.ownerUid, restored.ownerUid)
        assertEquals(model.name, restored.name)
        assertEquals(model.category, restored.category)
        assertEquals(model.colorValue, restored.colorValue)
        assertEquals(model.reminderTime, restored.reminderTime)
        assertEquals(model.createdAt.time, restored.createdAt.time)
        assertEquals(model.updatedAt.time, restored.updatedAt.time)
    }

    @Test
    fun testHabitEntryEntityAndModelBidirectionalMapping() {
        val entryModel = HabitEntryModel(
            id = "h1_2026-10-18",
            ownerUid = "uid-101",
            habitId = "h1",
            dateStr = "2026-10-18",
            completed = true,
        )

        val entity = entryModel.toEntity()
        assertEquals("h1_2026-10-18", entity.id)
        assertEquals("uid-101", entity.ownerUid)
        assertEquals("h1", entity.habitId)
        assertEquals("2026-10-18", entity.dateStr)
        assertTrue(entity.completed)

        val restored = entity.toModel()
        assertEquals(entryModel.id, restored.id)
        assertEquals(entryModel.ownerUid, restored.ownerUid)
        assertEquals(entryModel.habitId, restored.habitId)
        assertEquals(entryModel.dateStr, restored.dateStr)
        assertEquals(entryModel.completed, restored.completed)
    }
}
