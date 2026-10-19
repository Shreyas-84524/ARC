package com.arc.arc.features.habits

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arc.arc.core.di.AppContainer

@Composable
fun HabitsRoute(
    container: AppContainer,
    modifier: Modifier = Modifier,
) {
    val habitsViewModel: HabitsViewModel = viewModel(
        factory = HabitsViewModel.factory(
            habitRepository = container.habitRepository,
            authRepository = container.authRepository,
        )
    )

    HabitsScreen(
        viewModel = habitsViewModel,
        modifier = modifier,
    )
}
