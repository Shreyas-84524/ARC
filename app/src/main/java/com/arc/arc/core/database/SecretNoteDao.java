package com.arc.arc.core.database;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;

import java.util.List;

import kotlinx.coroutines.flow.Flow;

/**
 * Room Data Access Object for encrypted secret notes.
 * Enforces strict multi-user scoping via ownerUid in all queries.
 */
@Dao
public interface SecretNoteDao {

    @Query("SELECT * FROM secret_notes WHERE ownerUid = :ownerUid ORDER BY updatedAt DESC")
    Flow<List<SecretNoteEntity>> observeNotes(String ownerUid);

    @Query("SELECT * FROM secret_notes WHERE ownerUid = :ownerUid ORDER BY updatedAt DESC")
    List<SecretNoteEntity> getNotes(String ownerUid);

    @Query("SELECT * FROM secret_notes WHERE id = :id AND ownerUid = :ownerUid LIMIT 1")
    SecretNoteEntity getNoteById(String id, String ownerUid);

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insert(SecretNoteEntity note);

    @Query("DELETE FROM secret_notes WHERE id = :id AND ownerUid = :ownerUid")
    int deleteById(String id, String ownerUid);

    @Query("DELETE FROM secret_notes WHERE ownerUid = :ownerUid")
    int deleteAllForUser(String ownerUid);

    @Query("SELECT COUNT(*) FROM secret_notes WHERE ownerUid = :ownerUid")
    int countNotes(String ownerUid);
}
