package com.arc.arc.features.money.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.PieChart
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Wallet
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.TabRowDefaults
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.components.ArcEmptyState
import com.arc.arc.core.designsystem.components.ArcFilterChip
import com.arc.arc.core.designsystem.components.ArcPrimaryButton
import com.arc.arc.core.designsystem.components.ArcTextField
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.core.utilities.CurrencyFormatter
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MoneyScreen(
    uiState: MoneyUiState,
    onPreviousMonth: () -> Unit,
    onNextMonth: () -> Unit,
    onTabSelected: (Int) -> Unit,
    onFilterTypeSelected: (String) -> Unit,
    onSearchQueryChanged: (String) -> Unit,
    onSaveTransaction: (TransactionModel) -> Unit,
    onDeleteTransaction: (String) -> Unit,
    onSetBudget: (Long) -> Unit,
    onClearMessage: () -> Unit,
    isDetectionEnabled: Boolean = false,
    isAutoSaveEnabled: Boolean = false,
    onToggleDetection: (Boolean) -> Unit = {},
    onToggleAutoSave: (Boolean) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val snackbarHostState = remember { SnackbarHostState() }
    var showEditorSheet by remember { mutableStateOf(false) }
    var showSetBudgetDialog by remember { mutableStateOf(false) }
    var showSettingsSheet by remember { mutableStateOf(false) }
    var selectedTransactionForDetails by remember { mutableStateOf<TransactionModel?>(null) }

    val editorSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val detailsSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val settingsSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    val monthDisplayName = remember(uiState.selectedMonth) {
        try {
            val ym = YearMonth.parse(uiState.selectedMonth)
            ym.format(DateTimeFormatter.ofPattern("MMMM yyyy", Locale.US))
        } catch (_: Exception) {
            uiState.selectedMonth
        }
    }

    LaunchedEffect(uiState.userMessage) {
        uiState.userMessage?.let {
            snackbarHostState.showSnackbar(it)
            onClearMessage()
        }
    }

    if (showSettingsSheet) {
        MoneySettingsSheet(
            sheetState = settingsSheetState,
            isDetectionEnabled = isDetectionEnabled,
            isAutoSaveEnabled = isAutoSaveEnabled,
            onToggleDetection = onToggleDetection,
            onToggleAutoSave = onToggleAutoSave,
            onSimulateTransaction = onSaveTransaction,
            onDismiss = { showSettingsSheet = false },
        )
    }

    if (showSetBudgetDialog) {
        SetBudgetDialog(
            currentMonth = uiState.selectedMonth,
            currentBudgetPaise = uiState.monthlyBudgetPaise,
            onDismiss = { showSetBudgetDialog = false },
            onSetBudget = onSetBudget,
        )
    }

    if (showEditorSheet) {
        TransactionEditorSheet(
            sheetState = editorSheetState,
            onDismiss = { showEditorSheet = false },
            onSaveTransaction = onSaveTransaction,
        )
    }

    selectedTransactionForDetails?.let { tx ->
        TransactionDetailsSheet(
            transaction = tx,
            sheetState = detailsSheetState,
            onDismiss = { selectedTransactionForDetails = null },
            onDelete = {
                onDeleteTransaction(tx.id)
                selectedTransactionForDetails = null
            },
        )
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        modifier = modifier.fillMaxSize(),
        containerColor = ArcTheme.colors.background,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        floatingActionButton = {
            if (uiState.selectedTab == 0) {
                FloatingActionButton(
                    onClick = { showEditorSheet = true },
                    containerColor = ArcTheme.colors.accent,
                    contentColor = Color.Black,
                    shape = CircleShape,
                ) {
                    Icon(imageVector = Icons.Default.Add, contentDescription = "Add Transaction")
                }
            }
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            MoneyModeSwitcher(
                selectedTab = uiState.selectedTab,
                onTabSelected = onTabSelected,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
            )

            MonthSelectorHeader(
                monthName = monthDisplayName,
                onPreviousMonth = onPreviousMonth,
                onNextMonth = onNextMonth,
                onSettingsClick = { showSettingsSheet = true },
            )

            Spacer(modifier = Modifier.height(12.dp))

            if (uiState.selectedTab == 0) {
                // TRANSACTIONS TAB
                TransactionsView(
                    uiState = uiState,
                    onConfigureBudgetClick = { showSetBudgetDialog = true },
                    onFilterTypeSelected = onFilterTypeSelected,
                    onSearchQueryChanged = onSearchQueryChanged,
                    onTransactionClick = { selectedTransactionForDetails = it },
                    onDeleteTransaction = onDeleteTransaction,
                )
            } else {
                // ANALYTICS TAB
                AnalyticsView(
                    uiState = uiState,
                    monthName = monthDisplayName,
                )
            }
        }
    }
}

