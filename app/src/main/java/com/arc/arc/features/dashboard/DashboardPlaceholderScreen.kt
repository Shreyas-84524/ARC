package com.arc.arc.features.dashboard

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.components.ArcEmptyState
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme

@Composable
fun DashboardPlaceholderScreen(
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
            icon = Icons.Default.Dashboard,
            title = "Dashboard (Phase 2)",
            description = "The centralized ARC productivity dashboard with analytics, streak monitoring, and widgets is scheduled for Phase 2 migration.\n\nExplore Tasks to experience ARC's first working native module.",
            actionLabel = "Go to Tasks",
            onAction = onNavigateToTasks,
        )
    }
}
