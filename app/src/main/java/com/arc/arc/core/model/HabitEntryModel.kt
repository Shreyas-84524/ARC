package com.arc.arc.core.model

/**
 * Native Kotlin representation of ARC's HabitEntry model.
 * Preserves 100% schema compatibility with Flutter Hive Type 2 and Firestore `users/{uid}/habitEntries`.
 */
data class HabitEntryModel(
    val id: String = "",
    val ownerUid: String = "",
    val habitId: String = "",
    val dateStr: String = "",
    val completed: Boolean = false,
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "habitId" to habitId,
            "dateStr" to dateStr,
            "completed" to completed,
        )
    }

    companion object {
        fun createId(habitId: String, dateStr: String): String {
            return "${habitId}_${dateStr}"
        }

        fun fromMap(map: Map<String, Any?>, ownerUid: String = ""): HabitEntryModel {
            val habitId = (map["habitId"] as? String) ?: ""
            val dateStr = (map["dateStr"] as? String) ?: ""
            val id = (map["id"] as? String)?.takeIf { it.isNotBlank() } ?: createId(habitId, dateStr)

            return HabitEntryModel(
                id = id,
                ownerUid = ownerUid,
                habitId = habitId,
                dateStr = dateStr,
                completed = (map["completed"] as? Boolean) ?: false,
            )
        }
    }
}
