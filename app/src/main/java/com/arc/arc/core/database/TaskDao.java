package com.arc.arc.core.database;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;
import androidx.room.Update;

import java.util.List;

/**
 * Data Access Object for Room tasks table.
 */
@Dao
public interface TaskDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insert(TaskEntity task);

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insertAll(List<TaskEntity> tasks);

    @Update
    void update(TaskEntity task);

    @Query("DELETE FROM tasks WHERE id = :id AND ownerUid = :ownerUid")
    int deleteById(String id, String ownerUid);

    @Query("DELETE FROM tasks WHERE ownerUid = :ownerUid")
    int deleteAllForUser(String ownerUid);

    @Query("SELECT * FROM tasks WHERE id = :id AND ownerUid = :ownerUid LIMIT 1")
    TaskEntity getById(String id, String ownerUid);

    @Query("SELECT * FROM tasks WHERE ownerUid = :ownerUid ORDER BY createdAt DESC")
    List<TaskEntity> getAllForUser(String ownerUid);

    @Query("SELECT * FROM tasks WHERE ownerUid = :ownerUid AND completed = 0 ORDER BY createdAt DESC")
    List<TaskEntity> getPendingForUser(String ownerUid);

    @Query("SELECT * FROM tasks WHERE ownerUid = :ownerUid AND completed = 1 ORDER BY completedAt DESC")
    List<TaskEntity> getCompletedForUser(String ownerUid);

    @Query("SELECT COUNT(*) FROM tasks WHERE ownerUid = :ownerUid")
    int getTaskCountForUser(String ownerUid);
}
