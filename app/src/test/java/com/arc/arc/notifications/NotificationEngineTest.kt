package com.arc.arc.notifications

import com.arc.arc.core.datastore.AppPreferences
import com.arc.arc.core.model.HabitEntryModel
import com.arc.arc.core.model.HabitModel
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.notifications.ArcNotificationChannels
import com.arc.arc.core.notifications.ArcNotificationManager
import com.arc.arc.core.notifications.IAlarmScheduler
import com.arc.arc.core.notifications.IArcNotificationManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class NotificationEngineTest {

    private lateinit var fakeScheduler: FakeAlarmScheduler
    private lateinit var notificationManager: ArcNotificationManager

    data class ScheduledItem(
        val notificationId: Int,
        val triggerAtMillis: Long,
        val title: String,
        val message: String,
        val channelId: String,
        val destination: String,
        val entityId: String,
    )

    class FakeAlarmScheduler : IAlarmScheduler {
        val scheduledAlarms = mutableMapOf<Int, ScheduledItem>()
        val cancelledAlarms = mutableListOf<Int>()
        var cancelAllCalled = false

        override fun schedule(
            notificationId: Int,
            triggerAtMillis: Long,
            title: String,
            message: String,
            channelId: String,
            destination: String,
            entityId: String,
        ) {
            scheduledAlarms[notificationId] = ScheduledItem(
                notificationId = notificationId,
                triggerAtMillis = triggerAtMillis,
                title = title,
                message = message,
                channelId = channelId,
                destination = destination,
                entityId = entityId,
            )
        }

        override fun cancel(notificationId: Int) {
            cancelledAlarms.add(notificationId)
            scheduledAlarms.remove(notificationId)
        }

        override fun cancelAll() {
            cancelAllCalled = true
            scheduledAlarms.clear()
        }
    }

    @Before
    fun setup() {
        fakeScheduler = FakeAlarmScheduler()
        notificationManager = ArcNotificationManager(fakeScheduler)
    }

    @Test
    fun `channel constants match specification and legacy compatibility`() {
        assertEquals("arc_tasks_channel", ArcNotificationChannels.CHANNEL_TASKS)
        assertEquals("arc_habits_channel", ArcNotificationChannels.CHANNEL_HABITS)
        assertEquals("arc_money_channel", ArcNotificationChannels.CHANNEL_MONEY)
        assertEquals("arc_reminders_channel", ArcNotificationChannels.CHANNEL_REMINDERS_LEGACY)
        assertEquals("arc_money_reminder_channel", ArcNotificationChannels.CHANNEL_MONEY_LEGACY)
    }

    @Test
    fun `stable hash produces deterministic positive 31-bit integers`() {
        val testStrings = listOf("task_123", "habit_abc", "task_dead_xyz", "random_string_!", "")
        for (str in testStrings) {
            val hash1 = ArcNotificationManager.getStableHash(str)
            val hash2 = ArcNotificationManager.getStableHash(str)
            assertEquals(hash1, hash2)
            assertTrue("Hash should be non-negative: $hash1", hash1 >= 0)
            assertTrue("Hash must fit within 31-bit integer: $hash1", hash1 <= Int.MAX_VALUE)
        }
    }

    @Test
    fun `disjoint ID namespaces guarantee zero collisions across entities`() {
        val sampleIds = (1..500).map { "entity_$it" }

        val taskPreIds = sampleIds.map { ArcNotificationManager.getTaskNotificationId5m(it) }
        val taskDeadIds = sampleIds.map { ArcNotificationManager.getTaskNotificationIdDeadline(it) }
        val habitDeadIds = sampleIds.map { ArcNotificationManager.getHabitNotificationIdDeadline(it) }
        val habitRemIds = sampleIds.map { ArcNotificationManager.getHabitNotificationIdRemTime(it) }

        // Range checks
        taskPreIds.forEach { id ->
            assertTrue("Task 5m ID $id must be in [10_000_000, 399_999_999]", id in 10000000..399999999)
        }
        taskDeadIds.forEach { id ->
            assertTrue("Task Deadline ID $id must be in [400_000_000, 799_999_999]", id in 400000000..799999999)
        }
        habitDeadIds.forEach { id ->
            assertTrue("Habit Deadline ID $id must be in [800_000_000, 1_099_999_999]", id in 800000000..1099999999)
        }
        habitRemIds.forEach { id ->
            assertTrue("Habit rem_time ID $id must be in [1_100_000_000, 1_399_999_999]", id in 1100000000..1399999999)
        }

        // Mutual exclusion checks
        val allIds = taskPreIds + taskDeadIds + habitDeadIds + habitRemIds +
                listOf(ArcNotificationManager.MONEY_REMINDER_ID, ArcNotificationManager.EVENING_HABIT_REMINDER_ID)

        val uniqueIds = allIds.toSet()
        assertEquals("All namespace IDs must be completely disjoint and collision-free", allIds.size, uniqueIds.size)
    }

    @Test
    fun `reconciliation respects master and module preference toggles`() {
        val ownerUid = "dev_user_001"
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

        val futureCal = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 18)
            set(Calendar.MINUTE, 0)
        }

        val tasks = listOf(
            TaskModel(id = "t1", ownerUid = ownerUid, title = "Task 1", dueDate = futureCal.time, dueTime = "18:00")
        )
        val habits = listOf(
            HabitModel(id = "h1", ownerUid = ownerUid, name = "Habit 1", reminderTime = "19:00")
        )
        val entries = listOf(
            HabitEntryModel(habitId = "h1", dateStr = todayStr, completed = false, ownerUid = ownerUid)
        )

        // 1. Reconcile with all enabled
        val allEnabledPrefs = AppPreferences(
            masterNotificationsEnabled = true,
            taskRemindersEnabled = true,
            habitRemindersEnabled = true,
            expenseRemindersEnabled = true
        )
        notificationManager.reconcile(ownerUid, allEnabledPrefs, tasks, habits, entries)
        assertTrue(fakeScheduler.scheduledAlarms.isNotEmpty())

        // 2. Reconcile with master disabled
        val masterDisabledPrefs = AppPreferences(
            masterNotificationsEnabled = false
        )
        notificationManager.reconcile(ownerUid, masterDisabledPrefs, tasks, habits, entries)
        assertTrue(fakeScheduler.cancelAllCalled)
        assertTrue(fakeScheduler.scheduledAlarms.isEmpty())

        // 3. Reconcile with tasks disabled
        fakeScheduler.cancelAllCalled = false
        val tasksDisabledPrefs = AppPreferences(
            masterNotificationsEnabled = true,
            taskRemindersEnabled = false,
            habitRemindersEnabled = true,
            expenseRemindersEnabled = true
        )
        notificationManager.reconcile(ownerUid, tasksDisabledPrefs, tasks, habits, entries)

        // Verify task alarms were cancelled
        val t1DeadId = ArcNotificationManager.getTaskNotificationIdDeadline("t1")
        assertFalse(fakeScheduler.scheduledAlarms.containsKey(t1DeadId))
    }

    @Test
    fun `vault privacy invariant - notification manager API strictly excludes vault methods`() {
        val methods = IArcNotificationManager::class.java.methods
        for (m in methods) {
            val name = m.name.lowercase()
            assertFalse("Notification manager must not have note/vault methods: $name", name.contains("note"))
            assertFalse("Notification manager must not have secret methods: $name", name.contains("secret"))
            assertFalse("Notification manager must not have vault methods: $name", name.contains("vault"))
        }
    }
}
