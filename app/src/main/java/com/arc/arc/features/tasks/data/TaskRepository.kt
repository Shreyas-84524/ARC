package com.arc.arc.features.tasks.data

import com.arc.arc.core.database.RoomTaskDataSource
import com.arc.arc.core.model.TaskModel
import kotlinx.coroutines.flow.Flow
import java.util.Date

sealed interface SyncResult {
    data class Success(val syncedCount: Int) : SyncResult
    data class PendingOffline(val pendingCount: Int, val reason: String) : SyncResult
    data class Failure(val error: String) : SyncResult
}

interface ITaskRepository {
    fun getTasksFlow(ownerUid: String): Flow<List<TaskModel>>
    suspend fun getTasks(ownerUid: String): List<TaskModel>
    suspend fun getTaskById(id: String, ownerUid: String): TaskModel?
    suspend fun saveTask(task: TaskModel): Result<Unit>
    suspend fun toggleTaskCompletion(taskId: String, ownerUid: String): Result<TaskModel>
    suspend fun deleteTask(taskId: String, ownerUid: String): Result<Unit>
    suspend fun syncPending(ownerUid: String): SyncResult
}

/**
 * Offline-first TaskRepository.
 * Local Room storage is the immediate source of truth.
 * Prepared with cloud sync contracts for future Firestore integration.
 */
class OfflineFirstTaskRepository(
    private val localDataSource: RoomTaskDataSource
) : ITaskRepository {

    override fun getTasksFlow(ownerUid: String): Flow<List<TaskModel>> {
        return localDataSource.observeTasks(ownerUid)
    }

    override suspend fun getTasks(ownerUid: String): List<TaskModel> {
        return localDataSource.getTasks(ownerUid)
    }

    override suspend fun getTaskById(id: String, ownerUid: String): TaskModel? {
        return localDataSource.getTask(id, ownerUid)
    }

    override suspend fun saveTask(task: TaskModel): Result<Unit> {
        if (task.title.isBlank()) {
            return Result.failure(IllegalArgumentException("Task title cannot be empty"))
        }
        val updated = task.copy(updatedAt = Date())
        localDataSource.saveTask(updated)
        return Result.success(Unit)
    }

    override suspend fun toggleTaskCompletion(taskId: String, ownerUid: String): Result<TaskModel> {
        val existing = localDataSource.getTask(taskId, ownerUid)
            ?: return Result.failure(NoSuchElementException("Task not found: $taskId"))

        val now = Date()
        val isNowCompleted = !existing.completed
        val updated = existing.copy(
            completed = isNowCompleted,
            completedAt = if (isNowCompleted) now else null,
            updatedAt = now,
        )

        localDataSource.saveTask(updated)
        return Result.success(updated)
    }

    override suspend fun deleteTask(taskId: String, ownerUid: String): Result<Unit> {
        val deleted = localDataSource.deleteTask(taskId, ownerUid)
        return if (deleted) {
            Result.success(Unit)
        } else {
            Result.failure(NoSuchElementException("Task not found or not deleted: $taskId"))
        }
    }

    override suspend fun syncPending(ownerUid: String): SyncResult {
        // In Phase 1 local-first mode without approved production Firebase config,
        // all operations are persisted locally.
        return SyncResult.PendingOffline(
            pendingCount = 0,
            reason = "Local-first storage active. Cloud sync pending Firebase project configuration in later phase."
        )
    }
}
