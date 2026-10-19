package com.arc.arc.core.database;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.room.Entity;
import androidx.room.Index;
import androidx.room.PrimaryKey;

/**
 * Room persistence entity for ARC habits.
 * User-isolated via ownerUid index.
 */
@Entity(
    tableName = "habits",
    indices = {
        @Index("ownerUid"),
        @Index({"ownerUid", "name"}),
        @Index({"ownerUid", "createdAt"})
    }
)
public class HabitEntity {
    @PrimaryKey
    @NonNull
    public String id;

    @NonNull
    public String ownerUid;

    @NonNull
    public String name;

    @NonNull
    public String category;

    public long colorValue;

    @Nullable
    public String reminderTime;

    public long createdAt;

    public long updatedAt;

    public HabitEntity(
        @NonNull String id,
        @NonNull String ownerUid,
        @NonNull String name,
        @NonNull String category,
        long colorValue,
        @Nullable String reminderTime,
        long createdAt,
        long updatedAt
    ) {
        this.id = id;
        this.ownerUid = ownerUid;
        this.name = name;
        this.category = category;
        this.colorValue = colorValue;
        this.reminderTime = reminderTime;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }
}