@Composable
private fun MoneyModeSwitcher(
    selectedTab: Int,
    onTabSelected: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(color = ArcTheme.colors.surface, shape = RoundedCornerShape(18.dp), modifier = modifier.fillMaxWidth()) {
        Row(Modifier.padding(5.dp)) {
            listOf("Transactions" to Icons.Default.SwapHoriz, "Analytics" to Icons.Default.PieChart).forEachIndexed { index, item ->
                val selected = selectedTab == index
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (selected) ArcTheme.colors.accent else Color.Transparent)
                        .clickable { onTabSelected(index) }
                        .padding(vertical = 13.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(item.second, null, tint = if (selected) Color.Black else ArcTheme.colors.textSecondary, modifier = Modifier.size(19.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(item.first, fontWeight = FontWeight.Bold, color = if (selected) Color.Black else ArcTheme.colors.textSecondary)
                }
            }
        }
    }
}

@Composable
private fun MonthSelectorHeader(
    monthName: String,
    onPreviousMonth: () -> Unit,
    onNextMonth: () -> Unit,
    onSettingsClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onPreviousMonth) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Previous Month",
                    tint = ArcTheme.colors.textSecondary,
                )
            }

            Text(
                text = monthName,
                style = ArcTheme.typography.titleMedium.copy(
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp,
                ),
                color = ArcTheme.colors.textPrimary,
            )

            IconButton(onClick = onNextMonth) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = "Next Month",
                    tint = ArcTheme.colors.textSecondary,
                )
            }
        }

        IconButton(onClick = onSettingsClick) {
            Icon(
                imageVector = Icons.Default.Tune,
                contentDescription = "Settings",
                tint = ArcTheme.colors.textSecondary,
            )
        }
    }
}

