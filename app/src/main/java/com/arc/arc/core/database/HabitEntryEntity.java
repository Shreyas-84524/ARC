package com.arc.arc.core.database;

import androidx.annotation.NonNull;
import androidx.room.Entity;
import androidx.room.ForeignKey;
import androidx.room.Index;
import androidx.room.PrimaryKey;

/**
 * Room persistence entity for ARC habit entries.
 * Composite key: id is formatted as "${habitId}_${dateStr}".
 * Foreign key to habits table with CASCADE delete.
 */
@Entity(
    tableName = "habit_entries",
    foreignKeys = @ForeignKey(
        entity = HabitEntity.class,
        parentColumns = "id",
        childColumns = "habitId",
        onDelete = ForeignKey.CASCADE
    ),
    indices = {
        @Index("ownerUid"),
        @Index("habitId"),
        @Index({"ownerUid", "dateStr"}),
        @Index({"ownerUid", "habitId", "dateStr"})
    }
)
public class HabitEntryEntity {
    @PrimaryKey
    @NonNull
    public String id; // Format: "${habitId}_${dateStr}"

    @NonNull
    public String ownerUid;

    @NonNull
    public String habitId;

    @NonNull
    public String dateStr; // Format: "yyyy-MM-dd"

    public boolean completed;

    public HabitEntryEntity(
        @NonNull String id,
        @NonNull String ownerUid,
        @NonNull String habitId,
        @NonNull String dateStr,
        boolean completed
    ) {
        this.id = id;
        this.ownerUid = ownerUid;
        this.habitId = habitId;
        this.dateStr = dateStr;
        this.completed = completed;
    }
}
