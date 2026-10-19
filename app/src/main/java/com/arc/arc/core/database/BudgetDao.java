package com.arc.arc.core.database;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;
import androidx.room.Update;

import java.util.List;

/**
 * Data Access Object for Room budgets table.
 * Fully user-isolated via ownerUid.
 */
@Dao
public interface BudgetDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insertBudget(BudgetEntity budget);

    @Update
    void updateBudget(BudgetEntity budget);

    @Query("SELECT * FROM budgets WHERE ownerUid = :ownerUid AND month = :month LIMIT 1")
    BudgetEntity getBudgetForMonth(String ownerUid, String month);

    @Query("SELECT * FROM budgets WHERE ownerUid = :ownerUid ORDER BY month DESC")
    List<BudgetEntity> getAllBudgetsForUser(String ownerUid);

    @Query("DELETE FROM budgets WHERE ownerUid = :ownerUid AND month = :month")
    int deleteBudgetForMonth(String ownerUid, String month);

    @Query("DELETE FROM budgets WHERE ownerUid = :ownerUid")
    int deleteAllBudgetsForUser(String ownerUid);
}
