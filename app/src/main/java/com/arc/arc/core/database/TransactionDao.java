package com.arc.arc.core.database;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;
import androidx.room.Update;

import java.util.List;

/**
 * Data Access Object for Room transactions table.
 * Fully user-isolated via ownerUid.
 */
@Dao
public interface TransactionDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insertTransaction(TransactionEntity transaction);

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insertAllTransactions(List<TransactionEntity> transactions);

    @Update
    void updateTransaction(TransactionEntity transaction);

    @Query("DELETE FROM transactions WHERE id = :id AND ownerUid = :ownerUid")
    int deleteTransactionById(String id, String ownerUid);

    @Query("DELETE FROM transactions WHERE ownerUid = :ownerUid")
    int deleteAllTransactionsForUser(String ownerUid);

    @Query("SELECT * FROM transactions WHERE id = :id AND ownerUid = :ownerUid LIMIT 1")
    TransactionEntity getTransactionById(String id, String ownerUid);

    @Query("SELECT * FROM transactions WHERE ownerUid = :ownerUid ORDER BY date DESC, createdAt DESC")
    List<TransactionEntity> getAllTransactionsForUser(String ownerUid);

    @Query("SELECT * FROM transactions WHERE ownerUid = :ownerUid AND date >= :startDate AND date <= :endDate ORDER BY date DESC, createdAt DESC")
    List<TransactionEntity> getTransactionsForDateRange(String ownerUid, long startDate, long endDate);

    @Query("SELECT * FROM transactions WHERE ownerUid = :ownerUid AND type = :type ORDER BY date DESC, createdAt DESC")
    List<TransactionEntity> getTransactionsByType(String ownerUid, String type);

    @Query("SELECT * FROM transactions WHERE ownerUid = :ownerUid AND category = :category ORDER BY date DESC, createdAt DESC")
    List<TransactionEntity> getTransactionsByCategory(String ownerUid, String category);

    @Query("SELECT * FROM transactions WHERE ownerUid = :ownerUid AND automationFingerprint = :fingerprint LIMIT 1")
    TransactionEntity getTransactionByFingerprint(String ownerUid, String fingerprint);

    @Query("SELECT COALESCE(SUM(amountPaise), 0) FROM transactions WHERE ownerUid = :ownerUid AND type = :type AND date >= :startDate AND date <= :endDate")
    long getTotalAmountPaiseForTypeAndRange(String ownerUid, String type, long startDate, long endDate);

    @Query("SELECT COUNT(*) FROM transactions WHERE ownerUid = :ownerUid")
    int getTransactionCountForUser(String ownerUid);
}
