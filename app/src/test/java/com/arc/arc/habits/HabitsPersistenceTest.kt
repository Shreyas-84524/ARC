package com.arc.arc.habits

import com.arc.arc.core.database.ArcDatabase
import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import com.arc.arc.features.habits.data.IHabitRepository
import com.arc.arc.features.tasks.data.SyncResult
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Date

/**
 * In-memory test repository implementing IHabitRepository with exact Room foreign-key
 * cascade deletion, composite key uniqueness, and user isolation semantics.
 */
class InMemoryHabitRepository : IHabitRepository {
    private val habitsStore = MutableStateFlow<Map<String, HabitModel>>(emptyMap())
    private val entriesStore = MutableStateFlow<Map<String, HabitEntryModel>>(emptyMap())

    override fun getHabitsFlow(ownerUid: String): Flow<List<HabitModel>> {
        return habitsStore.map { map ->
            map.values.filter { it.ownerUid == ownerUid }
        }
    }

    override fun getEntriesFlow(ownerUid: String): Flow<List<HabitEntryModel>> {
        return entriesStore.map { map ->
            map.values.filter { it.ownerUid == ownerUid }
        }
    }

    override fun getEntriesForDateFlow(ownerUid: String, dateStr: String): Flow<List<HabitEntryModel>> {
        return entriesStore.map { map ->
            map.values.filter { it.ownerUid == ownerUid && it.dateStr == dateStr }
        }
    }

    override suspend fun getHabits(ownerUid: String): List<HabitModel> {
        return habitsStore.value.values.filter { it.ownerUid == ownerUid }
    }

    override suspend fun getHabitById(id: String, ownerUid: String): HabitModel? {
        return habitsStore.value[id]?.takeIf { it.ownerUid == ownerUid }
    }

    override suspend fun saveHabit(habit: HabitModel): Result<Unit> {
        if (habit.name.isBlank()) {
            return Result.failure(IllegalArgumentException("Habit name cannot be empty"))
        }
        val current = habitsStore.value.toMutableMap()
        current[habit.id] = habit.copy(updatedAt = Date())
        habitsStore.value = current
        return Result.success(Unit)
    }

    override suspend fun deleteHabit(id: String, ownerUid: String): Result<Unit> {
        val existing = getHabitById(id, ownerUid)
            ?: return Result.failure(NoSuchElementException("Habit not found: $id"))

        // Cascade delete all associated entries
        val currentEntries = entriesStore.value.toMutableMap()
        val toRemove = currentEntries.values.filter { it.habitId == id && it.ownerUid == ownerUid }.map { it.id }
        toRemove.forEach { currentEntries.remove(it) }
        entriesStore.value = currentEntries

        val currentHabits = habitsStore.value.toMutableMap()
        currentHabits.remove(id)
        habitsStore.value = currentHabits
        return Result.success(Unit)
    }

    override suspend fun getEntries(ownerUid: String): List<HabitEntryModel> {
        return entriesStore.value.values.filter { it.ownerUid == ownerUid }
    }

    override suspend fun getEntriesForDate(ownerUid: String, dateStr: String): List<HabitEntryModel> {
        return entriesStore.value.values.filter { it.ownerUid == ownerUid && it.dateStr == dateStr }
    }

    override suspend fun toggleHabitCompletion(
        habitId: String,
        dateStr: String,
        completed: Boolean,
        ownerUid: String
    ): Result<HabitEntryModel> {
        val entryId = HabitEntryModel.createId(habitId, dateStr)
        val currentEntries = entriesStore.value.toMutableMap()

        val model = HabitEntryModel(
            id = entryId,
            ownerUid = ownerUid,
            habitId = habitId,
            dateStr = dateStr,
            completed = completed,
        )

        if (completed) {
            currentEntries[entryId] = model
        } else {
            currentEntries.remove(entryId)
        }
        entriesStore.value = currentEntries
        return Result.success(model)
    }

    override suspend fun undoHabitCompletion(
        habitId: String,
        dateStr: String,
        ownerUid: String
    ): Result<Unit> {
        val entryId = HabitEntryModel.createId(habitId, dateStr)
        val currentEntries = entriesStore.value.toMutableMap()
        currentEntries.remove(entryId)
        entriesStore.value = currentEntries
        return Result.success(Unit)
    }

    override suspend fun syncPending(ownerUid: String): SyncResult {
        return SyncResult.PendingOffline(0, "Local-first")
    }
}

class HabitsPersistenceTest {

    private lateinit var repository: InMemoryHabitRepository

