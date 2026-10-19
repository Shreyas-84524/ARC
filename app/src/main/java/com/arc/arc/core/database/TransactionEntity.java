package com.arc.arc.core.database;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.room.Entity;
import androidx.room.Index;
import androidx.room.PrimaryKey;

/**
 * Room persistence entity for ARC financial transactions.
 * Fully user-isolated via ownerUid indexes.
 * Stores exact amountPaise (integer minor units in paise) to prevent floating-point errors.
 */
@Entity(
    tableName = "transactions",
    indices = {
        @Index("ownerUid"),
        @Index({"ownerUid", "date"}),
        @Index({"ownerUid", "type"}),
        @Index({"ownerUid", "category"}),
        @Index({"ownerUid", "automationFingerprint"})
    }
)
public class TransactionEntity {
    @PrimaryKey
    @NonNull
    public String id;

    @NonNull
    public String ownerUid;

    public long amountPaise;

    public double amount;

    @NonNull
    public String type;

    @NonNull
    public String category;

    public long date;

    @NonNull
    public String time;

    @NonNull
    public String notes;

    public long createdAt;

    @NonNull
    public String source;

    @Nullable
    public String automationFingerprint;

    public TransactionEntity(
        @NonNull String id,
        @NonNull String ownerUid,
        long amountPaise,
        double amount,
        @NonNull String type,
        @NonNull String category,
        long date,
        @NonNull String time,
        @NonNull String notes,
        long createdAt,
        @NonNull String source,
        @Nullable String automationFingerprint
    ) {
        this.id = id;
        this.ownerUid = ownerUid;
        this.amountPaise = amountPaise;
        this.amount = amount;
        this.type = type;
        this.category = category;
        this.date = date;
        this.time = time;
        this.notes = notes;
        this.createdAt = createdAt;
        this.source = source;
        this.automationFingerprint = automationFingerprint;
    }
}
