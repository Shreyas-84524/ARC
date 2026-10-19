package com.arc.arc.features.dashboard

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arc.arc.core.designsystem.components.ArcNavTab
import com.arc.arc.core.di.AppContainer

@Composable
fun DashboardRoute(
    container: AppContainer,
    onNavigateToTab: (ArcNavTab) -> Unit,
    modifier: Modifier = Modifier,
) {
    val dashboardViewModel: DashboardViewModel = viewModel(
        factory = DashboardViewModel.factory(
            taskRepository = container.taskRepository,
            habitRepository = container.habitRepository,
            authRepository = container.authRepository,
            transactionRepository = container.transactionRepository,
        )
    )

    DashboardScreen(
        viewModel = dashboardViewModel,
        onNavigateToTasks = { onNavigateToTab(ArcNavTab.TASKS) },
        onNavigateToHabits = { onNavigateToTab(ArcNavTab.HABITS) },
        onNavigateToMoney = { onNavigateToTab(ArcNavTab.MONEY) },
        modifier = modifier,
    )
}
