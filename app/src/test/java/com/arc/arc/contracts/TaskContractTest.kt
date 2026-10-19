package com.arc.arc.contracts

import com.arc.arc.core.model.DateTimeUtils
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TaskPriority
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

/**
 * Data contract tests verifying Kotlin TaskModel compatibility with ARC's Flutter Hive Type 0
 * and Firestore `users/{uid}/tasks` schema.
 */
class TaskContractTest {

    @Test
    fun testCompleteTaskSerializationRoundTrip() {
        val now = Date(1773000000000L) // Fixed timestamp for deterministic testing
        val dueDate = Date(1773100000000L)
        val reminder = Date(1773050000000L)
        val completedAt = Date(1773080000000L)

        val task = TaskModel(
            id = "test-task-uuid-001",
            ownerUid = "user-firebase-uid-123",
            title = "Complete Flutter to Kotlin Migration",
            description = "Implement Phase 1 native architecture and task vertical slice",
            priority = "High",
            category = "Work",
            labels = listOf("android", "kotlin", "migration"),
            dueDate = dueDate,
            dueTime = "14:30",
            reminder = reminder,
            completed = true,
            completedAt = completedAt,
            createdAt = now,
            updatedAt = now,
        )

        val map = task.toMap()

        // Verify map field names match Flutter Task.toMap() exactly
        assertEquals("test-task-uuid-001", map["id"])
        assertEquals("Complete Flutter to Kotlin Migration", map["title"])
        assertEquals("Implement Phase 1 native architecture and task vertical slice", map["description"])
        assertEquals("High", map["priority"])
        assertEquals("Work", map["category"])
        assertEquals(listOf("android", "kotlin", "migration"), map["labels"])
        assertEquals(DateTimeUtils.formatIso(dueDate), map["dueDate"])
        assertEquals("14:30", map["dueTime"])
        assertEquals(DateTimeUtils.formatIso(reminder), map["reminder"])
        assertEquals(true, map["completed"])
        assertEquals(DateTimeUtils.formatIso(completedAt), map["completedAt"])
        assertEquals(DateTimeUtils.formatIso(now), map["createdAt"])
        assertEquals(DateTimeUtils.formatIso(now), map["updatedAt"])

        // Deserialization round trip
        val restored = TaskModel.fromMap(map, ownerUid = "user-firebase-uid-123")
        assertEquals(task.id, restored.id)
        assertEquals(task.ownerUid, restored.ownerUid)
        assertEquals(task.title, restored.title)
        assertEquals(task.description, restored.description)
        assertEquals(task.priority, restored.priority)
        assertEquals(task.category, restored.category)
        assertEquals(task.labels, restored.labels)
        assertEquals(task.dueTime, restored.dueTime)
        assertEquals(task.completed, restored.completed)
        assertNotNull(restored.dueDate)
        assertNotNull(restored.reminder)
        assertNotNull(restored.completedAt)
        assertEquals(task.priorityEnum, TaskPriority.HIGH)
    }

    @Test
    fun testLegacyMuchPriorityNormalizesToMust() {
        val legacyFlutterMap = mapOf<String, Any?>(
            "id" to "legacy-task-1",
            "title" to "Legacy task with Much priority",
            "priority" to "Much",
            "category" to "Personal",
            "completed" to false,
        )

        val task = TaskModel.fromMap(legacyFlutterMap, ownerUid = "uid-1")
        assertEquals("Must", task.priority)
        assertEquals("Must", task.displayPriority)
        assertEquals(TaskPriority.MUST, task.priorityEnum)
        assertEquals(2, task.priorityEnum.level)

        // Reserializing must output "Must" for future compatibility
        val serialized = task.toMap()
        assertEquals("Must", serialized["priority"])
    }

    @Test
    fun testMinimalMissingFieldsHandling() {
        // Simulates a sparse or legacy Firestore document where optional fields were omitted
        val sparseMap = mapOf<String, Any?>(
            "id" to "sparse-task-id",
            "title" to "Sparse Task",
        )

        val task = TaskModel.fromMap(sparseMap, ownerUid = "uid-456")
        assertEquals("sparse-task-id", task.id)
        assertEquals("uid-456", task.ownerUid)
        assertEquals("Sparse Task", task.title)
        assertEquals("", task.description)
        assertEquals("Low", task.priority)
        assertEquals("Other", task.category)
        assertTrue(task.labels.isEmpty())
        assertNull(task.dueDate)
        assertNull(task.dueTime)
        assertNull(task.reminder)
        assertFalse(task.completed)
        assertNull(task.completedAt)
        assertNotNull(task.createdAt)
        assertNotNull(task.updatedAt)
    }

    @Test
    fun testUserOwnershipScoping() {
        val map = mapOf<String, Any?>(
            "id" to "shared-id-task",
            "title" to "User Scoped Task",
        )

        val user1Task = TaskModel.fromMap(map, ownerUid = "user_alpha")
        val user2Task = TaskModel.fromMap(map, ownerUid = "user_beta")

        assertEquals("user_alpha", user1Task.ownerUid)
        assertEquals("user_beta", user2Task.ownerUid)
        assertFalse("Cross-user tasks must have distinct ownership", user1Task == user2Task)
    }
}
