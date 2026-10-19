package com.arc.arc.integration

import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.model.BudgetModel
import com.arc.arc.core.model.HabitModel
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.features.dashboard.DashboardActivityType
import com.arc.arc.features.dashboard.DashboardViewModel
import com.arc.arc.habits.InMemoryHabitRepository
import com.arc.arc.money.InMemoryTransactionRepository
import com.arc.arc.tasks.InMemoryTaskRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.util.Calendar
import java.util.Date

/**
 * End-to-end integration test suite verifying the reactive integration
 * between Tasks, Habits, Money Manager, and the native ARC Dashboard.
 *
 * Verifies unified cross-module aggregation, multi-user isolation,
 * budget alerts, and recent activity chronological ordering.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class OfflineFinancialIntegrationTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var taskRepository: InMemoryTaskRepository
    private lateinit var habitRepository: InMemoryHabitRepository
    private lateinit var transactionRepository: InMemoryTransactionRepository
    private lateinit var authRepository: DevFakeAuthRepository

    private val currentMonthStr = YearMonth.now().toString()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        taskRepository = InMemoryTaskRepository()
        habitRepository = InMemoryHabitRepository()
        transactionRepository = InMemoryTransactionRepository()
        authRepository = DevFakeAuthRepository()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun getTodayDate(): Date {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time
    }

    @Test
    fun crossModule_whenFinancialDataPresent_dashboardAggregatesExpensesAndBudgetAccurately() = runTest(testDispatcher) {
        val user = authRepository.currentUserSession!!
        val today = getTodayDate()

        // 1. Setup a monthly budget of ₹25,000.00 (2,500,000 paise)
        transactionRepository.saveBudget(
            BudgetModel.fromPaise(
                ownerUid = user.uid,
                month = currentMonthStr,
                amountPaise = 2500000L,
            )
        )

        // 2. Add an Expense of ₹4,500.00 (450,000 paise)
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-groceries",
                ownerUid = user.uid,
                amountPaise = 450000L,
                type = "Expense",
                category = "Groceries",
                date = today,
                notes = "Weekly grocery shopping",
            )
        )

        // 3. Add an Expense of ₹1,200.50 (120,050 paise)
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-dining",
                ownerUid = user.uid,
                amountPaise = 120050L,
                type = "Expense",
                category = "Dining",
                date = today,
                notes = "Lunch with team",
            )
        )

        // 4. Add an Income of ₹60,000.00 (should not be counted in monthly expenses)
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-salary",
                ownerUid = user.uid,
                amountPaise = 6000000L,
                type = "Income",
                category = "Salary",
                date = today,
            )
        )

        val dashboardViewModel = DashboardViewModel(
            taskRepository = taskRepository,
            habitRepository = habitRepository,
            authRepository = authRepository,
            transactionRepository = transactionRepository,
        )
        advanceUntilIdle()

        val state = dashboardViewModel.uiState.value
        assertEquals(2500000L, state.monthlyBudgetPaise)
        assertEquals(570050L, state.monthlyExpensesPaise)
        assertEquals(1929950L, state.remainingBudgetPaise)

        // Verify transaction items appear in recent activities
        val txActivities = state.recentActivities.filter { it.type == DashboardActivityType.TRANSACTION }
        assertEquals(3, txActivities.size)
    }

    @Test
    fun crossModule_whenOverBudget_dashboardCalculatesNegativeRemainingBudget() = runTest(testDispatcher) {
        val user = authRepository.currentUserSession!!
        val today = getTodayDate()

        // Budget ₹10,000.00 (1,000,000 paise)
        transactionRepository.saveBudget(
            BudgetModel.fromPaise(
                ownerUid = user.uid,
                month = currentMonthStr,
                amountPaise = 1000000L,
            )
        )

        // Expense ₹15,000.00 (1,500,000 paise)
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-laptop",
                ownerUid = user.uid,
                amountPaise = 1500000L,
                type = "Expense",
                category = "Electronics",
                date = today,
            )
        )

        val dashboardViewModel = DashboardViewModel(
            taskRepository = taskRepository,
            habitRepository = habitRepository,
            authRepository = authRepository,
            transactionRepository = transactionRepository,
        )
        advanceUntilIdle()

        val state = dashboardViewModel.uiState.value
        assertEquals(1000000L, state.monthlyBudgetPaise)
        assertEquals(1500000L, state.monthlyExpensesPaise)
        assertEquals(-500000L, state.remainingBudgetPaise)
    }

    @Test
    fun crossModule_activityFeedCombinesTasksHabitsAndTransactionsInChronologicalOrder() = runTest(testDispatcher) {
        val user = authRepository.currentUserSession!!
        val cal = Calendar.getInstance()

        // 1. Task created at t=1000
        cal.set(2026, Calendar.OCTOBER, 18, 10, 0, 0)
        val taskDate = cal.time
        taskRepository.saveTask(
            TaskModel(
                id = "task-alpha",
                ownerUid = user.uid,
                title = "Review PR",
                category = "Work",
                dueDate = taskDate,
                updatedAt = taskDate,
            )
        )

        // 2. Transaction at t=1100
        cal.set(2026, Calendar.OCTOBER, 18, 11, 0, 0)
        val txDate = cal.time
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-coffee",
                ownerUid = user.uid,
                amountPaise = 25000L,
                type = "Expense",
                category = "Food",
                date = txDate,
            )
        )

        // 3. Habit checked-in at t=1200
        cal.set(2026, Calendar.OCTOBER, 18, 12, 0, 0)
        val habitDate = cal.time
        habitRepository.saveHabit(
            HabitModel(
                id = "habit-workout",
                ownerUid = user.uid,
                name = "Morning Workout",
                category = "Health",
                updatedAt = habitDate,
            )
        )
        val todayStr = "2026-10-18"
        habitRepository.toggleHabitCompletion("habit-workout", todayStr, true, user.uid)

        val dashboardViewModel = DashboardViewModel(
            taskRepository = taskRepository,
            habitRepository = habitRepository,
            authRepository = authRepository,
            transactionRepository = transactionRepository,
        )
        advanceUntilIdle()

        val activities = dashboardViewModel.uiState.value.recentActivities
        assertTrue(activities.isNotEmpty())

        // Verify transaction activity details
        val txActivity = activities.find { it.type == DashboardActivityType.TRANSACTION }
        assertNotNull(txActivity)
        assertEquals("Food", txActivity?.title)
        assertTrue(txActivity?.subtitle?.contains("₹250.00") == true)

        // Verify sorted descending by timestamp
        for (i in 0 until activities.size - 1) {
            assertTrue(activities[i].timestamp.time >= activities[i + 1].timestamp.time)
        }
    }

    @Test
    fun multiUserIsolation_financesRemainStrictlyIsolatedAcrossUsers() = runTest(testDispatcher) {
        val userShreyas = DevFakeAuthRepository.DEFAULT_DEV_USER
        val userAman = DevFakeAuthRepository.PRESET_DEV_USERS[1]
        val today = getTodayDate()

        // Shreyas data: Budget ₹50,000, Expense ₹20,000
        transactionRepository.saveBudget(
            BudgetModel.fromPaise(
                ownerUid = userShreyas.uid,
                month = currentMonthStr,
                amountPaise = 5000000L,
            )
        )
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-shreyas-rent",
                ownerUid = userShreyas.uid,
                amountPaise = 2000000L,
                type = "Expense",
                category = "Rent",
                date = today,
            )
        )

        // Aman data: Budget ₹10,000, Expense ₹3,000
        transactionRepository.saveBudget(
            BudgetModel.fromPaise(
                ownerUid = userAman.uid,
                month = currentMonthStr,
                amountPaise = 1000000L,
            )
        )
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-aman-books",
                ownerUid = userAman.uid,
                amountPaise = 300000L,
                type = "Expense",
                category = "Education",
                date = today,
            )
        )

        val dashboardViewModel = DashboardViewModel(
            taskRepository = taskRepository,
            habitRepository = habitRepository,
            authRepository = authRepository,
            transactionRepository = transactionRepository,
        )
        advanceUntilIdle()

        // 1. Shreyas is currently logged in
        var state = dashboardViewModel.uiState.value
        assertEquals(5000000L, state.monthlyBudgetPaise)
        assertEquals(2000000L, state.monthlyExpensesPaise)
        assertEquals(3000000L, state.remainingBudgetPaise)
        assertEquals(1, state.recentActivities.filter { it.type == DashboardActivityType.TRANSACTION }.size)

        // 2. Switch user to Aman
        authRepository.switchUser(userAman)
        advanceUntilIdle()

        state = dashboardViewModel.uiState.value
        assertEquals(1000000L, state.monthlyBudgetPaise)
        assertEquals(300000L, state.monthlyExpensesPaise)
        assertEquals(700000L, state.remainingBudgetPaise)
        val amanTxActivities = state.recentActivities.filter { it.type == DashboardActivityType.TRANSACTION }
        assertEquals(1, amanTxActivities.size)
        assertEquals("Education", amanTxActivities.first().title)
    }

    @Test
    fun transactionDeletion_immediatelyUpdatesDashboardTotals() = runTest(testDispatcher) {
        val user = authRepository.currentUserSession!!
        val today = getTodayDate()

        transactionRepository.saveBudget(
            BudgetModel.fromPaise(
                ownerUid = user.uid,
                month = currentMonthStr,
                amountPaise = 1000000L,
            )
        )
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-temporary",
                ownerUid = user.uid,
                amountPaise = 250000L,
                type = "Expense",
                category = "Travel",
                date = today,
            )
        )

        val dashboardViewModel = DashboardViewModel(
            taskRepository = taskRepository,
            habitRepository = habitRepository,
            authRepository = authRepository,
            transactionRepository = transactionRepository,
        )
        advanceUntilIdle()

        assertEquals(250000L, dashboardViewModel.uiState.value.monthlyExpensesPaise)

        // Delete the transaction
        transactionRepository.deleteTransaction("tx-temporary", user.uid)
        advanceUntilIdle()

        assertEquals(0L, dashboardViewModel.uiState.value.monthlyExpensesPaise)
        assertEquals(1000000L, dashboardViewModel.uiState.value.remainingBudgetPaise)
        assertTrue(dashboardViewModel.uiState.value.recentActivities.none { it.id == "tx-temporary" })
    }
}
