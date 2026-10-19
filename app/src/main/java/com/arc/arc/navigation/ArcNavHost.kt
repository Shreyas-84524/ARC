package com.arc.arc.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arc.arc.core.auth.AuthState
import com.arc.arc.core.di.AppContainer
import com.arc.arc.core.designsystem.components.ArcLoadingState
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.features.auth.LoginScreen
import com.arc.arc.features.auth.LoginViewModel
import kotlinx.coroutines.flow.first

@Composable
fun ArcNavHost(
    container: AppContainer,
    tasksContent: @Composable () -> Unit,
    modifier: Modifier = Modifier,
) {
    val authState by container.authRepository.authState.collectAsState()

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(ArcTheme.colors.background),
    ) {
        when (val state = authState) {
            is AuthState.Initializing -> {
                ArcLoadingState()
            }

            is AuthState.Unauthenticated, is AuthState.Error -> {
                val loginViewModel: LoginViewModel = viewModel(
                    factory = LoginViewModel.factory(container.authRepository)
                )
                LoginScreen(
                    viewModel = loginViewModel,
                    onLoginSuccess = {
                        // Handled reactively by authState state flow
                    },
                )
            }

            is AuthState.Authenticated -> {
                androidx.compose.runtime.LaunchedEffect(state.user.uid) {
                    try {
                        val prefs = container.preferencesDataStore.preferencesFlow.first()
                        val tasks = container.taskRepository.getTasks(state.user.uid)
                        val habits = container.habitRepository.getHabits(state.user.uid)
                        val entries = container.habitRepository.getEntries(state.user.uid)
                        container.notificationManager.reconcile(
                            ownerUid = state.user.uid,
                            preferences = prefs,
                            tasks = tasks,
                            habits = habits,
                            habitEntries = entries,
                        )
                    } catch (_: Exception) {}
                }

                MainShellScreen(
                    authRepository = container.authRepository,
                    preferencesDataStore = container.preferencesDataStore,
                    container = container,
                    tasksContent = tasksContent,
                    habitsContent = {
                        com.arc.arc.features.habits.HabitsRoute(container = container)
                    },
                    moneyContent = {
                        com.arc.arc.features.money.MoneyRoute(container = container)
                    },
                    vaultContent = {
                        com.arc.arc.features.vault.VaultRoute(container = container)
                    },
                    dashboardContent = { onNavigateToTab ->
                        com.arc.arc.features.dashboard.DashboardRoute(
                            container = container,
                            onNavigateToTab = onNavigateToTab,
                        )
                    },
                )
            }
        }
    }
}
