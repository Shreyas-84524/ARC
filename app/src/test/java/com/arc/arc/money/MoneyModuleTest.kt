package com.arc.arc.money

import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.model.BudgetModel
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.features.money.ui.MoneyViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.text.SimpleDateFormat
import java.time.YearMonth
import java.util.Date
import java.util.Locale
import java.util.TimeZone

@OptIn(ExperimentalCoroutinesApi::class)
class MoneyModuleTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var transactionRepository: InMemoryTransactionRepository
    private lateinit var authRepository: DevFakeAuthRepository
    private lateinit var viewModel: MoneyViewModel

    private val currentMonth = YearMonth.now().toString()
    private val testUid = DevFakeAuthRepository.DEFAULT_DEV_USER.uid
    private val sdf = SimpleDateFormat("yyyy-MM", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        transactionRepository = InMemoryTransactionRepository()
        authRepository = DevFakeAuthRepository()

        viewModel = MoneyViewModel(transactionRepository, authRepository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun initialState_hasCurrentMonthAndEmptyTotals() = runTest {
        val state = viewModel.uiState.value
        assertEquals(currentMonth, state.selectedMonth)
        assertEquals(0L, state.monthlyBudgetPaise)
        assertEquals(0L, state.totalIncomePaise)
        assertEquals(0L, state.totalExpensesPaise)
        assertEquals(0L, state.remainingBudgetPaise)
        assertEquals(0, state.transactions.size)
        assertFalse(state.hasBudget)
    }

    @Test
    fun transactionsFlowUpdate_calculatesFinancialTotalsAccurately() = runTest {
        val now = Date()
        val currentUid = testUid

        // Save Income ₹50,000.00
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "inc-1",
                ownerUid = currentUid,
                amountPaise = 5000000L,
                type = "Income",
                category = "Salary",
                date = now,
            )
        )

        // Save Expense ₹12,500.50
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "exp-1",
                ownerUid = currentUid,
                amountPaise = 1250050L,
                type = "Expense",
                category = "Rent",
                date = now,
            )
        )

        // Save Expense ₹3,499.50
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "exp-2",
                ownerUid = currentUid,
                amountPaise = 349950L,
                type = "Expense",
                category = "Food",
                date = now,
            )
        )

        // Set Budget ₹30,000.00
        transactionRepository.saveBudget(
            BudgetModel.fromPaise(
                month = currentMonth,
                ownerUid = currentUid,
                amountPaise = 3000000L,
            )
        )

        advanceUntilIdle()

        val state = viewModel.uiState.first { it.transactions.isNotEmpty() }
        assertEquals(3, state.transactions.size)
        assertEquals(5000000L, state.totalIncomePaise)
        assertEquals(1600000L, state.totalExpensesPaise) // 1250050 + 349950 = 1600000 (₹16,000.00)
        assertEquals(3000000L, state.monthlyBudgetPaise)
        assertEquals(1400000L, state.remainingBudgetPaise) // 3000000 - 1600000 = 1400000 (₹14,000.00)
        assertEquals(3400000L, state.savingsPaise)        // 5000000 - 1600000 = 3400000 (₹34,000.00)
        assertTrue(state.hasBudget)
        assertFalse(state.isBudgetExceeded)
    }

    @Test
    fun filterType_filtersExpensesAndIncomeCorrectly() = runTest {
        val now = Date()
        val currentUid = testUid

        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "inc-1",
                ownerUid = currentUid,
                amountPaise = 100000L,
                type = "Income",
                date = now,
            )
        )
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "exp-1",
                ownerUid = currentUid,
                amountPaise = 50000L,
                type = "Expense",
                date = now,
            )
        )

        advanceUntilIdle()

        // Filter by Expense
        viewModel.setFilterType("Expense")
        advanceUntilIdle()
        var state = viewModel.uiState.value
        assertEquals(1, state.filteredTransactions.size)
        assertEquals("exp-1", state.filteredTransactions.first().id)

        // Filter by Income
        viewModel.setFilterType("Income")
        advanceUntilIdle()
        state = viewModel.uiState.value
        assertEquals(1, state.filteredTransactions.size)
        assertEquals("inc-1", state.filteredTransactions.first().id)

        // Filter All
        viewModel.setFilterType("All")
        advanceUntilIdle()
        state = viewModel.uiState.value
        assertEquals(2, state.filteredTransactions.size)
    }

    @Test
    fun searchQuery_filtersByNotesOrCategory() = runTest {
        val now = Date()
        val currentUid = testUid

        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-coffee",
                ownerUid = currentUid,
                amountPaise = 25000L,
                type = "Expense",
                category = "Food",
                notes = "Starbucks latte",
                date = now,
            )
        )
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-uber",
                ownerUid = currentUid,
                amountPaise = 45000L,
                type = "Expense",
                category = "Travel",
                notes = "Airport ride",
                date = now,
            )
        )

        advanceUntilIdle()

        viewModel.setSearchQuery("latte")
        advanceUntilIdle()
        var state = viewModel.uiState.value
        assertEquals(1, state.filteredTransactions.size)
        assertEquals("tx-coffee", state.filteredTransactions.first().id)

        viewModel.setSearchQuery("travel")
        advanceUntilIdle()
        state = viewModel.uiState.value
        assertEquals(1, state.filteredTransactions.size)
        assertEquals("tx-uber", state.filteredTransactions.first().id)
    }

    @Test
    fun budgetExceeded_flagsCorrectly() = runTest {
        val now = Date()
        val currentUid = testUid

        // Budget ₹10,000
        transactionRepository.saveBudget(
            BudgetModel.fromPaise(
                month = currentMonth,
                ownerUid = currentUid,
                amountPaise = 1000000L,
            )
        )

        // Expense ₹15,000
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "exp-big",
                ownerUid = currentUid,
                amountPaise = 1500000L,
                type = "Expense",
                date = now,
            )
        )

        advanceUntilIdle()

        val state = viewModel.uiState.first { it.transactions.isNotEmpty() }
        assertEquals(-500000L, state.remainingBudgetPaise)
        assertTrue(state.isBudgetExceeded)
    }

    @Test
    fun monthNavigation_changesSelectedMonth() = runTest {
        val originalMonth = viewModel.uiState.value.selectedMonth
        val ym = YearMonth.parse(originalMonth)

        viewModel.previousMonth()
        advanceUntilIdle()
        assertEquals(ym.minusMonths(1).toString(), viewModel.uiState.value.selectedMonth)

        viewModel.nextMonth()
        advanceUntilIdle()
        assertEquals(originalMonth, viewModel.uiState.value.selectedMonth)
    }

    @Test
    fun saveAndDeleteTransaction_delegatesToRepository() = runTest {
        val newTx = TransactionModel.fromPaise(
            id = "tx-new",
            amountPaise = 12000L,
            type = "Expense",
            category = "Snacks",
            date = Date(),
        )

        viewModel.saveTransaction(newTx)
        advanceUntilIdle()

        val saved = transactionRepository.getTransactionById("tx-new", testUid)
        assertNotNull(saved)
        assertEquals(12000L, saved?.amountPaise)

        viewModel.deleteTransaction("tx-new")
        advanceUntilIdle()

        val deleted = transactionRepository.getTransactionById("tx-new", testUid)
        assertNull(deleted)
    }

    @Test
    fun setMonthlyBudget_updatesRepository() = runTest {
        viewModel.setMonthlyBudget(4500000L) // ₹45,000.00
        advanceUntilIdle()

        val savedBudget = transactionRepository.getBudget(testUid, currentMonth)
        assertNotNull(savedBudget)
        assertEquals(4500000L, savedBudget?.amountPaise)
    }

    @Test
    fun userIsolation_onlyCurrentUserDataObserved() = runTest {
        val now = Date()

        // Shreyas transaction
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-shreyas",
                ownerUid = testUid,
                amountPaise = 10000L,
                type = "Expense",
                date = now,
            )
        )

        // Aman transaction
        transactionRepository.saveTransaction(
            TransactionModel.fromPaise(
                id = "tx-aman",
                ownerUid = "dev_uid_aman",
                amountPaise = 99000L,
                type = "Expense",
                date = now,
            )
        )

        advanceUntilIdle()

        val state = viewModel.uiState.first { it.transactions.isNotEmpty() }
        assertEquals(1, state.transactions.size)
        assertEquals("tx-shreyas", state.transactions.first().id)
    }
}
