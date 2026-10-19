package com.arc.arc.core.database

import com.arc.arc.core.model.TaskModel
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.util.Date

/**
 * Bi-directional mappers between Room persistence entity and Domain/UI TaskModel.
 */
object TaskMappers {
    private val gson = Gson()
    private val listStringType = object : TypeToken<List<String>>() {}.type

    fun TaskEntity.toModel(): TaskModel {
        val labelList: List<String> = try {
            if (labelsJson.isNotBlank()) {
                gson.fromJson<List<String>>(labelsJson, listStringType) ?: emptyList()
            } else {
                emptyList()
            }
        } catch (_: Exception) {
            emptyList()
        }

        return TaskModel(
            id = id,
            ownerUid = ownerUid,
            title = title,
            description = description,
            priority = priority,
            category = category,
            labels = labelList,
            dueDate = dueDate?.let { Date(it) },
            dueTime = dueTime,
            reminder = reminder?.let { Date(it) },
            completed = completed,
            createdAt = Date(createdAt),
            updatedAt = Date(updatedAt),
            completedAt = completedAt?.let { Date(it) },
        )
    }

    fun TaskModel.toEntity(): TaskEntity {
        val jsonLabels = gson.toJson(labels)
        return TaskEntity(
            id,
            ownerUid,
            title,
            description,
            displayPriority,
            category,
            jsonLabels,
            dueDate?.time,
            dueTime,
            reminder?.time,
            completed,
            createdAt.time,
            updatedAt.time,
            completedAt?.time
        )
    }
}
