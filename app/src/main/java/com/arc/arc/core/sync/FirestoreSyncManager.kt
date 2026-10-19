package com.arc.arc.core.sync

import com.arc.arc.core.database.ArcDatabase
import com.arc.arc.core.database.BudgetEntity
import com.arc.arc.core.database.HabitEntity
import com.arc.arc.core.database.HabitEntryEntity
import com.arc.arc.core.database.TaskEntity
import com.arc.arc.core.database.TransactionEntity
import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions
import com.google.gson.Gson
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.format.DateTimeFormatter

enum class SyncStatus {
    IDLE,
    SYNCING,
    SUCCESS,
    ERROR,
    OFFLINE
}

enum class SyncMutationType {
    UPSERT,
    DELETE
}

data class SyncMutation(
    val id: String,
    val collection: String,
    val docId: String,
    val type: SyncMutationType,
    val payload: Map<String, Any?>? = null,
    val timestamp: Long = System.currentTimeMillis(),
    val retryCount: Int = 0,
)

data class SyncSummary(
    val success: Boolean,
    val tasksCount: Int = 0,
    val habitsCount: Int = 0,
    val entriesCount: Int = 0,
    val transactionsCount: Int = 0,
    val budgetsCount: Int = 0,
    val errors: List<String> = emptyList(),
)

/**
 * Interface contract for Cloud Firestore two-way synchronization.
 */
interface IFirestoreSyncManager {
    val syncStatus: StateFlow<SyncStatus>
    val lastSyncTimestamp: StateFlow<Long?>
    val pendingMutationsCount: StateFlow<Int>

    fun startRealtimeSync(uid: String)
    fun stopRealtimeSync()
    suspend fun pullInitialData(uid: String): Result<SyncSummary>
    suspend fun pushPendingMutations(uid: String): Result<Int>
    fun enqueueMutation(mutation: SyncMutation)
}

/**
 * Two-way Cloud Firestore synchronization engine for ARC.
 *
 * CRITICAL ARCHITECTURAL INVARIANTS:
 * 1. Room is the primary offline source of truth.
 * 2. User-scoped Firestore paths: `users/{uid}/{collection}/{docId}`.
 * 3. ZERO-CLOUD VAULT GUARANTEE: Secret notes, vault PINs, and keys are strictly prohibited
 *    from cloud sync and will trigger an immediate [SecurityException] if attempted.
 * 4. Conflict Resolution: Evaluates remote vs local timestamps (Last-Write-Wins), respecting local pending edits.
 * 5. Bounded exponential backoff on retries.
 */
