package com.arc.arc.core.model

import java.util.Date
import java.util.UUID

/**
 * Native Kotlin representation of ARC's Habit model.
 * Preserves 100% schema compatibility with Flutter Hive Type 1 and Firestore `users/{uid}/habits`.
 */
data class HabitModel(
    val id: String = UUID.randomUUID().toString(),
    val ownerUid: String = "",
    val name: String = "",
    val category: String = "Other",
    val colorValue: Long = 0xFFFFFFFFL,
    val reminderTime: String? = null,
    val createdAt: Date = Date(),
    val updatedAt: Date = Date(),
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "name" to name,
            "category" to category,
            "colorValue" to colorValue,
            "reminderTime" to reminderTime,
            "createdAt" to DateTimeUtils.formatIso(createdAt),
            "updatedAt" to DateTimeUtils.formatIso(updatedAt),
        )
    }

    companion object {
        fun fromMap(map: Map<String, Any?>, ownerUid: String = ""): HabitModel {
            val now = Date()
            val createdAtDate = (map["createdAt"] as? String)?.let { DateTimeUtils.parseIso(it) } ?: now
            val updatedAtDate = (map["updatedAt"] as? String)?.let { DateTimeUtils.parseIso(it) } ?: now
            val colorNum = when (val c = map["colorValue"]) {
                is Number -> c.toLong()
                else -> 0xFFFFFFFFL
            }

            return HabitModel(
                id = (map["id"] as? String)?.takeIf { it.isNotBlank() } ?: UUID.randomUUID().toString(),
                ownerUid = ownerUid,
                name = (map["name"] as? String) ?: "",
                category = (map["category"] as? String) ?: "Other",
                colorValue = colorNum,
                reminderTime = map["reminderTime"] as? String,
                createdAt = createdAtDate,
                updatedAt = updatedAtDate,
            )
        }
    }
}
