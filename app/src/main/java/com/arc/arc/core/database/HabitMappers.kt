package com.arc.arc.core.database

import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import java.util.Date

/**
 * Bi-directional mappers between Room persistence entities and Domain Habit models.
 */
object HabitMappers {

    fun HabitEntity.toModel(): HabitModel {
        return HabitModel(
            id = id,
            ownerUid = ownerUid,
            name = name,
            category = category,
            colorValue = colorValue,
            reminderTime = reminderTime,
            createdAt = Date(createdAt),
            updatedAt = Date(updatedAt),
        )
    }

    fun HabitModel.toEntity(): HabitEntity {
        return HabitEntity(
            id,
            ownerUid,
            name,
            category,
            colorValue,
            reminderTime,
            createdAt.time,
            updatedAt.time,
        )
    }

    fun HabitEntryEntity.toModel(): HabitEntryModel {
        return HabitEntryModel(
            id = id,
            ownerUid = ownerUid,
            habitId = habitId,
            dateStr = dateStr,
            completed = completed,
        )
    }

    fun HabitEntryModel.toEntity(): HabitEntryEntity {
        val entryId = if (id.isNotBlank()) id else HabitEntryModel.createId(habitId, dateStr)
        return HabitEntryEntity(
            entryId,
            ownerUid,
            habitId,
            dateStr,
            completed,
        )
    }
}