@Composable
private fun TransactionsView(
    uiState: MoneyUiState,
    onConfigureBudgetClick: () -> Unit,
    onFilterTypeSelected: (String) -> Unit,
    onSearchQueryChanged: (String) -> Unit,
    onTransactionClick: (TransactionModel) -> Unit,
    onDeleteTransaction: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Set Budget Banner (when budget == 0)
        if (!uiState.hasBudget) {
            item {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(ArcDimens.RadiusCard))
                        .background(ArcTheme.colors.accent.copy(alpha = 0.1f))
                        .border(1.dp, ArcTheme.colors.accent.copy(alpha = 0.3f), RoundedCornerShape(ArcDimens.RadiusCard)),
                    color = ArcTheme.colors.surface,
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Wallet, contentDescription = null, tint = ArcTheme.colors.accent)
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(
                                text = "Set your monthly budget to start tracking balance!",
                                style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                color = ArcTheme.colors.textPrimary,
                            )
                        }
                        Spacer(modifier = Modifier.height(14.dp))
                        ArcPrimaryButton(
                            text = "Configure Monthly Budget",
                            onClick = onConfigureBudgetClick,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        }

        // Remaining Budget Card
        item {
            BudgetOverviewCard(
                uiState = uiState,
                onCardClick = onConfigureBudgetClick,
            )
        }

        // Search & Filter Row
        item {
            Column {
                ArcTextField(
                    value = uiState.searchQuery,
                    onValueChange = onSearchQueryChanged,
                    placeholder = "Search transactions...",
                    leadingIcon = {
                        Icon(Icons.Default.Search, contentDescription = null, tint = ArcTheme.colors.textSecondary)
                    },
                    modifier = Modifier.fillMaxWidth(),
                )

                Spacer(modifier = Modifier.height(10.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    listOf("All", "Expense", "Income").forEach { type ->
                        ArcFilterChip(
                            label = type,
                            selected = uiState.filterType == type,
                            onClick = { onFilterTypeSelected(type) },
                        )
                    }
                }
            }
        }

        // Header
        item {
            Text(
                text = "Recent Transactions (${uiState.filteredTransactions.size})",
                style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = ArcTheme.colors.textPrimary,
            )
        }

        // Transactions list or empty state
        if (uiState.filteredTransactions.isEmpty()) {
            item {
                ArcEmptyState(
                    icon = Icons.Default.ReceiptLong,
                    title = "No Transactions Found",
                    description = if (uiState.searchQuery.isNotBlank()) "No records match '${uiState.searchQuery}'" else "Tap + to add your first transaction this month",
                )
            }
        } else {
            items(uiState.filteredTransactions, key = { it.id }) { tx ->
                TransactionCard(
                    transaction = tx,
                    onClick = { onTransactionClick(tx) },
                    onDeleteClick = { onDeleteTransaction(tx.id) },
                )
            }
        }

        item {
            Spacer(modifier = Modifier.height(80.dp)) // Space for FAB
        }
    }
}

@Composable
private fun BudgetOverviewCard(
    uiState: MoneyUiState,
    onCardClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val remainingColor = if (uiState.remainingBudgetPaise >= 0L) {
        ArcTheme.colors.success
    } else {
        ArcTheme.colors.danger
    }

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(ArcDimens.RadiusCard))
            .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(ArcDimens.RadiusCard))
            .clickable(onClick = onCardClick),
        color = ArcTheme.colors.surface,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
        ) {
            Text(
                text = "REMAINING BALANCE",
                style = ArcTheme.typography.labelSmall.copy(
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.2.sp,
                    color = ArcTheme.colors.textSecondary,
                ),
            )
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = CurrencyFormatter.formatPaise(uiState.remainingBudgetPaise),
                style = ArcTheme.typography.headlineLarge.copy(
                    fontWeight = FontWeight.Bold,
                    color = remainingColor,
                    fontSize = 28.sp,
                ),
            )

            if (uiState.hasBudget) {
                Spacer(modifier = Modifier.height(14.dp))
                LinearProgressIndicator(
                    progress = { uiState.budgetUtilizationRate.toFloat().coerceIn(0f, 1f) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp)),
                    color = if (uiState.isBudgetExceeded) ArcTheme.colors.danger else ArcTheme.colors.accent,
                    trackColor = ArcTheme.colors.background,
                    strokeCap = StrokeCap.Round,
                )
            }

            Spacer(modifier = Modifier.height(18.dp))
            HorizontalDivider(color = ArcTheme.colors.borderSubtle.copy(alpha = 0.5f), thickness = 0.5.dp)
            Spacer(modifier = Modifier.height(14.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                BudgetStatColumn(
                    label = "Budget Limit",
                    value = CurrencyFormatter.formatPaise(uiState.monthlyBudgetPaise),
                    color = ArcTheme.colors.textPrimary,
                )
                BudgetStatColumn(
                    label = "Total Income",
                    value = "+${CurrencyFormatter.formatPaise(uiState.totalIncomePaise)}",
                    color = ArcTheme.colors.success,
                )
                BudgetStatColumn(
                    label = "Total Expense",
                    value = "-${CurrencyFormatter.formatPaise(uiState.totalExpensesPaise)}",
                    color = ArcTheme.colors.danger,
                )
            }
        }
    }
}

