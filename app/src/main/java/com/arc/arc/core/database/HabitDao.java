package com.arc.arc.core.database;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;
import androidx.room.Update;

import java.util.List;

/**
 * Data Access Object for Room habits and habit_entries tables.
 * Fully user-isolated.
 */
@Dao
public interface HabitDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insertHabit(HabitEntity habit);

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insertAllHabits(List<HabitEntity> habits);

    @Update
    void updateHabit(HabitEntity habit);

    @Query("DELETE FROM habits WHERE id = :id AND ownerUid = :ownerUid")
    int deleteHabitById(String id, String ownerUid);

    @Query("DELETE FROM habits WHERE ownerUid = :ownerUid")
    int deleteAllHabitsForUser(String ownerUid);

    @Query("SELECT * FROM habits WHERE id = :id AND ownerUid = :ownerUid LIMIT 1")
    HabitEntity getHabitById(String id, String ownerUid);

    @Query("SELECT * FROM habits WHERE ownerUid = :ownerUid ORDER BY createdAt ASC")
    List<HabitEntity> getAllHabitsForUser(String ownerUid);

    @Query("SELECT COUNT(*) FROM habits WHERE ownerUid = :ownerUid")
    int getHabitCountForUser(String ownerUid);

    // Entries operations
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insertEntry(HabitEntryEntity entry);

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insertAllEntries(List<HabitEntryEntity> entries);

    @Query("DELETE FROM habit_entries WHERE id = :entryId AND ownerUid = :ownerUid")
    int deleteEntryById(String entryId, String ownerUid);

    @Query("DELETE FROM habit_entries WHERE habitId = :habitId AND ownerUid = :ownerUid")
    int deleteEntriesForHabit(String habitId, String ownerUid);

    @Query("DELETE FROM habit_entries WHERE ownerUid = :ownerUid")
    int deleteAllEntriesForUser(String ownerUid);

    @Query("SELECT * FROM habit_entries WHERE id = :entryId AND ownerUid = :ownerUid LIMIT 1")
    HabitEntryEntity getEntryById(String entryId, String ownerUid);

    @Query("SELECT * FROM habit_entries WHERE ownerUid = :ownerUid")
    List<HabitEntryEntity> getAllEntriesForUser(String ownerUid);

    @Query("SELECT * FROM habit_entries WHERE ownerUid = :ownerUid AND dateStr = :dateStr")
    List<HabitEntryEntity> getEntriesForDate(String ownerUid, String dateStr);

    @Query("SELECT * FROM habit_entries WHERE ownerUid = :ownerUid AND habitId = :habitId")
    List<HabitEntryEntity> getEntriesForHabit(String ownerUid, String habitId);
}
