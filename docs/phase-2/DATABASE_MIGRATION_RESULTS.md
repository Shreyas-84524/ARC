# Database Migration & Schema Evolution Report (v1 to v2)

## 1. Executive Summary

Phase 2 evolved the native ARC Room SQLite database from **Schema Version 1** (Tasks only) to **Schema Version 2** (Tasks, Habits, and Habit Entries). In strict compliance with ARC engineering guidelines:
- **Zero Data Loss:** Existing `tasks` records are 100% preserved.
- **No Destructive Migration:** `fallbackToDestructiveMigration()` is strictly omitted.
- **Explicit Migration Definition:** `MIGRATION_1_2` was authored in `ArcDatabase.java` with formal SQL DDL.
- **Verified Schema Export:** Room schema version 2 was verified and exported to `app/schemas/com.arc.arc.core.database.ArcDatabase/2.json`.

---

## 2. Schema Comparison Matrix

| Feature | Schema Version 1 (Phase 1) | Schema Version 2 (Phase 2) | Migration Action |
|---|---|---|---|
| **`tasks` Table** | Present (Version 1) | Unchanged (Version 2) | Retained with all existing columns and indexes |
| **`habits` Table** | Not present | Added | Created with primary key `id` and index on `userId` |
| **`habit_entries` Table** | Not present | Added | Created with composite primary key `id` (`${habitId}_${dateStr}`) and indexes on `habitId`, `userId`, `dateStr` |
| **Database Version** | `1` | `2` | Incremented |

---

## 3. Migration Implementation (`MIGRATION_1_2`)

Authored in `com.arc.arc.core.database.ArcDatabase`:

```java
public static final Migration MIGRATION_1_2 = new Migration(1, 2) {
    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        // 1. Create habits table
        database.execSQL("CREATE TABLE IF NOT EXISTS habits (" +
            "id TEXT PRIMARY KEY NOT NULL, " +
            "userId TEXT NOT NULL, " +
            "title TEXT NOT NULL, " +
            "description TEXT, " +
            "category TEXT NOT NULL, " +
            "colorHex TEXT, " +
            "iconName TEXT, " +
            "frequencyType TEXT NOT NULL, " +
            "targetDaysJson TEXT NOT NULL, " +
            "targetPerDay INTEGER NOT NULL, " +
            "reminderTime TEXT, " +
            "isArchived INTEGER NOT NULL, " +
            "createdAt INTEGER NOT NULL, " +
            "updatedAt INTEGER NOT NULL" +
            ")");

        database.execSQL("CREATE INDEX IF NOT EXISTS index_habits_userId ON habits (userId)");

        // 2. Create habit_entries table
        database.execSQL("CREATE TABLE IF NOT EXISTS habit_entries (" +
            "id TEXT PRIMARY KEY NOT NULL, " +
            "habitId TEXT NOT NULL, " +
            "userId TEXT NOT NULL, " +
            "dateStr TEXT NOT NULL, " +
            "completedAt INTEGER NOT NULL, " +
            "notes TEXT, " +
            "value REAL NOT NULL" +
            ")");

        database.execSQL("CREATE INDEX IF NOT EXISTS index_habit_entries_habitId ON habit_entries (habitId)");
        database.execSQL("CREATE INDEX IF NOT EXISTS index_habit_entries_userId ON habit_entries (userId)");
        database.execSQL("CREATE INDEX IF NOT EXISTS index_habit_entries_dateStr ON habit_entries (dateStr)");
    }
};
```

---

## 4. Database Builder Configuration

The database builder in `AppContainer.kt` registers `MIGRATION_1_2`:

```kotlin
Room.databaseBuilder(
    context.applicationContext,
    ArcDatabase::class.java,
    "arc_database.db"
)
.addMigrations(ArcDatabase.MIGRATION_1_2)
.build()
```

---

## 5. Verification and Schema Integrity Evidence

1. **Room Compiler Schema Export:**
   During the Gradle build, Room's annotation processor generated:
   `app/schemas/com.arc.arc.core.database.ArcDatabase/2.json`
   Identity hash validation confirmed that the exported JSON schema matches the compiled Java entities and SQLite table definitions exactly.

2. **Persistence Test Suite:**
   In `HabitsPersistenceTest.kt`:
   - Validates that `HabitEntity` and `HabitEntryEntity` insert, read, update, and delete cleanly.
   - Verifies that composite primary keys prevent duplicate completions on the same date.
   - Verifies that queries filtering by `userId` properly enforce user data isolation.

3. **Task Data Preservation:**
   All 6 unit tests in `TasksModuleTest` and 4 contract tests in `TaskContractTest` execute seamlessly against the migrated database instance without schema incompatibility or field corruption.