@Composable
private fun BudgetStatColumn(
    label: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        Text(
            text = label,
            style = ArcTheme.typography.labelSmall.copy(color = ArcTheme.colors.textSecondary),
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = value,
            style = ArcTheme.typography.titleMedium.copy(
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
                color = color,
            ),
        )
    }
}

@Composable
private fun AnalyticsView(
    uiState: MoneyUiState,
    monthName: String,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // 1. Financial Health & Pace Card
        uiState.analyticsReport?.let { report ->
            item {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(ArcDimens.RadiusCard))
                        .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(ArcDimens.RadiusCard)),
                    color = ArcTheme.colors.surface,
                ) {
                    Column(modifier = Modifier.padding(20.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = "Financial Health",
                                style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                color = ArcTheme.colors.textPrimary,
                            )
                            val (badgeBg, badgeText) = when (report.healthRating) {
                                com.arc.arc.features.money.analytics.FinancialHealthRating.EXCELLENT -> Pair(ArcTheme.colors.accent, "EXCELLENT")
                                com.arc.arc.features.money.analytics.FinancialHealthRating.HEALTHY -> Pair(ArcTheme.colors.success, "HEALTHY")
                                com.arc.arc.features.money.analytics.FinancialHealthRating.MODERATE -> Pair(Color(0xFFFAAD14), "MODERATE")
                                com.arc.arc.features.money.analytics.FinancialHealthRating.CRITICAL -> Pair(ArcTheme.colors.danger, "CRITICAL")
                            }
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(6.dp))
                                    .background(badgeBg.copy(alpha = 0.15f))
                                    .padding(horizontal = 10.dp, vertical = 4.dp),
                            ) {
                                Text(
                                    text = badgeText,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = badgeBg,
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))
                        Text(
                            text = report.healthSummary,
                            style = ArcTheme.typography.bodyMedium.copy(
                                fontSize = 13.sp,
                                color = ArcTheme.colors.textSecondary,
                            ),
                        )

                        Spacer(modifier = Modifier.height(14.dp))
                        HorizontalDivider(color = ArcTheme.colors.borderSubtle.copy(alpha = 0.5f), thickness = 0.5.dp)
                        Spacer(modifier = Modifier.height(12.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Column {
                                Text(text = "Daily Burn Rate", style = ArcTheme.typography.labelSmall.copy(color = ArcTheme.colors.textSecondary))
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = "${CurrencyFormatter.formatPaise(report.dailyAverageSpendPaise)}/day",
                                    style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold, color = ArcTheme.colors.textPrimary),
                                )
                            }
                            Column {
                                Text(text = "Projected Spend", style = ArcTheme.typography.labelSmall.copy(color = ArcTheme.colors.textSecondary))
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = CurrencyFormatter.formatPaise(report.projectedMonthEndSpendPaise),
                                    style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold, color = ArcTheme.colors.textPrimary),
                                )
                            }
                            Column {
                                Text(text = "Budget Pace", style = ArcTheme.typography.labelSmall.copy(color = ArcTheme.colors.textSecondary))
                                Spacer(modifier = Modifier.height(4.dp))
                                val paceLabel = when (report.budgetPaceStatus) {
                                    com.arc.arc.features.money.analytics.BudgetPaceStatus.ON_TRACK -> "On Track"
                                    com.arc.arc.features.money.analytics.BudgetPaceStatus.AT_RISK -> "At Risk"
                                    com.arc.arc.features.money.analytics.BudgetPaceStatus.EXCEEDED -> "Exceeded"
                                    com.arc.arc.features.money.analytics.BudgetPaceStatus.NO_BUDGET -> "No Budget"
                                }
                                val paceColor = when (report.budgetPaceStatus) {
                                    com.arc.arc.features.money.analytics.BudgetPaceStatus.ON_TRACK -> ArcTheme.colors.success
                                    com.arc.arc.features.money.analytics.BudgetPaceStatus.AT_RISK -> Color(0xFFFAAD14)
                                    com.arc.arc.features.money.analytics.BudgetPaceStatus.EXCEEDED -> ArcTheme.colors.danger
                                    com.arc.arc.features.money.analytics.BudgetPaceStatus.NO_BUDGET -> ArcTheme.colors.textSecondary
                                }
                                Text(
                                    text = paceLabel,
                                    style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold, color = paceColor),
                                )
                            }
                        }
                    }
                }
            }
        }

        // 2. Month-over-Month Comparison Card
        uiState.analyticsReport?.monthOverMonthComparison?.let { mom ->
            item {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(ArcDimens.RadiusCard))
                        .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(ArcDimens.RadiusCard)),
                    color = ArcTheme.colors.surface,
                ) {
                    Column(modifier = Modifier.padding(20.dp)) {
                        Text(
                            text = "Month-over-Month Trend",
                            style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = ArcTheme.colors.textPrimary,
                        )
                        Spacer(modifier = Modifier.height(14.dp))
                        SummaryRow(
                            label = "Previous Month Expenses (${mom.previousMonth})",
                            value = CurrencyFormatter.formatPaise(mom.previousExpensePaise),
                        )
                        SummaryRow(
                            label = "Expense Change",
                            value = "${if (mom.expenseChangePercentage >= 0) "+" else ""}${"%.1f".format(mom.expenseChangePercentage)}%",
                            valueColor = if (mom.expenseChangePercentage > 0) ArcTheme.colors.danger else ArcTheme.colors.success,
                        )
                        SummaryRow(
                            label = "Income Change",
                            value = "${if (mom.incomeChangePercentage >= 0) "+" else ""}${"%.1f".format(mom.incomeChangePercentage)}%",
                            valueColor = if (mom.incomeChangePercentage >= 0) ArcTheme.colors.success else ArcTheme.colors.danger,
                        )
                    }
                }
            }
        }

        // Monthly Summary Card
        item {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(ArcDimens.RadiusCard))
                    .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(ArcDimens.RadiusCard)),
                color = ArcTheme.colors.surface,
            ) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(
                        text = "Monthly Summary ($monthName)",
                        style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = ArcTheme.colors.textPrimary,
                    )
                    Spacer(modifier = Modifier.height(16.dp))

                    SummaryRow(label = "Monthly Budget Limit", value = CurrencyFormatter.formatPaise(uiState.monthlyBudgetPaise))
                    SummaryRow(label = "Total Monthly Income", value = "+${CurrencyFormatter.formatPaise(uiState.totalIncomePaise)}", valueColor = ArcTheme.colors.success)
                    SummaryRow(label = "Total Monthly Expenses", value = "-${CurrencyFormatter.formatPaise(uiState.totalExpensesPaise)}", valueColor = ArcTheme.colors.danger)
                    SummaryRow(
                        label = "Net Savings (Income - Expense)",
                        value = CurrencyFormatter.formatPaise(uiState.savingsPaise),
                        valueColor = if (uiState.savingsPaise >= 0L) ArcTheme.colors.accent else ArcTheme.colors.danger,
                    )

                    HorizontalDivider(color = ArcTheme.colors.borderSubtle.copy(alpha = 0.5f), thickness = 0.5.dp, modifier = Modifier.padding(vertical = 12.dp))

                    SummaryRow(
                        label = "Remaining Budget Balance",
                        value = CurrencyFormatter.formatPaise(uiState.remainingBudgetPaise),
                        valueColor = if (uiState.remainingBudgetPaise >= 0L) ArcTheme.colors.success else ArcTheme.colors.danger,
                        isBold = true,
                    )
                }
            }
        }

        // Savings Rate Progress Card
        item {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(ArcDimens.RadiusCard))
                    .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(ArcDimens.RadiusCard)),
                color = ArcTheme.colors.surface,
            ) {
                Row(
                    modifier = Modifier.padding(20.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Savings Rate",
                            style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = ArcTheme.colors.textPrimary,
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        val pct = (uiState.savingsRate * 100).toInt()
                        val desc = if (uiState.savingsPaise >= 0L) {
                            "You've saved $pct% of your total earnings this month."
                        } else {
                            "You are currently spending more than your earnings this month."
                        }
                        Text(
                            text = desc,
                            style = ArcTheme.typography.bodyMedium.copy(
                                fontSize = 13.sp,
                                color = ArcTheme.colors.textSecondary,
                            ),
                        )
                    }

                    Spacer(modifier = Modifier.width(16.dp))

                    Box(
                        modifier = Modifier.size(72.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        CircularProgressIndicator(
                            progress = { uiState.savingsRate.toFloat() },
                            modifier = Modifier.fillMaxSize(),
                            color = if (uiState.savingsPaise >= 0L) ArcTheme.colors.accent else ArcTheme.colors.danger,
                            trackColor = ArcTheme.colors.background,
                            strokeWidth = 7.dp,
                            strokeCap = StrokeCap.Round,
                        )
                        Text(
                            text = "${(uiState.savingsRate * 100).toInt()}%",
                            style = ArcTheme.typography.bodyMedium.copy(
                                fontWeight = FontWeight.Bold,
                                color = ArcTheme.colors.textPrimary,
                            ),
                        )
                    }
                }
            }
        }

        // Spending Categories Breakdown
        item {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(ArcDimens.RadiusCard))
                    .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(ArcDimens.RadiusCard)),
                color = ArcTheme.colors.surface,
            ) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(
                        text = "Category Spending Breakdown",
                        style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = ArcTheme.colors.textPrimary,
                    )
                    Spacer(modifier = Modifier.height(16.dp))

                    if (uiState.categoryExpenses.isEmpty()) {
                        Text(
                            text = "No expenses recorded for this month.",
                            style = ArcTheme.typography.bodyMedium.copy(color = ArcTheme.colors.textSecondary),
                        )
                    } else {
                        val totalExp = uiState.totalExpensesPaise.coerceAtLeast(1L)
                        val sortedCategories = uiState.categoryExpenses.entries.sortedByDescending { it.value }

                        sortedCategories.forEach { (cat, paise) ->
                            val proportion = (paise.toDouble() / totalExp.toDouble()).toFloat()
                            Column(modifier = Modifier.padding(vertical = 6.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                ) {
                                    Text(
                                        text = cat,
                                        style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                        color = ArcTheme.colors.textPrimary,
                                    )
                                    Text(
                                        text = "${CurrencyFormatter.formatPaise(paise)} (${(proportion * 100).toInt()}%)",
                                        style = ArcTheme.typography.bodyMedium.copy(
                                            color = ArcTheme.colors.textSecondary,
                                            fontSize = 13.sp,
                                        ),
                                    )
                                }
                                Spacer(modifier = Modifier.height(6.dp))
                                LinearProgressIndicator(
                                    progress = { proportion },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(6.dp)
                                        .clip(RoundedCornerShape(3.dp)),
                                    color = ArcTheme.colors.accent,
                                    trackColor = ArcTheme.colors.background,
                                    strokeCap = StrokeCap.Round,
                                )
                            }
                        }
                    }
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}

@Composable
private fun SummaryRow(
    label: String,
    value: String,
    valueColor: Color = ArcTheme.colors.textPrimary,
    isBold: Boolean = false,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 5.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = ArcTheme.typography.bodyMedium.copy(
                fontWeight = if (isBold) FontWeight.Bold else FontWeight.Normal,
                color = ArcTheme.colors.textSecondary,
            ),
        )
        Text(
            text = value,
            style = ArcTheme.typography.bodyMedium.copy(
                fontWeight = if (isBold) FontWeight.Bold else FontWeight.SemiBold,
                color = valueColor,
            ),
        )
    }
}
