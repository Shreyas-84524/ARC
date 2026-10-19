package com.arc.arc.core.database;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.room.Entity;
import androidx.room.Index;
import androidx.room.PrimaryKey;

/**
 * Room persistence entity for ARC tasks.
 * User-isolated via ownerUid index.
 */
@Entity(
    tableName = "tasks",
    indices = {
        @Index("ownerUid"),
        @Index({"ownerUid", "completed"}),
        @Index({"ownerUid", "createdAt"})
    }
)
public class TaskEntity {
    @PrimaryKey
    @NonNull
    public String id;

    @NonNull
    public String ownerUid;

    @NonNull
    public String title;

    @NonNull
    public String description;

    @NonNull
    public String priority;

    @NonNull
    public String category;

    @NonNull
    public String labelsJson;

    @Nullable
    public Long dueDate;

    @Nullable
    public String dueTime;

    @Nullable
    public Long reminder;

    public boolean completed;

    public long createdAt;

    public long updatedAt;

    @Nullable
    public Long completedAt;

    public TaskEntity(
        @NonNull String id,
        @NonNull String ownerUid,
        @NonNull String title,
        @NonNull String description,
        @NonNull String priority,
        @NonNull String category,
        @NonNull String labelsJson,
        @Nullable Long dueDate,
        @Nullable String dueTime,
        @Nullable Long reminder,
        boolean completed,
        long createdAt,
        long updatedAt,
        @Nullable Long completedAt
    ) {
        this.id = id;
        this.ownerUid = ownerUid;
        this.title = title;
        this.description = description;
        this.priority = priority;
        this.category = category;
        this.labelsJson = labelsJson;
        this.dueDate = dueDate;
        this.dueTime = dueTime;
        this.reminder = reminder;
        this.completed = completed;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        this.completedAt = completedAt;
    }
}