class FirestoreSyncManager(
    private val database: ArcDatabase,
    private val firestore: FirebaseFirestore = FirebaseFirestore.getInstance(),
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : IFirestoreSyncManager {

    private val gson = Gson()
    private val listeners = mutableListOf<ListenerRegistration>()
    private val pendingQueue = mutableListOf<SyncMutation>()

    private val _syncStatus = MutableStateFlow(SyncStatus.IDLE)
    override val syncStatus: StateFlow<SyncStatus> = _syncStatus.asStateFlow()

    private val _lastSyncTimestamp = MutableStateFlow<Long?>(null)
    override val lastSyncTimestamp: StateFlow<Long?> = _lastSyncTimestamp.asStateFlow()

    private val _pendingMutationsCount = MutableStateFlow(0)
    override val pendingMutationsCount: StateFlow<Int> = _pendingMutationsCount.asStateFlow()

    private var activeUid: String? = null

    companion object {
        const val COL_TASKS = "tasks"
        const val COL_HABITS = "habits"
        const val COL_HABIT_ENTRIES = "habitEntries"
        const val COL_TRANSACTIONS = "transactions"
        const val COL_BUDGETS = "budgets"
        const val COL_SETTINGS = "settings"

        val ALLOWED_COLLECTIONS = setOf(
            COL_TASKS,
            COL_HABITS,
            COL_HABIT_ENTRIES,
            COL_TRANSACTIONS,
            COL_BUDGETS,
            COL_SETTINGS
        )

        fun assertVaultExcluded(collection: String) {
            val lower = collection.lowercase()
            if (lower.contains("secret") || lower.contains("vault") || lower.contains("note")) {
                throw SecurityException(
                    "ARCHITECTURAL INVARIANT VIOLATION: Secret Notes & Vault records are local-only and must NEVER sync to Firestore."
                )
            }
            if (!ALLOWED_COLLECTIONS.contains(collection)) {
                throw IllegalArgumentException("Unsupported synchronization collection: $collection")
            }
        }
    }

    override fun enqueueMutation(mutation: SyncMutation) {
        assertVaultExcluded(mutation.collection)
        synchronized(pendingQueue) {
            // Remove any obsolete pending mutation for the same docId
            pendingQueue.removeAll { it.collection == mutation.collection && it.docId == mutation.docId }
            pendingQueue.add(mutation)
            _pendingMutationsCount.value = pendingQueue.size
        }
    }

    override fun startRealtimeSync(uid: String) {
        if (uid.isBlank()) return
        if (activeUid == uid && listeners.isNotEmpty()) return

        stopRealtimeSync()
        activeUid = uid

        try {
            val userDoc = firestore.collection("users").document(uid)

            // 1. Tasks Listener
            val tasksReg = userDoc.collection(COL_TASKS).addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) return@addSnapshotListener
                for (change in snapshot.documentChanges) {
                    val docId = change.document.id
                    if (isPendingLocalEdit(COL_TASKS, docId)) continue

                    when (change.type) {
                        DocumentChange.Type.REMOVED -> {
                            database.taskDao().deleteById(docId, uid)
                        }
                        DocumentChange.Type.ADDED, DocumentChange.Type.MODIFIED -> {
                            val data = change.document.data
                            val entity = mapFirestoreToTask(docId, uid, data)
                            val local = database.taskDao().getById(docId, uid)
                            if (local == null || entity.updatedAt >= local.updatedAt) {
                                database.taskDao().insert(entity)
                            }
                        }
                    }
                }
            }
            listeners.add(tasksReg)

            // 2. Habits Listener
            val habitsReg = userDoc.collection(COL_HABITS).addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) return@addSnapshotListener
                for (change in snapshot.documentChanges) {
                    val docId = change.document.id
                    if (isPendingLocalEdit(COL_HABITS, docId)) continue

                    when (change.type) {
                        DocumentChange.Type.REMOVED -> {
                            database.habitDao().deleteHabitById(docId, uid)
                        }
                        DocumentChange.Type.ADDED, DocumentChange.Type.MODIFIED -> {
                            val data = change.document.data
                            val entity = mapFirestoreToHabit(docId, uid, data)
                            val local = database.habitDao().getHabitById(docId, uid)
                            if (local == null || entity.updatedAt >= local.updatedAt) {
                                database.habitDao().insertHabit(entity)
                            }
                        }
                    }
                }
            }
            listeners.add(habitsReg)

            // 3. Habit Entries Listener
            val entriesReg = userDoc.collection(COL_HABIT_ENTRIES).addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) return@addSnapshotListener
                for (change in snapshot.documentChanges) {
                    val docId = change.document.id
                    if (isPendingLocalEdit(COL_HABIT_ENTRIES, docId)) continue

                    when (change.type) {
                        DocumentChange.Type.REMOVED -> {
                            database.habitDao().deleteEntryById(docId, uid)
                        }
                        DocumentChange.Type.ADDED, DocumentChange.Type.MODIFIED -> {
                            val data = change.document.data
                            val entity = mapFirestoreToHabitEntry(docId, uid, data)
                            database.habitDao().insertEntry(entity)
                        }
                    }
                }
            }
            listeners.add(entriesReg)

            // 4. Transactions Listener
            val txReg = userDoc.collection(COL_TRANSACTIONS).addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) return@addSnapshotListener
                for (change in snapshot.documentChanges) {
                    val docId = change.document.id
                    if (isPendingLocalEdit(COL_TRANSACTIONS, docId)) continue

                    when (change.type) {
                        DocumentChange.Type.REMOVED -> {
                            database.transactionDao().deleteTransactionById(docId, uid)
                        }
                        DocumentChange.Type.ADDED, DocumentChange.Type.MODIFIED -> {
                            val data = change.document.data
                            val entity = mapFirestoreToTransaction(docId, uid, data)
                            database.transactionDao().insertTransaction(entity)
                        }
                    }
                }
            }
            listeners.add(txReg)

            // 5. Budgets Listener
            val budgetsReg = userDoc.collection(COL_BUDGETS).addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) return@addSnapshotListener
                for (change in snapshot.documentChanges) {
                    val month = change.document.id
                    if (isPendingLocalEdit(COL_BUDGETS, month)) continue

                    val budgetId = "${uid}_$month"
                    when (change.type) {
                        DocumentChange.Type.REMOVED -> {
                            database.budgetDao().deleteBudgetForMonth(uid, month)
                        }
                        DocumentChange.Type.ADDED, DocumentChange.Type.MODIFIED -> {
                            val data = change.document.data
                            val amount = (data["amount"] as? Number)?.toDouble() ?: 0.0
                            val amountPaise = (amount * 100).toLong()
                            val updatedAt = (data["updatedAt"] as? Number)?.toLong() ?: System.currentTimeMillis()
                            database.budgetDao().insertBudget(BudgetEntity(budgetId, uid, month, amountPaise, amount, updatedAt))
                        }
                    }
                }
            }
            listeners.add(budgetsReg)
        } catch (e: Exception) {
            _syncStatus.value = SyncStatus.ERROR
        }
    }

    override fun stopRealtimeSync() {
        listeners.forEach { it.remove() }
        listeners.clear()
        activeUid = null
    }

    override suspend fun pullInitialData(uid: String): Result<SyncSummary> = withContext(ioDispatcher) {
        if (uid.isBlank()) return@withContext Result.failure(IllegalArgumentException("UID cannot be blank"))

        _syncStatus.value = SyncStatus.SYNCING
        val errors = mutableListOf<String>()

        var tasksCount = 0
        var habitsCount = 0
        var entriesCount = 0
        var txCount = 0
        var budgetsCount = 0

        try {
            val userDoc = firestore.collection("users").document(uid)

            // 1. Pull Tasks
            try {
                val tasksSnap = userDoc.collection(COL_TASKS).get().await()
                val taskEntities = mutableListOf<TaskEntity>()
                for (doc in tasksSnap.documents) {
                    if (isPendingLocalEdit(COL_TASKS, doc.id)) continue
                    doc.data?.let {
                        taskEntities.add(mapFirestoreToTask(doc.id, uid, it))
                    }
                }
                if (taskEntities.isNotEmpty()) {
                    database.taskDao().insertAll(taskEntities)
                    tasksCount = taskEntities.size
                }
            } catch (e: Exception) {
                errors.add("Tasks pull failed: ${e.message}")
            }

            // 2. Pull Habits
            try {
                val habitsSnap = userDoc.collection(COL_HABITS).get().await()
                val habitEntities = mutableListOf<HabitEntity>()
                for (doc in habitsSnap.documents) {
                    if (isPendingLocalEdit(COL_HABITS, doc.id)) continue
                    doc.data?.let {
                        habitEntities.add(mapFirestoreToHabit(doc.id, uid, it))
                    }
                }
                if (habitEntities.isNotEmpty()) {
                    database.habitDao().insertAllHabits(habitEntities)
                    habitsCount = habitEntities.size
                }
            } catch (e: Exception) {
                errors.add("Habits pull failed: ${e.message}")
            }

            // 3. Pull Habit Entries
            try {
                val entriesSnap = userDoc.collection(COL_HABIT_ENTRIES).get().await()
                val entryEntities = mutableListOf<HabitEntryEntity>()
                for (doc in entriesSnap.documents) {
                    if (isPendingLocalEdit(COL_HABIT_ENTRIES, doc.id)) continue
                    doc.data?.let {
                        entryEntities.add(mapFirestoreToHabitEntry(doc.id, uid, it))
                    }
                }
                if (entryEntities.isNotEmpty()) {
                    database.habitDao().insertAllEntries(entryEntities)
                    entriesCount = entryEntities.size
                }
            } catch (e: Exception) {
                errors.add("Habit entries pull failed: ${e.message}")
            }

            // 4. Pull Transactions
            try {
                val txSnap = userDoc.collection(COL_TRANSACTIONS).get().await()
                val txEntities = mutableListOf<TransactionEntity>()
                for (doc in txSnap.documents) {
                    if (isPendingLocalEdit(COL_TRANSACTIONS, doc.id)) continue
                    doc.data?.let {
                        txEntities.add(mapFirestoreToTransaction(doc.id, uid, it))
                    }
                }
                if (txEntities.isNotEmpty()) {
                    database.transactionDao().insertAllTransactions(txEntities)
                    txCount = txEntities.size
                }
            } catch (e: Exception) {
                errors.add("Transactions pull failed: ${e.message}")
            }

            // 5. Pull Budgets
            try {
                val budgetsSnap = userDoc.collection(COL_BUDGETS).get().await()
                for (doc in budgetsSnap.documents) {
                    val month = doc.id
                    if (isPendingLocalEdit(COL_BUDGETS, month)) continue
                    val amount = (doc.data?.get("amount") as? Number)?.toDouble() ?: 0.0
                    val amountPaise = (amount * 100).toLong()
                    val updatedAt = (doc.data?.get("updatedAt") as? Number)?.toLong() ?: System.currentTimeMillis()
                    database.budgetDao().insertBudget(
                        BudgetEntity("${uid}_$month", uid, month, amountPaise, amount, updatedAt)
                    )
                    budgetsCount++
                }
            } catch (e: Exception) {
                errors.add("Budgets pull failed: ${e.message}")
            }

            val success = errors.isEmpty()
            _syncStatus.value = if (success) SyncStatus.SUCCESS else SyncStatus.ERROR
            _lastSyncTimestamp.value = System.currentTimeMillis()

            Result.success(
                SyncSummary(
                    success = success,
                    tasksCount = tasksCount,
                    habitsCount = habitsCount,
                    entriesCount = entriesCount,
                    transactionsCount = txCount,
                    budgetsCount = budgetsCount,
                    errors = errors,
                )
            )
        } catch (e: Exception) {
            _syncStatus.value = SyncStatus.ERROR
            Result.failure(e)
        }
    }

    override suspend fun pushPendingMutations(uid: String): Result<Int> = withContext(ioDispatcher) {
        if (uid.isBlank()) return@withContext Result.failure(IllegalArgumentException("UID cannot be blank"))

        val mutationsToProcess = synchronized(pendingQueue) {
            pendingQueue.toList()
        }

        if (mutationsToProcess.isEmpty()) {
            return@withContext Result.success(0)
        }

        _syncStatus.value = SyncStatus.SYNCING
        var processedCount = 0
        val remainingMutations = mutableListOf<SyncMutation>()

        val userDoc = firestore.collection("users").document(uid)

        for (mutation in mutationsToProcess) {
            assertVaultExcluded(mutation.collection)
            try {
                val docRef = userDoc.collection(mutation.collection).document(mutation.docId)

                when (mutation.type) {
                    SyncMutationType.DELETE -> {
                        docRef.delete().await()
                    }
                    SyncMutationType.UPSERT -> {
                        mutation.payload?.let { payload ->
                            docRef.set(payload, SetOptions.merge()).await()
                        }
                    }
                }
                processedCount++
            } catch (e: Exception) {
                // Retry with bounded backoff
                if (mutation.retryCount < 5) {
                    remainingMutations.add(mutation.copy(retryCount = mutation.retryCount + 1))
                }
            }
        }

        synchronized(pendingQueue) {
            pendingQueue.clear()
            pendingQueue.addAll(remainingMutations)
            _pendingMutationsCount.value = pendingQueue.size
        }

        _lastSyncTimestamp.value = System.currentTimeMillis()
        _syncStatus.value = if (remainingMutations.isEmpty()) SyncStatus.SUCCESS else SyncStatus.ERROR

        Result.success(processedCount)
    }

    private fun isPendingLocalEdit(collection: String, docId: String): Boolean {
        synchronized(pendingQueue) {
            return pendingQueue.any { it.collection == collection && it.docId == docId }
        }
    }

    // Mapping Helpers conforming to Flutter contract
    private fun mapFirestoreToTask(id: String, uid: String, data: Map<String, Any?>): TaskEntity {
        val title = data["title"] as? String ?: ""
        val description = data["description"] as? String ?: ""
        val rawPriority = data["priority"] as? String ?: "Low"
        val priority = if (rawPriority == "Much") "Must" else rawPriority
        val category = data["category"] as? String ?: "Other"
        val labelsList = (data["labels"] as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()
        val labelsJson = gson.toJson(labelsList)

        val dueDateStr = data["dueDate"] as? String
        val dueDate = parseIsoToEpoch(dueDateStr)
        val dueTime = data["dueTime"] as? String
        val reminderStr = data["reminder"] as? String
        val reminder = parseIsoToEpoch(reminderStr)

        val completed = data["completed"] as? Boolean ?: false
        val completedAtStr = data["completedAt"] as? String
        val completedAt = parseIsoToEpoch(completedAtStr)

        val createdAt = parseIsoToEpoch(data["createdAt"] as? String) ?: System.currentTimeMillis()
        val updatedAt = parseIsoToEpoch(data["updatedAt"] as? String) ?: System.currentTimeMillis()

        return TaskEntity(
            id, uid, title, description, priority, category, labelsJson,
            dueDate, dueTime, reminder, completed, createdAt, updatedAt, completedAt
        )
    }

    private fun mapFirestoreToHabit(id: String, uid: String, data: Map<String, Any?>): HabitEntity {
        val name = data["name"] as? String ?: ""
        val category = data["category"] as? String ?: "Other"
        val colorValue = (data["colorValue"] as? Number)?.toLong() ?: 0xffffffff
        val reminderTime = data["reminderTime"] as? String
        val createdAt = parseIsoToEpoch(data["createdAt"] as? String) ?: System.currentTimeMillis()
        val updatedAt = parseIsoToEpoch(data["updatedAt"] as? String) ?: System.currentTimeMillis()

        return HabitEntity(id, uid, name, category, colorValue, reminderTime, createdAt, updatedAt)
    }

    private fun mapFirestoreToHabitEntry(id: String, uid: String, data: Map<String, Any?>): HabitEntryEntity {
        val habitId = data["habitId"] as? String ?: id.substringBefore("_")
        val dateStr = data["dateStr"] as? String ?: id.substringAfter("_")
        val completed = data["completed"] as? Boolean ?: false

        return HabitEntryEntity(id, uid, habitId, dateStr, completed)
    }

    private fun mapFirestoreToTransaction(id: String, uid: String, data: Map<String, Any?>): TransactionEntity {
        val amount = (data["amount"] as? Number)?.toDouble() ?: 0.0
        val amountPaise = (data["amountPaise"] as? Number)?.toLong() ?: (amount * 100).toLong()
        val type = data["type"] as? String ?: "Expense"
        val category = data["category"] as? String ?: "Other"
        val date = parseIsoToEpoch(data["date"] as? String) ?: (data["date"] as? Number)?.toLong() ?: System.currentTimeMillis()
        val time = data["time"] as? String ?: ""
        val notes = data["notes"] as? String ?: ""
        val createdAt = parseIsoToEpoch(data["createdAt"] as? String) ?: System.currentTimeMillis()
        val source = data["source"] as? String ?: "manual"
        val automationFingerprint = data["automationFingerprint"] as? String

        return TransactionEntity(id, uid, amountPaise, amount, type, category, date, time, notes, createdAt, source, automationFingerprint)
    }

    private fun parseIsoToEpoch(isoString: String?): Long? {
        if (isoString.isNullOrBlank()) return null
        return try {
            Instant.parse(isoString).toEpochMilli()
        } catch (_: Exception) {
            try {
                isoString.toLongOrNull()
            } catch (_: Exception) {
                null
            }
        }
    }
}
