# Room Database Migration V3 Specification

## 1. Schema Version 3 Migration

Phase 3 introduces Room Database Version 3 via the formal, non-destructive migration `MIGRATION_2_3`. In accordance with non-negotiable migration rules, `fallbackToDestructiveMigration` is strictly prohibited.

---

## 2. Migration DDL

Authored in `com.arc.arc.core.database.ArcDatabase.java`:

```java
public static final Migration MIGRATION_2_3 = new Migration(2, 3) {
    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        // 1. Create transactions table
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS `transactions` ("
                + "`id` TEXT NOT NULL, "
                + "`ownerUid` TEXT NOT NULL, "
                + "`amount` REAL NOT NULL, "
                + "`amountPaise` INTEGER NOT NULL, "
                + "`type` TEXT NOT NULL, "
                + "`category` TEXT NOT NULL, "
                + "`date` INTEGER NOT NULL, "
                + "`time` TEXT NOT NULL, "
                + "`notes` TEXT NOT NULL, "
                + "`source` TEXT NOT NULL, "
                + "`automationFingerprint` TEXT, "
                + "`createdAt` INTEGER NOT NULL, "
                + "PRIMARY KEY(`id`)"
                + ")"
        );

        // 2. Create indices on transactions
        database.execSQL(
            "CREATE INDEX IF NOT EXISTS `index_transactions_ownerUid` ON `transactions` (`ownerUid`)"
        );
        database.execSQL(
            "CREATE INDEX IF NOT EXISTS `index_transactions_date` ON `transactions` (`date`)"
        );
        database.execSQL(
            "CREATE INDEX IF NOT EXISTS `index_transactions_automationFingerprint` ON `transactions` (`automationFingerprint`)"
        );

        // 3. Create budgets table
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS `budgets` ("
                + "`id` TEXT NOT NULL, "
                + "`ownerUid` TEXT NOT NULL, "
                + "`month` TEXT NOT NULL, "
                + "`amount` REAL NOT NULL, "
                + "`amountPaise` INTEGER NOT NULL, "
                + "`createdAt` INTEGER NOT NULL, "
                + "`updatedAt` INTEGER NOT NULL, "
                + "PRIMARY KEY(`id`)"
                + ")"
        );

        // 4. Create unique index on budgets (ownerUid + month)
        database.execSQL(
            "CREATE UNIQUE INDEX IF NOT EXISTS `index_budgets_ownerUid_month` ON `budgets` (`ownerUid`, `month`)"
        );
    }
};
```

---

## 3. Schema JSON Verification

The schema JSON has been successfully generated and exported:
`app/schemas/com.arc.arc.core.database.ArcDatabase/3.json`

Summary of tables in Schema Version 3:
1. `tasks` (Schema V1)
2. `habits` (Schema V2)
3. `habit_entries` (Schema V2)
4. `transactions` (Schema V3)
5. `budgets` (Schema V3)

All existing user data in `tasks`, `habits`, and `habit_entries` is 100% preserved during migration.