    @Before
    fun setup() {
        repository = InMemoryHabitRepository()
    }

    @Test
    fun testHabitCRUDOperations() = runTest {
        val habit = HabitModel(
            id = "habit-1",
            ownerUid = "user-a",
            name = "Morning Run",
            category = "Fitness",
            colorValue = 0xFFEF4444L,
            reminderTime = "06:30",
        )

        // Create
        val createResult = repository.saveHabit(habit)
        assertTrue(createResult.isSuccess)

        // Read
        val fetched = repository.getHabitById("habit-1", "user-a")
        assertNotNull(fetched)
        assertEquals("Morning Run", fetched?.name)

        // Update
        val updated = fetched!!.copy(name = "Morning 5K Run")
        repository.saveHabit(updated)
        val fetchedUpdated = repository.getHabitById("habit-1", "user-a")
        assertEquals("Morning 5K Run", fetchedUpdated?.name)

        // Delete
        val deleteResult = repository.deleteHabit("habit-1", "user-a")
        assertTrue(deleteResult.isSuccess)
        assertNull(repository.getHabitById("habit-1", "user-a"))
    }

    @Test
    fun testCascadeDeletionOfHabitEntries() = runTest {
        val habit = HabitModel(id = "habit-cascade", ownerUid = "user-a", name = "Guitar Practice")
        repository.saveHabit(habit)

        // Add entries for 3 different days
        repository.toggleHabitCompletion("habit-cascade", "2026-10-16", true, "user-a")
        repository.toggleHabitCompletion("habit-cascade", "2026-10-17", true, "user-a")
        repository.toggleHabitCompletion("habit-cascade", "2026-10-18", true, "user-a")

        assertEquals(3, repository.getEntries("user-a").size)

        // Deleting the habit must cascade delete all associated entries
        repository.deleteHabit("habit-cascade", "user-a")

        assertEquals(0, repository.getEntries("user-a").size)
    }

    @Test
    fun testUserIsolationEnforcedStrictly() = runTest {
        // User A records
        val habitA = HabitModel(id = "h-user-a", ownerUid = "user-a", name = "User A Habit")
        repository.saveHabit(habitA)
        repository.toggleHabitCompletion("h-user-a", "2026-10-18", true, "user-a")

        // User B records
        val habitB = HabitModel(id = "h-user-b", ownerUid = "user-b", name = "User B Habit")
        repository.saveHabit(habitB)
        repository.toggleHabitCompletion("h-user-b", "2026-10-18", true, "user-b")

        // User A must only see their own habits and entries
        val userAHabits = repository.getHabits("user-a")
        assertEquals(1, userAHabits.size)
        assertEquals("h-user-a", userAHabits.first().id)

        val userAEntries = repository.getEntries("user-a")
        assertEquals(1, userAEntries.size)
        assertEquals("h-user-a_2026-10-18", userAEntries.first().id)

        // User B must only see their own habits and entries
        val userBHabits = repository.getHabits("user-b")
        assertEquals(1, userBHabits.size)
        assertEquals("h-user-b", userBHabits.first().id)

        val userBEntries = repository.getEntries("user-b")
        assertEquals(1, userBEntries.size)
        assertEquals("h-user-b_2026-10-18", userBEntries.first().id)
    }

    @Test
    fun testCompositeKeyUniquenessAndToggle() = runTest {
        val habit = HabitModel(id = "h-toggle", ownerUid = "user-a", name = "Drink Water")
        repository.saveHabit(habit)

        // Complete for 2026-10-18
        repository.toggleHabitCompletion("h-toggle", "2026-10-18", true, "user-a")
        var entries = repository.getEntriesForDate("user-a", "2026-10-18")
        assertEquals(1, entries.size)
        assertTrue(entries.first().completed)

        // Toggle to false (uncheck)
        repository.toggleHabitCompletion("h-toggle", "2026-10-18", false, "user-a")
        entries = repository.getEntriesForDate("user-a", "2026-10-18")
        assertEquals(0, entries.size)

        // Toggle back to true
        repository.toggleHabitCompletion("h-toggle", "2026-10-18", true, "user-a")
        entries = repository.getEntriesForDate("user-a", "2026-10-18")
        assertEquals(1, entries.size)
        assertEquals("h-toggle_2026-10-18", entries.first().id)
    }

    @Test
    fun testMigrationVersionDefinition() {
        assertEquals(1, ArcDatabase.MIGRATION_1_2.startVersion)
        assertEquals(2, ArcDatabase.MIGRATION_1_2.endVersion)
    }
}
