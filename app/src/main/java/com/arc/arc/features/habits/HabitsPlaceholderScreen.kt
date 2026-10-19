package com.arc.arc.features.habits

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.arc.arc.core.designsystem.components.ArcEmptyState
import com.arc.arc.core.designsystem.theme.ArcDimens

@Composable
fun HabitsPlaceholderScreen(
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
            icon = Icons.Default.FlashOn,
            title = "Habits Tracker (Phase 2)",
            description = "Habit streaks, daily entry tracking, and completion matrix are scheduled for Phase 2.\n\nData contracts and Room foundation have been prepared.",
            actionLabel = "Go to Tasks",
            onAction = onNavigateToTasks,
        )
    }
}
