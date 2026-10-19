package com.arc.arc.core.database

import androidx.room.InvalidationTracker
import com.arc.arc.core.database.HabitMappers.toEntity
import com.arc.arc.core.database.HabitMappers.toModel
import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext

/**
 * Local Room data source implementation for Habit and HabitEntry persistence,
 * providing reactive Flow observation and asynchronous CRUD operations.
 */
class RoomHabitDataSource(
    private val database: ArcDatabase,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    private val habitDao: HabitDao get() = database.habitDao()

    /**
     * Observes habits reactively for the given user.
     */
    fun observeHabits(ownerUid: String): Flow<List<HabitModel>> = callbackFlow {
        val observer = object : InvalidationTracker.Observer("habits") {
            override fun onInvalidated(tables: Set<String>) {
                val current = habitDao.getAllHabitsForUser(ownerUid).map { it.toModel() }
                trySend(current)
            }
        }

        database.invalidationTracker.addObserver(observer)
        // Emit initial value
        val initial = habitDao.getAllHabitsForUser(ownerUid).map { it.toModel() }
        trySend(initial)

        awaitClose {
            database.invalidationTracker.removeObserver(observer)
        }
    }.flowOn(ioDispatcher)

    /**
     * Observes all habit entries reactively for the given user.
     */
    fun observeEntries(ownerUid: String): Flow<List<HabitEntryModel>> = callbackFlow {
        val observer = object : InvalidationTracker.Observer("habit_entries") {
            override fun onInvalidated(tables: Set<String>) {
                val current = habitDao.getAllEntriesForUser(ownerUid).map { it.toModel() }
                trySend(current)
            }
        }

        database.invalidationTracker.addObserver(observer)
        // Emit initial value
        val initial = habitDao.getAllEntriesForUser(ownerUid).map { it.toModel() }
        trySend(initial)

        awaitClose {
            database.invalidationTracker.removeObserver(observer)
        }
    }.flowOn(ioDispatcher)

    /**
     * Observes habit entries for a specific date (yyyy-MM-dd) reactively.
     */
    fun observeEntriesForDate(ownerUid: String, dateStr: String): Flow<List<HabitEntryModel>> = callbackFlow {
        val observer = object : InvalidationTracker.Observer("habit_entries") {
            override fun onInvalidated(tables: Set<String>) {
                val current = habitDao.getEntriesForDate(ownerUid, dateStr).map { it.toModel() }
                trySend(current)
            }
        }

        database.invalidationTracker.addObserver(observer)
        // Emit initial value
        val initial = habitDao.getEntriesForDate(ownerUid, dateStr).map { it.toModel() }
        trySend(initial)

        awaitClose {
            database.invalidationTracker.removeObserver(observer)
        }
    }.flowOn(ioDispatcher)

    suspend fun getHabits(ownerUid: String): List<HabitModel> = withContext(ioDispatcher) {
        habitDao.getAllHabitsForUser(ownerUid).map { it.toModel() }
    }

    suspend fun getHabit(id: String, ownerUid: String): HabitModel? = withContext(ioDispatcher) {
        habitDao.getHabitById(id, ownerUid)?.toModel()
    }

    suspend fun saveHabit(habit: HabitModel) = withContext(ioDispatcher) {
        habitDao.insertHabit(habit.toEntity())
    }

    suspend fun saveHabits(habits: List<HabitModel>) = withContext(ioDispatcher) {
        database.runInTransaction {
            habitDao.insertAllHabits(habits.map { it.toEntity() })
        }
    }

    suspend fun deleteHabit(id: String, ownerUid: String): Boolean = withContext(ioDispatcher) {
        habitDao.deleteHabitById(id, ownerUid) > 0
    }

    suspend fun deleteAllForUser(ownerUid: String): Int = withContext(ioDispatcher) {
        habitDao.deleteAllHabitsForUser(ownerUid)
    }

    suspend fun getHabitCountForUser(ownerUid: String): Int = withContext(ioDispatcher) {
        habitDao.getHabitCountForUser(ownerUid)
    }

    // Entries CRUD
    suspend fun getEntries(ownerUid: String): List<HabitEntryModel> = withContext(ioDispatcher) {
        habitDao.getAllEntriesForUser(ownerUid).map { it.toModel() }
    }

    suspend fun getEntriesForDate(ownerUid: String, dateStr: String): List<HabitEntryModel> = withContext(ioDispatcher) {
        habitDao.getEntriesForDate(ownerUid, dateStr).map { it.toModel() }
    }

    suspend fun getEntriesForHabit(ownerUid: String, habitId: String): List<HabitEntryModel> = withContext(ioDispatcher) {
        habitDao.getEntriesForHabit(ownerUid, habitId).map { it.toModel() }
    }

    suspend fun recordCompletion(
        habitId: String,
        dateStr: String,
        completed: Boolean,
        ownerUid: String
    ): HabitEntryModel = withContext(ioDispatcher) {
        val entryId = HabitEntryModel.createId(habitId, dateStr)
        val model = HabitEntryModel(
            id = entryId,
            ownerUid = ownerUid,
            habitId = habitId,
            dateStr = dateStr,
            completed = completed,
        )
        if (completed) {
            habitDao.insertEntry(model.toEntity())
        } else {
            // Delete entry on uncheck to match Flutter behavior
            habitDao.deleteEntryById(entryId, ownerUid)
        }
        model
    }

    suspend fun undoCompletion(
        habitId: String,
        dateStr: String,
        ownerUid: String
    ): Boolean = withContext(ioDispatcher) {
        val entryId = HabitEntryModel.createId(habitId, dateStr)
        habitDao.deleteEntryById(entryId, ownerUid) > 0
    }
}
