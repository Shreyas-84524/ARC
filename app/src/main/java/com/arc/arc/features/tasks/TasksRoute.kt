package com.arc.arc.features.tasks

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arc.arc.core.di.AppContainer

@Composable
fun TasksRoute(
    container: AppContainer,
    modifier: Modifier = Modifier,
) {
    val tasksViewModel: TasksViewModel = viewModel(
        factory = TasksViewModel.factory(
            taskRepository = container.taskRepository,
            authRepository = container.authRepository,
            preferencesDataStore = container.preferencesDataStore,
        )
    )

    TasksScreen(
        viewModel = tasksViewModel,
        modifier = modifier,
    )
}
