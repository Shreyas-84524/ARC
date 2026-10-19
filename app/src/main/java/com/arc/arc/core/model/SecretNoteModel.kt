package com.arc.arc.core.model

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import java.util.Date
import java.util.UUID

/**
 * Native Kotlin representation of ARC's Secret Note domain model.
 * Preserves 100% schema compatibility with Flutter [SecretNote].
 *
 * Security Guarantee:
 * This model represents decrypted in-memory state only.
 * It is NEVER stored in plaintext in Room, SharedPreferences, DataStore, logs, or backups.
 */
data class SecretNoteModel(
    val id: String = "note_${System.currentTimeMillis()}_${(100000..999999).random()}",
    val ownerUid: String = "",
    val title: String = "",
    val description: String = "",
    val color: String = "default",
    val checklist: List<SecretChecklistItemModel> = emptyList(),
    val createdAt: Date = Date(),
    val updatedAt: Date = Date(),
) {
    val isValid: Boolean
        get() = title.trim().isNotEmpty() ||
                description.trim().isNotEmpty() ||
                checklist.any { it.isValid }

    fun toMap(): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        map["id"] = id
        map["ownerUid"] = ownerUid
        map["title"] = title
        map["description"] = description
        map["color"] = color
        map["checklist"] = checklist.map { it.toMap() }
        map["createdAt"] = DateTimeUtils.formatIso(createdAt)
        map["updatedAt"] = DateTimeUtils.formatIso(updatedAt)
        return map
    }

    /**
     * Serializes note to JSON string suitable for encryption into a secure envelope.
     */
    fun toJson(): String {
        return gson.toJson(this)
    }

    companion object {
        private val gson: Gson = GsonBuilder()
            .setDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
            .create()

        fun fromMap(map: Map<*, *>): SecretNoteModel {
            val id = map["id"]?.toString() ?: UUID.randomUUID().toString()
            val ownerUid = map["ownerUid"]?.toString() ?: ""
            val title = map["title"]?.toString() ?: ""
            val description = map["description"]?.toString() ?: ""
            val color = map["color"]?.toString() ?: "default"

            val checklistItems = mutableListOf<SecretChecklistItemModel>()
            val rawChecklist = map["checklist"]
            if (rawChecklist is List<*>) {
                rawChecklist.filterIsInstance<Map<*, *>>().forEach { itemMap ->
                    try {
                        checklistItems.add(SecretChecklistItemModel.fromMap(itemMap))
                    } catch (_: Exception) {}
                }
            }

            val createdAt = map["createdAt"]?.toString()?.let { DateTimeUtils.parseIso(it) } ?: Date()
            val updatedAt = map["updatedAt"]?.toString()?.let { DateTimeUtils.parseIso(it) } ?: Date()

            return SecretNoteModel(
                id = id,
                ownerUid = ownerUid,
                title = title,
                description = description,
                color = color,
                checklist = checklistItems,
                createdAt = createdAt,
                updatedAt = updatedAt,
            )
        }

        fun fromJson(jsonStr: String): SecretNoteModel {
            return gson.fromJson(jsonStr, SecretNoteModel::class.java)
        }
    }
}
