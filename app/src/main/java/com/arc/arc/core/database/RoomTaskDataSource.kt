package com.arc.arc.core.database

import androidx.room.InvalidationTracker
import com.arc.arc.core.database.TaskMappers.toEntity
import com.arc.arc.core.database.TaskMappers.toModel
import com.arc.arc.core.model.TaskModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext

/**
 * Local Room data source implementation for Task persistence,
 * providing reactive Flow observation and asynchronous CRUD operations.
 */
class RoomTaskDataSource(
    private val database: ArcDatabase,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    private val taskDao: TaskDao get() = database.taskDao()

    /**
     * Observes task changes reactively for the given user using Room's InvalidationTracker.
     */
    fun observeTasks(ownerUid: String): Flow<List<TaskModel>> = callbackFlow {
        val observer = object : InvalidationTracker.Observer("tasks") {
            override fun onInvalidated(tables: Set<String>) {
                val current = taskDao.getAllForUser(ownerUid).map { it.toModel() }
                trySend(current)
            }
        }

        database.invalidationTracker.addObserver(observer)
        // Emit initial value
        val initial = taskDao.getAllForUser(ownerUid).map { it.toModel() }
        trySend(initial)

        awaitClose {
            database.invalidationTracker.removeObserver(observer)
        }
    }.flowOn(ioDispatcher)

    suspend fun getTasks(ownerUid: String): List<TaskModel> = withContext(ioDispatcher) {
        taskDao.getAllForUser(ownerUid).map { it.toModel() }
    }

    suspend fun getTask(id: String, ownerUid: String): TaskModel? = withContext(ioDispatcher) {
        taskDao.getById(id, ownerUid)?.toModel()
    }

    suspend fun saveTask(task: TaskModel) = withContext(ioDispatcher) {
        taskDao.insert(task.toEntity())
    }

    suspend fun saveTasks(tasks: List<TaskModel>) = withContext(ioDispatcher) {
        database.runInTransaction {
            taskDao.insertAll(tasks.map { it.toEntity() })
        }
    }

    suspend fun deleteTask(id: String, ownerUid: String): Boolean = withContext(ioDispatcher) {
        taskDao.deleteById(id, ownerUid) > 0
    }

    suspend fun deleteAllForUser(ownerUid: String): Int = withContext(ioDispatcher) {
        taskDao.deleteAllForUser(ownerUid)
    }

    suspend fun countForUser(ownerUid: String): Int = withContext(ioDispatcher) {
        taskDao.getTaskCountForUser(ownerUid)
    }
}
