package com.arc.arc.core.model

import java.util.Date
import java.util.UUID

/**
 * Native Kotlin representation of an item in a Secret Note checklist.
 * Preserves 100% compatibility with Flutter [SecretChecklistItem].
 */
data class SecretChecklistItemModel(
    val id: String = "item_${System.currentTimeMillis()}_${(100000..999999).random()}",
    val text: String = "",
    val isCompleted: Boolean = false,
    val createdAt: Date = Date(),
    val order: Int = 0,
) {
    val isValid: Boolean
        get() = text.trim().isNotEmpty()

    fun toMap(): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        map["id"] = id
        map["text"] = text
        map["isCompleted"] = isCompleted
        map["createdAt"] = DateTimeUtils.formatIso(createdAt)
        map["order"] = order
        return map
    }

    companion object {
        fun fromMap(map: Map<*, *>): SecretChecklistItemModel {
            val id = map["id"]?.toString() ?: UUID.randomUUID().toString()
            val text = map["text"]?.toString() ?: ""
            val isCompleted = when (val c = map["isCompleted"]) {
                is Boolean -> c
                is Number -> c.toInt() != 0
                is String -> c.equals("true", ignoreCase = true)
                else -> false
            }
            val createdAt = map["createdAt"]?.toString()?.let { DateTimeUtils.parseIso(it) } ?: Date()
            val order = (map["order"] as? Number)?.toInt() ?: 0

            return SecretChecklistItemModel(
                id = id,
                text = text,
                isCompleted = isCompleted,
                createdAt = createdAt,
                order = order,
            )
        }
    }
}
