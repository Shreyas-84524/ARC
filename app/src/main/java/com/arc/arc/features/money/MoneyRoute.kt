package com.arc.arc.features.money

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arc.arc.core.datastore.AppPreferences
import com.arc.arc.core.di.AppContainer
import com.arc.arc.features.money.ui.MoneyScreen
import com.arc.arc.features.money.ui.MoneyViewModel
import kotlinx.coroutines.launch

@Composable
fun MoneyRoute(
    container: AppContainer,
    modifier: Modifier = Modifier,
) {
    val viewModel: MoneyViewModel = viewModel(
        factory = MoneyViewModel.factory(
            transactionRepository = container.transactionRepository,
            authRepository = container.authRepository,
        )
    )

    val uiState by viewModel.uiState.collectAsState()
    val preferences by container.preferencesDataStore.preferencesFlow.collectAsState(
        initial = AppPreferences()
    )
    val coroutineScope = rememberCoroutineScope()

    MoneyScreen(
        uiState = uiState,
        onPreviousMonth = viewModel::previousMonth,
        onNextMonth = viewModel::nextMonth,
        onTabSelected = viewModel::setSelectedTab,
        onFilterTypeSelected = viewModel::setFilterType,
        onSearchQueryChanged = viewModel::setSearchQuery,
        onSaveTransaction = viewModel::saveTransaction,
        onDeleteTransaction = viewModel::deleteTransaction,
        onSetBudget = viewModel::setMonthlyBudget,
        onClearMessage = viewModel::clearMessage,
        isDetectionEnabled = preferences.isMoneyDetectionEnabled,
        isAutoSaveEnabled = preferences.isMoneyAutoSaveEnabled,
        onToggleDetection = { enabled ->
            coroutineScope.launch {
                container.preferencesDataStore.setMoneyDetectionEnabled(enabled)
            }
        },
        onToggleAutoSave = { enabled ->
            coroutineScope.launch {
                container.preferencesDataStore.setMoneyAutoSaveEnabled(enabled)
            }
        },
        modifier = modifier,
    )
}
