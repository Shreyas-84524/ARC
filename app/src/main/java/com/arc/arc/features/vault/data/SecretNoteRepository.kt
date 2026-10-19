package com.arc.arc.features.vault.data

import com.arc.arc.core.database.RoomSecretNoteDataSource
import com.arc.arc.core.database.SecretNoteEntity
import com.arc.arc.core.model.SecretNoteModel
import kotlinx.coroutines.flow.Flow
import java.util.Date

interface ISecretNoteRepository {
    fun getNotesFlow(ownerUid: String, dek: ByteArray): Flow<List<SecretNoteModel>>
    suspend fun getNotes(ownerUid: String, dek: ByteArray): List<SecretNoteModel>
    suspend fun getNoteById(id: String, ownerUid: String, dek: ByteArray): SecretNoteModel?
    suspend fun saveNote(note: SecretNoteModel, dek: ByteArray): Result<Unit>
    suspend fun deleteNote(id: String, ownerUid: String): Result<Unit>
    suspend fun deleteAllForUser(ownerUid: String): Result<Unit>
    suspend fun getNoteCount(ownerUid: String): Int
    suspend fun getRawEntities(ownerUid: String): List<SecretNoteEntity>
}

/**
 * Local-only, offline-first repository for Secret Notes.
 *
 * CRITICAL ARCHITECTURAL CONSTRAINTS:
 * 1. Zero Cloud Sync: Notes are strictly stored in local encrypted Room storage.
 * 2. Zero Plaintext Persistence: Every write is encrypted via AES-256-GCM before entering SQLite.
 * 3. Multi-User Isolation: Notes are strictly filtered by [ownerUid].
 */
class OfflineFirstSecretNoteRepository(
    private val localDataSource: RoomSecretNoteDataSource
) : ISecretNoteRepository {

    override fun getNotesFlow(ownerUid: String, dek: ByteArray): Flow<List<SecretNoteModel>> {
        return localDataSource.observeNotes(ownerUid, dek)
    }

    override suspend fun getNotes(ownerUid: String, dek: ByteArray): List<SecretNoteModel> {
        return localDataSource.getNotes(ownerUid, dek)
    }

    override suspend fun getNoteById(id: String, ownerUid: String, dek: ByteArray): SecretNoteModel? {
        return localDataSource.getNoteById(id, ownerUid, dek)
    }

    override suspend fun saveNote(note: SecretNoteModel, dek: ByteArray): Result<Unit> {
        return try {
            if (!note.isValid) {
                return Result.failure(IllegalArgumentException("Note must have a title, description, or checklist item"))
            }
            val updated = note.copy(updatedAt = Date())
            localDataSource.saveNote(updated, dek)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun deleteNote(id: String, ownerUid: String): Result<Unit> {
        return try {
            val rows = localDataSource.deleteNote(id, ownerUid)
            if (rows > 0) Result.success(Unit)
            else Result.failure(NoSuchElementException("Note not found or does not belong to user"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun deleteAllForUser(ownerUid: String): Result<Unit> {
        return try {
            localDataSource.deleteAllForUser(ownerUid)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun getNoteCount(ownerUid: String): Int {
        return localDataSource.countNotes(ownerUid)
    }

    override suspend fun getRawEntities(ownerUid: String): List<SecretNoteEntity> {
        return localDataSource.getRawEntities(ownerUid)
    }
}
