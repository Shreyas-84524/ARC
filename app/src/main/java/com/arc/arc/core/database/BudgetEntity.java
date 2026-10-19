package com.arc.arc.core.database;

import androidx.annotation.NonNull;
import androidx.room.Entity;
import androidx.room.Index;
import androidx.room.PrimaryKey;

/**
 * Room persistence entity for ARC monthly budgets.
 * Scoped by ownerUid and month (format: "yyyy-MM").
 * Primary key is "${ownerUid}_${month}".
 */
@Entity(
    tableName = "budgets",
    indices = {
        @Index("ownerUid"),
        @Index({"ownerUid", "month"})
    }
)
public class BudgetEntity {
    @PrimaryKey
    @NonNull
    public String id; // ownerUid + "_" + month

    @NonNull
    public String ownerUid;

    @NonNull
    public String month; // "yyyy-MM"

    public long amountPaise;

    public double amount;

    public long updatedAt;

    public BudgetEntity(
        @NonNull String id,
        @NonNull String ownerUid,
        @NonNull String month,
        long amountPaise,
        double amount,
        long updatedAt
    ) {
        this.id = id;
        this.ownerUid = ownerUid;
        this.month = month;
        this.amountPaise = amountPaise;
        this.amount = amount;
        this.updatedAt = updatedAt;
    }
}
