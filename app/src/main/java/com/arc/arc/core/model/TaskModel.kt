package com.arc.arc.core.model

import java.util.Date
import java.util.UUID

/**
 * Native Kotlin representation of ARC's Task model.
 * Preserves 100% schema compatibility with Flutter Hive Type 0 and Firestore `users/{uid}/tasks`.
 */
data class TaskModel(
    val id: String = UUID.randomUUID().toString(),
    val ownerUid: String = "",
    val title: String = "",
    val description: String = "",
    val priority: String = "Low",
    val category: String = "Other",
    val labels: List<String> = emptyList(),
    val dueDate: Date? = null,
    val dueTime: String? = null,
    val reminder: Date? = null,
    val completed: Boolean = false,
    val createdAt: Date = Date(),
    val updatedAt: Date = Date(),
    val completedAt: Date? = null,
) {
    val displayPriority: String
        get() = if (priority.equals("Much", ignoreCase = true)) "Must" else priority

    val priorityEnum: TaskPriority
        get() = TaskPriority.fromString(priority)

    /**
     * Serializes to map matching Flutter `Task.toMap()` and Firestore document structure.
     */
    fun toMap(): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        map["id"] = id
        map["title"] = title
        map["description"] = description
        map["priority"] = displayPriority
        map["category"] = category
        map["labels"] = labels
        map["dueDate"] = dueDate?.let { DateTimeUtils.formatIso(it) }
        map["dueTime"] = dueTime
        map["reminder"] = reminder?.let { DateTimeUtils.formatIso(it) }
        map["completed"] = completed
        map["completedAt"] = completedAt?.let { DateTimeUtils.formatIso(it) }
        map["createdAt"] = DateTimeUtils.formatIso(createdAt)
        map["updatedAt"] = DateTimeUtils.formatIso(updatedAt)
        return map
    }

    companion object {
        /**
         * Reconstructs TaskModel from a map representation (Firestore or Hive deserialized map),
         * preserving compatibility with legacy values and missing fields.
         */
        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<String, Any?>, ownerUid: String = ""): TaskModel {
            val rawPriority = (map["priority"] as? String) ?: "Low"
            val normalizedPriority = if (rawPriority.equals("Much", ignoreCase = true)) "Must" else rawPriority

            val rawLabels = when (val l = map["labels"]) {
                is List<*> -> l.filterIsInstance<String>()
                else -> emptyList()
            }

            val now = Date()
            val createdAtDate = (map["createdAt"] as? String)?.let { DateTimeUtils.parseIso(it) } ?: now
            val updatedAtDate = (map["updatedAt"] as? String)?.let { DateTimeUtils.parseIso(it) } ?: now
            val dueDateParsed = (map["dueDate"] as? String)?.let { DateTimeUtils.parseIso(it) }
            val reminderParsed = (map["reminder"] as? String)?.let { DateTimeUtils.parseIso(it) }
            val completedAtParsed = (map["completedAt"] as? String)?.let { DateTimeUtils.parseIso(it) }

            return TaskModel(
                id = (map["id"] as? String)?.takeIf { it.isNotBlank() } ?: UUID.randomUUID().toString(),
                ownerUid = ownerUid,
                title = (map["title"] as? String) ?: "",
                description = (map["description"] as? String) ?: "",
                priority = normalizedPriority,
                category = (map["category"] as? String) ?: "Other",
                labels = rawLabels,
                dueDate = dueDateParsed,
                dueTime = map["dueTime"] as? String,
                reminder = reminderParsed,
                completed = (map["completed"] as? Boolean) ?: false,
                createdAt = createdAtDate,
                updatedAt = updatedAtDate,
                completedAt = completedAtParsed,
            )
        }
    }
}
