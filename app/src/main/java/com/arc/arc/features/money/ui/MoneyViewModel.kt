package com.arc.arc.features.money.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.arc.arc.core.auth.AuthState
import com.arc.arc.core.auth.IAuthRepository
import com.arc.arc.core.model.BudgetModel
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.features.money.analytics.FinancialAnalyticsEngine
import com.arc.arc.features.money.data.ITransactionRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.time.YearMonth
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

@OptIn(ExperimentalCoroutinesApi::class)
class MoneyViewModel(
    private val transactionRepository: ITransactionRepository,
    private val authRepository: IAuthRepository,
) : ViewModel() {

    private val currentMonthStr = YearMonth.now().toString()

    private val _selectedMonth = MutableStateFlow(currentMonthStr)
    private val _selectedTab = MutableStateFlow(0)
    private val _filterType = MutableStateFlow("All") // "All", "Expense", "Income"
    private val _filterCategory = MutableStateFlow("All")
    private val _searchQuery = MutableStateFlow("")
    private val _userMessage = MutableStateFlow<String?>(null)
    private val _isAutomationPromptDismissed = MutableStateFlow(false)

    private val monthFormat = SimpleDateFormat("yyyy-MM", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    private val activeUserUid = authRepository.authState.flatMapLatest { state ->
        when (state) {
            is AuthState.Authenticated -> flowOf(state.user.uid)
            else -> flowOf("")
        }
    }

    private val transactionsFlow = activeUserUid.flatMapLatest { uid ->
        if (uid.isBlank()) flowOf(emptyList()) else transactionRepository.getTransactionsFlow(uid)
    }

    private val budgetFlow = combine(activeUserUid, _selectedMonth) { uid, month ->
        Pair(uid, month)
    }.flatMapLatest { (uid, month) ->
        if (uid.isBlank()) flowOf(null) else transactionRepository.getBudgetFlow(uid, month)
    }

    val uiState: StateFlow<MoneyUiState> = combine(
        transactionsFlow,
        budgetFlow,
        _selectedMonth,
        _selectedTab,
        _filterType,
        _filterCategory,
        _searchQuery,
        _userMessage,
        _isAutomationPromptDismissed,
    ) { params ->
        @Suppress("UNCHECKED_CAST")
        val allTx = params[0] as List<TransactionModel>
        val budget = params[1] as? BudgetModel
        val month = params[2] as String
        val tab = params[3] as Int
        val fType = params[4] as String
        val fCat = params[5] as String
        val query = params[6] as String
        val message = params[7] as? String
        val promptDismissed = params[8] as Boolean

        // Filter transactions for selectedMonth
        val monthTx = allTx.filter { tx ->
            val txMonth = monthFormat.format(tx.date)
            txMonth == month
        }.sortedByDescending { it.date.time }

        // Compute integer paise arithmetic
        val incomePaise = monthTx.filter { it.isIncome }.sumOf { it.amountPaise }
        val expensesPaise = monthTx.filter { it.isExpense }.sumOf { it.amountPaise }
        val budgetPaise = budget?.amountPaise ?: 0L
        val remainingPaise = budgetPaise - expensesPaise
        val savingsPaise = incomePaise - expensesPaise
        val savingsRate = if (incomePaise > 0L) {
            (savingsPaise.toDouble() / incomePaise.toDouble()).coerceIn(0.0, 1.0)
        } else {
            0.0
        }

        // Category breakdown for expenses
        val catBreakdown = monthTx.filter { it.isExpense }
            .groupBy { it.category }
            .mapValues { (_, txs) -> txs.sumOf { it.amountPaise } }

        // Daily spending breakdown
        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        val dailyMap = monthTx.filter { it.isExpense }
            .groupBy { tx ->
                cal.time = tx.date
                cal.get(Calendar.DAY_OF_MONTH)
            }
            .mapValues { (_, txs) -> txs.sumOf { it.amountPaise } }

        // Apply filters & search query
        val filtered = monthTx.filter { tx ->
            val matchesType = when (fType) {
                "Expense" -> tx.isExpense
                "Income" -> tx.isIncome
                else -> true
            }
            val matchesCat = if (fCat == "All") true else tx.category.equals(fCat, ignoreCase = true)
            val matchesQuery = if (query.isBlank()) true else {
                tx.notes.contains(query, ignoreCase = true) ||
                        tx.category.contains(query, ignoreCase = true)
            }
            matchesType && matchesCat && matchesQuery
        }

        val showPrompt = budgetPaise > 0L && !promptDismissed

        val prevMonth = try {
            YearMonth.parse(month).minusMonths(1).toString()
        } catch (_: Exception) {
            ""
        }
        val prevMonthTx = if (prevMonth.isNotBlank()) {
            allTx.filter { tx -> monthFormat.format(tx.date) == prevMonth }
        } else {
            null
        }

        val report = FinancialAnalyticsEngine.generateReport(
            month = month,
            currentMonthTransactions = monthTx,
            currentBudget = budget,
            previousMonthTransactions = prevMonthTx,
        )

        MoneyUiState(
            selectedMonth = month,
            selectedTab = tab,
            monthlyBudget = budget,
            monthlyBudgetPaise = budgetPaise,
            totalIncomePaise = incomePaise,
            totalExpensesPaise = expensesPaise,
            remainingBudgetPaise = remainingPaise,
            savingsPaise = savingsPaise,
            savingsRate = savingsRate,
            transactions = monthTx,
            filteredTransactions = filtered,
            filterType = fType,
            filterCategory = fCat,
            searchQuery = query,
            categoryExpenses = catBreakdown,
            dailySpending = dailyMap,
            analyticsReport = report,
            isLoading = false,
            userMessage = message,
            isAutomationPromptVisible = showPrompt,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.Eagerly,
        initialValue = MoneyUiState(selectedMonth = currentMonthStr),
    )

    fun setMonth(month: String) {
        _selectedMonth.value = month
    }

    fun previousMonth() {
        try {
            val ym = YearMonth.parse(_selectedMonth.value)
            _selectedMonth.value = ym.minusMonths(1).toString()
        } catch (_: Exception) {}
    }

    fun nextMonth() {
        try {
            val ym = YearMonth.parse(_selectedMonth.value)
            _selectedMonth.value = ym.plusMonths(1).toString()
        } catch (_: Exception) {}
    }

    fun setSelectedTab(index: Int) {
        _selectedTab.value = index
    }

    fun setFilterType(type: String) {
        _filterType.value = type
    }

    fun setCategoryFilter(category: String) {
        _filterCategory.value = category
    }

    fun setSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun dismissAutomationPrompt() {
        _isAutomationPromptDismissed.value = true
    }

    fun clearMessage() {
        _userMessage.value = null
    }

    fun saveTransaction(transaction: TransactionModel) {
        viewModelScope.launch {
            val currentUid = authRepository.currentUserSession?.uid ?: return@launch
            val toSave = transaction.copy(ownerUid = currentUid)
            transactionRepository.saveTransaction(toSave)
                .onSuccess {
                    _userMessage.value = "Transaction saved"
                }
                .onFailure { e ->
                    _userMessage.value = e.message ?: "Failed to save transaction"
                }
        }
    }

    fun deleteTransaction(id: String) {
        viewModelScope.launch {
            val currentUid = authRepository.currentUserSession?.uid ?: return@launch
            transactionRepository.deleteTransaction(id, currentUid)
                .onSuccess {
                    _userMessage.value = "Transaction deleted"
                }
                .onFailure { e ->
                    _userMessage.value = e.message ?: "Failed to delete transaction"
                }
        }
    }

    fun setMonthlyBudget(amountPaise: Long) {
        viewModelScope.launch {
            val currentUid = authRepository.currentUserSession?.uid ?: return@launch
            val budget = BudgetModel.fromPaise(
                month = _selectedMonth.value,
                ownerUid = currentUid,
                amountPaise = amountPaise,
                updatedAt = Date(),
            )
            transactionRepository.saveBudget(budget)
                .onSuccess {
                    _userMessage.value = "Monthly budget updated"
                }
                .onFailure { e ->
                    _userMessage.value = e.message ?: "Failed to update budget"
                }
        }
    }

    companion object {
        fun factory(
            transactionRepository: ITransactionRepository,
            authRepository: IAuthRepository,
        ): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return MoneyViewModel(transactionRepository, authRepository) as T
            }
        }
    }
}
