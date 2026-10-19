package com.arc.arc.contracts

import com.arc.arc.core.database.TaskEntity
import com.arc.arc.core.database.TaskMappers.toEntity
import com.arc.arc.core.database.TaskMappers.toModel
import com.arc.arc.core.model.TaskModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

/**
 * Verifies Room TaskEntity <-> TaskModel mapping, labels serialization,
 * timestamp conversions, and null safety.
 */
class TaskMappersTest {

    @Test
    fun testEntityToModelAndBackRoundTrip() {
        val now = Date(1773000000000L)
        val dueDate = Date(1773100000000L)

        val originalModel = TaskModel(
            id = "task-ent-01",
            ownerUid = "owner-uid-abc",
            title = "Test Entity Mapping",
            description = "Ensure clean bi-directional mapping",
            priority = "Must",
            category = "Work",
            labels = listOf("tag1", "tag2", "tag3"),
            dueDate = dueDate,
            dueTime = "15:45",
            reminder = null,
            completed = true,
            createdAt = now,
            updatedAt = now,
            completedAt = now,
        )

        val entity = originalModel.toEntity()

        assertEquals("task-ent-01", entity.id)
        assertEquals("owner-uid-abc", entity.ownerUid)
        assertEquals("Test Entity Mapping", entity.title)
        assertEquals("Ensure clean bi-directional mapping", entity.description)
        assertEquals("Must", entity.priority)
        assertEquals("Work", entity.category)
        assertTrue("labelsJson should contain tag1", entity.labelsJson.contains("tag1"))
        assertEquals(dueDate.time, entity.dueDate)
        assertEquals("15:45", entity.dueTime)
        assertNull(entity.reminder)
        assertTrue(entity.completed)
        assertEquals(now.time, entity.createdAt)
        assertEquals(now.time, entity.updatedAt)
        assertEquals(now.time, entity.completedAt)

        val convertedModel = entity.toModel()
        assertEquals(originalModel.id, convertedModel.id)
        assertEquals(originalModel.ownerUid, convertedModel.ownerUid)
        assertEquals(originalModel.title, convertedModel.title)
        assertEquals(originalModel.description, convertedModel.description)
        assertEquals(originalModel.priority, convertedModel.priority)
        assertEquals(originalModel.category, convertedModel.category)
        assertEquals(originalModel.labels, convertedModel.labels)
        assertEquals(originalModel.dueDate, convertedModel.dueDate)
        assertEquals(originalModel.dueTime, convertedModel.dueTime)
        assertEquals(originalModel.completed, convertedModel.completed)
        assertEquals(originalModel.createdAt, convertedModel.createdAt)
        assertEquals(originalModel.updatedAt, convertedModel.updatedAt)
        assertEquals(originalModel.completedAt, convertedModel.completedAt)
    }

    @Test
    fun testCorruptLabelsJsonFallback() {
        val entity = TaskEntity(
            "id-1",
            "owner-1",
            "Title",
            "Desc",
            "Low",
            "Other",
            "INVALID_CORRUPT_JSON{{{",
            null,
            null,
            null,
            false,
            1000L,
            1000L,
            null
        )

        val model = entity.toModel()
        assertNotNull(model.labels)
        assertTrue("Corrupted labels must fallback to empty list gracefully", model.labels.isEmpty())
    }
}
