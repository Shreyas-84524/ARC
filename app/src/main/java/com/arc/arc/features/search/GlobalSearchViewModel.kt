package com.arc.arc.features.search

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.arc.arc.core.auth.AuthState
import com.arc.arc.core.auth.IAuthRepository
import com.arc.arc.core.model.HabitModel
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TransactionModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

enum class SearchFilter(val label: String) {
    ALL("All"),
    TASKS("Tasks"),
    HABITS("Habits"),
    TRANSACTIONS("Transactions"),
}

data class GlobalSearchUiState(
    val query: String = "",
    val activeFilter: SearchFilter = SearchFilter.ALL,
    val matchedTasks: List<TaskModel> = emptyList(),
    val matchedHabits: List<HabitModel> = emptyList(),
    val matchedTransactions: List<TransactionModel> = emptyList(),
    val rawTaskCount: Int = 0,
    val rawHabitCount: Int = 0,
    val rawTransactionCount: Int = 0,
    val isSearching: Boolean = false,
) {
    val totalMatches: Int
        get() = rawTaskCount + rawHabitCount + rawTransactionCount
}

@OptIn(FlowPreview::class, ExperimentalCoroutinesApi::class)
class GlobalSearchViewModel(
    private val searchRepository: IGlobalSearchRepository,
    private val authRepository: IAuthRepository,
) : ViewModel() {

    private val _query = MutableStateFlow("")
    private val _activeFilter = MutableStateFlow(SearchFilter.ALL)
    private val _isSearching = MutableStateFlow(false)
    private val _rawResults = MutableStateFlow(SearchResults())

    init {
        viewModelScope.launch {
            combine(_query, authRepository.authState) { q, auth ->
                val uid = (auth as? AuthState.Authenticated)?.user?.uid ?: ""
                Pair(q, uid)
            }
                .debounce { (q, _) -> if (q.isBlank()) 0L else 300L }
                .distinctUntilChanged()
                .collect { (q, uid) ->
                    executeSearch(q, uid)
                }
        }
    }

    private suspend fun executeSearch(query: String, uid: String) {
        val clean = query.trim()
        if (clean.isBlank() || uid.isBlank()) {
            _isSearching.value = false
            _rawResults.value = SearchResults()
            return
        }

        _isSearching.value = true
        val results = searchRepository.search(uid, clean)
        _rawResults.value = results
        _isSearching.value = false
    }

    val uiState: StateFlow<GlobalSearchUiState> = combine(
        _query,
        _activeFilter,
        _rawResults,
        _isSearching
    ) { query, filter, results, isSearching ->
        val filteredTasks = if (filter == SearchFilter.ALL || filter == SearchFilter.TASKS) results.tasks else emptyList()
        val filteredHabits = if (filter == SearchFilter.ALL || filter == SearchFilter.HABITS) results.habits else emptyList()
        val filteredTransactions = if (filter == SearchFilter.ALL || filter == SearchFilter.TRANSACTIONS) results.transactions else emptyList()

        GlobalSearchUiState(
            query = query,
            activeFilter = filter,
            matchedTasks = filteredTasks,
            matchedHabits = filteredHabits,
            matchedTransactions = filteredTransactions,
            rawTaskCount = results.tasks.size,
            rawHabitCount = results.habits.size,
            rawTransactionCount = results.transactions.size,
            isSearching = isSearching,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.Eagerly,
        initialValue = GlobalSearchUiState()
    )

    fun onQueryChanged(newQuery: String) {
        _query.value = newQuery
    }

    fun onFilterSelected(filter: SearchFilter) {
        _activeFilter.value = filter
    }

    fun clearQuery() {
        _query.value = ""
    }

    companion object {
        fun provideFactory(
            searchRepository: IGlobalSearchRepository,
            authRepository: IAuthRepository,
        ): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return GlobalSearchViewModel(
                    searchRepository = searchRepository,
                    authRepository = authRepository,
                ) as T
            }
        }
    }
}
