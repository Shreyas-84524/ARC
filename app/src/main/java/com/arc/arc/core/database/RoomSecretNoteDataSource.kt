package com.arc.arc.core.database

import androidx.room.InvalidationTracker
import com.arc.arc.core.database.SecretNoteMappers.toEntity
import com.arc.arc.core.database.SecretNoteMappers.toModel
import com.arc.arc.core.model.SecretNoteModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext

/**
 * Local Room data source implementation for encrypted Secret Notes persistence.
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. Plaintext notes are NEVER persisted to SQLite disk storage.
 * 2. Multi-user partitioning is enforced via [ownerUid].
 * 3. In-memory decryption requires a valid 256-bit Data Encryption Key (DEK).
 */
class RoomSecretNoteDataSource(
    private val database: ArcDatabase,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    private val secretNoteDao: SecretNoteDao get() = database.secretNoteDao()

    /**
     * Observes encrypted notes reactively for the given user, decrypting them with the provided DEK.
     * Corrupted or tampered records are safely filtered out.
     */
    fun observeNotes(ownerUid: String, dek: ByteArray): Flow<List<SecretNoteModel>> = callbackFlow {
        val observer = object : InvalidationTracker.Observer("secret_notes") {
            override fun onInvalidated(tables: Set<String>) {
                val current = secretNoteDao.getNotes(ownerUid).mapNotNull { entity ->
                    runCatching { entity.toModel(dek) }.getOrNull()
                }
                trySend(current)
            }
        }

        database.invalidationTracker.addObserver(observer)
        val initial = secretNoteDao.getNotes(ownerUid).mapNotNull { entity ->
            runCatching { entity.toModel(dek) }.getOrNull()
        }
        trySend(initial)

        awaitClose {
            database.invalidationTracker.removeObserver(observer)
        }
    }.flowOn(ioDispatcher)

    /**
     * Retrieves decrypted notes for [ownerUid] using [dek].
     */
    suspend fun getNotes(ownerUid: String, dek: ByteArray): List<SecretNoteModel> = withContext(ioDispatcher) {
        secretNoteDao.getNotes(ownerUid).map { it.toModel(dek) }
    }

    /**
     * Retrieves a single decrypted note by [id] and [ownerUid].
     */
    suspend fun getNoteById(id: String, ownerUid: String, dek: ByteArray): SecretNoteModel? = withContext(ioDispatcher) {
        secretNoteDao.getNoteById(id, ownerUid)?.toModel(dek)
    }

    /**
     * Retrieves raw encrypted entities (useful for backup, migration, and security assertions).
     */
    suspend fun getRawEntities(ownerUid: String): List<SecretNoteEntity> = withContext(ioDispatcher) {
        secretNoteDao.getNotes(ownerUid)
    }

    /**
     * Encrypts and saves a note to Room.
     */
    suspend fun saveNote(note: SecretNoteModel, dek: ByteArray) = withContext(ioDispatcher) {
        secretNoteDao.insert(note.toEntity(dek))
    }

    /**
     * Encrypts and saves multiple notes in a single database transaction.
     */
    suspend fun saveNotes(notes: List<SecretNoteModel>, dek: ByteArray) = withContext(ioDispatcher) {
        database.runInTransaction {
            notes.forEach { note ->
                secretNoteDao.insert(note.toEntity(dek))
            }
        }
    }

    /**
     * Deletes a note by ID for the specific owner.
     */
    suspend fun deleteNote(id: String, ownerUid: String): Int = withContext(ioDispatcher) {
        secretNoteDao.deleteById(id, ownerUid)
    }

    /**
     * Deletes all secret notes belonging to the specified owner.
     */
    suspend fun deleteAllForUser(ownerUid: String): Int = withContext(ioDispatcher) {
        secretNoteDao.deleteAllForUser(ownerUid)
    }

    /**
     * Returns total count of secret notes for the user.
     */
    suspend fun countNotes(ownerUid: String): Int = withContext(ioDispatcher) {
        secretNoteDao.countNotes(ownerUid)
    }
}
