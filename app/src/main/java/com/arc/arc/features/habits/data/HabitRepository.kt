package com.arc.arc.features.habits.data

import com.arc.arc.core.database.RoomHabitDataSource
import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import com.arc.arc.features.tasks.data.SyncResult
import kotlinx.coroutines.flow.Flow
import java.util.Date

interface IHabitRepository {
    fun getHabitsFlow(ownerUid: String): Flow<List<HabitModel>>
    fun getEntriesFlow(ownerUid: String): Flow<List<HabitEntryModel>>
    fun getEntriesForDateFlow(ownerUid: String, dateStr: String): Flow<List<HabitEntryModel>>
    suspend fun getHabits(ownerUid: String): List<HabitModel>
    suspend fun getHabitById(id: String, ownerUid: String): HabitModel?
    suspend fun saveHabit(habit: HabitModel): Result<Unit>
    suspend fun deleteHabit(id: String, ownerUid: String): Result<Unit>
    suspend fun getEntries(ownerUid: String): List<HabitEntryModel>
    suspend fun getEntriesForDate(ownerUid: String, dateStr: String): List<HabitEntryModel>
    suspend fun toggleHabitCompletion(
        habitId: String,
        dateStr: String,
        completed: Boolean,
        ownerUid: String
    ): Result<HabitEntryModel>
    suspend fun undoHabitCompletion(
        habitId: String,
        dateStr: String,
        ownerUid: String
    ): Result<Unit>
    suspend fun syncPending(ownerUid: String): SyncResult
}

/**
 * Offline-first HabitRepository.
 * Local Room storage is the immediate source of truth.
 * Prepared with cloud sync contracts for future Firestore integration.
 */
class OfflineFirstHabitRepository(
    private val localDataSource: RoomHabitDataSource
) : IHabitRepository {

    override fun getHabitsFlow(ownerUid: String): Flow<List<HabitModel>> {
        return localDataSource.observeHabits(ownerUid)
    }

    override fun getEntriesFlow(ownerUid: String): Flow<List<HabitEntryModel>> {
        return localDataSource.observeEntries(ownerUid)
    }

    override fun getEntriesForDateFlow(ownerUid: String, dateStr: String): Flow<List<HabitEntryModel>> {
        return localDataSource.observeEntriesForDate(ownerUid, dateStr)
    }

    override suspend fun getHabits(ownerUid: String): List<HabitModel> {
        return localDataSource.getHabits(ownerUid)
    }

    override suspend fun getHabitById(id: String, ownerUid: String): HabitModel? {
        return localDataSource.getHabit(id, ownerUid)
    }

    override suspend fun saveHabit(habit: HabitModel): Result<Unit> {
        if (habit.name.isBlank()) {
            return Result.failure(IllegalArgumentException("Habit name cannot be empty"))
        }
        val updated = habit.copy(updatedAt = Date())
        localDataSource.saveHabit(updated)
        return Result.success(Unit)
    }

    override suspend fun deleteHabit(id: String, ownerUid: String): Result<Unit> {
        val deleted = localDataSource.deleteHabit(id, ownerUid)
        return if (deleted) {
            Result.success(Unit)
        } else {
            Result.failure(NoSuchElementException("Habit not found or not deleted: $id"))
        }
    }

    override suspend fun getEntries(ownerUid: String): List<HabitEntryModel> {
        return localDataSource.getEntries(ownerUid)
    }

    override suspend fun getEntriesForDate(ownerUid: String, dateStr: String): List<HabitEntryModel> {
        return localDataSource.getEntriesForDate(ownerUid, dateStr)
    }

    override suspend fun toggleHabitCompletion(
        habitId: String,
        dateStr: String,
        completed: Boolean,
        ownerUid: String
    ): Result<HabitEntryModel> {
        val entry = localDataSource.recordCompletion(habitId, dateStr, completed, ownerUid)
        return Result.success(entry)
    }

    override suspend fun undoHabitCompletion(
        habitId: String,
        dateStr: String,
        ownerUid: String
    ): Result<Unit> {
        localDataSource.undoCompletion(habitId, dateStr, ownerUid)
        return Result.success(Unit)
    }

    override suspend fun syncPending(ownerUid: String): SyncResult {
        return SyncResult.PendingOffline(
            pendingCount = 0,
            reason = "Local-first storage active. Cloud sync pending Firebase project configuration in later phase."
        )
    }
}
