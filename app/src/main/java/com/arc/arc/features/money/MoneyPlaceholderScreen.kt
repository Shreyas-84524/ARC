package com.arc.arc.features.money

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AttachMoney
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.arc.arc.core.designsystem.components.ArcEmptyState
import com.arc.arc.core.designsystem.theme.ArcDimens

@Composable
fun MoneyPlaceholderScreen(
    onNavigateToTasks: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(ArcDimens.ScreenHorizontalPadding),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        ArcEmptyState(
            icon = Icons.Default.AttachMoney,
            title = "Money Tracker (Phase 3)",
            description = "Transactions, budgets, monthly summaries, and policy-compliant expense management are scheduled for Phase 3.\n\nData contracts have been validated.",
            actionLabel = "Go to Tasks",
            onAction = onNavigateToTasks,
        )
    }
}
