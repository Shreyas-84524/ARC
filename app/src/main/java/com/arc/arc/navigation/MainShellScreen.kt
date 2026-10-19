package com.arc.arc.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.CheckBox
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.NotificationsNone
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.NavigationDrawerItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arc.arc.core.auth.IAuthRepository
import com.arc.arc.core.auth.UserSession
import com.arc.arc.core.datastore.AppPreferencesDataStore
import com.arc.arc.core.designsystem.components.ArcBottomNavigationBar
import com.arc.arc.core.designsystem.components.ArcConfirmationDialog
import com.arc.arc.core.designsystem.components.ArcNavTab
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.di.AppContainer
import com.arc.arc.features.dashboard.DashboardPlaceholderScreen
import com.arc.arc.features.search.GlobalSearchScreen
import com.arc.arc.features.search.GlobalSearchViewModel
import com.arc.arc.features.settings.SettingsScreen
import com.arc.arc.features.settings.SettingsViewModel
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.launch

enum class ShellOverlayRoute { NONE, SEARCH, SETTINGS }

@Composable
fun MainShellScreen(
    authRepository: IAuthRepository,
    preferencesDataStore: AppPreferencesDataStore,
    container: AppContainer? = null,
    tasksContent: @Composable () -> Unit,
    habitsContent: @Composable () -> Unit = {},
    moneyContent: @Composable () -> Unit = {},
    vaultContent: @Composable () -> Unit = {},
    dashboardContent: (@Composable ((ArcNavTab) -> Unit) -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    var selectedTab by remember { mutableStateOf(ArcNavTab.DASHBOARD) }
    var activeOverlay by remember { mutableStateOf(ShellOverlayRoute.NONE) }
    var showSignOutDialog by remember { mutableStateOf(false) }
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    val userSession = authRepository.currentUserSession

    if (activeOverlay == ShellOverlayRoute.SEARCH && container != null) {
        val searchViewModel: GlobalSearchViewModel = viewModel(
            factory = GlobalSearchViewModel.provideFactory(
                searchRepository = container.globalSearchRepository,
                authRepository = container.authRepository,
            ),
        )
        GlobalSearchScreen(
            viewModel = searchViewModel,
            onBackClick = { activeOverlay = ShellOverlayRoute.NONE },
            onTaskClick = { activeOverlay = ShellOverlayRoute.NONE; selectedTab = ArcNavTab.TASKS },
            onHabitClick = { activeOverlay = ShellOverlayRoute.NONE; selectedTab = ArcNavTab.HABITS },
            onTransactionClick = { activeOverlay = ShellOverlayRoute.NONE; selectedTab = ArcNavTab.MONEY },
        )
        return
    }

    if (activeOverlay == ShellOverlayRoute.SETTINGS && container != null) {
        val settingsViewModel: SettingsViewModel = viewModel(
            factory = SettingsViewModel.provideFactory(
                preferencesDataStore = container.preferencesDataStore,
                authRepository = container.authRepository,
                taskRepository = container.taskRepository,
                habitRepository = container.habitRepository,
                transactionRepository = container.transactionRepository,
                secretNoteRepository = container.secretNoteRepository,
            ),
        )
        SettingsScreen(
            viewModel = settingsViewModel,
            onNavigateBack = { activeOverlay = ShellOverlayRoute.NONE },
            onNavigateToVault = { activeOverlay = ShellOverlayRoute.NONE; selectedTab = ArcNavTab.VAULT },
        )
        return
    }

    if (showSignOutDialog) {
        ArcConfirmationDialog(
            title = "Sign Out",
            message = "Are you sure you want to sign out from ${userSession?.displayName ?: "ARC"}?",
            confirmLabel = "Sign Out",
            isDanger = true,
            onConfirm = { showSignOutDialog = false; scope.launch { authRepository.signOut() } },
            onDismiss = { showSignOutDialog = false },
        )
    }

    fun selectDestination(tab: ArcNavTab) {
        selectedTab = tab
        scope.launch { drawerState.close() }
    }

    ModalNavigationDrawer(
        drawerState = drawerState,
        gesturesEnabled = true,
        scrimColor = Color.Black.copy(alpha = 0.64f),
        drawerContent = {
            AppNavigationDrawer(
                userSession = userSession,
                selectedTab = selectedTab,
                onDestinationSelected = ::selectDestination,
                onSearchClick = { scope.launch { drawerState.close() }; activeOverlay = ShellOverlayRoute.SEARCH },
                onSettingsClick = { scope.launch { drawerState.close() }; activeOverlay = ShellOverlayRoute.SETTINGS },
                onSignOutClick = { scope.launch { drawerState.close() }; showSignOutDialog = true },
            )
        },
    ) {
        Scaffold(
            modifier = modifier.fillMaxSize(),
            containerColor = ArcTheme.colors.background,
            topBar = {
                MainTopBar(
                    selectedTab = selectedTab,
                    userSession = userSession,
                    onMenuClick = { scope.launch { drawerState.open() } },
                    onNotificationsClick = { activeOverlay = ShellOverlayRoute.SETTINGS },
                    onSettingsClick = { activeOverlay = ShellOverlayRoute.SETTINGS },
                )
            },
            bottomBar = {
                ArcBottomNavigationBar(
                    currentRoute = selectedTab.route,
                    onTabSelected = { selectedTab = it },
                )
            },
        ) { innerPadding ->
            Box(Modifier.fillMaxSize().padding(innerPadding).consumeWindowInsets(innerPadding)) {
                when (selectedTab) {
                    ArcNavTab.DASHBOARD -> if (dashboardContent != null) {
                        dashboardContent { selectedTab = it }
                    } else {
                        DashboardPlaceholderScreen(onNavigateToTasks = { selectedTab = ArcNavTab.TASKS })
                    }
                    ArcNavTab.TASKS -> tasksContent()
                    ArcNavTab.HABITS -> habitsContent()
                    ArcNavTab.MONEY -> moneyContent()
                    ArcNavTab.VAULT -> vaultContent()
                }
            }
        }
    }
}

@Composable
private fun AppNavigationDrawer(
    userSession: UserSession?,
    selectedTab: ArcNavTab,
    onDestinationSelected: (ArcNavTab) -> Unit,
    onSearchClick: () -> Unit,
    onSettingsClick: () -> Unit,
    onSignOutClick: () -> Unit,
) {
    ModalDrawerSheet(
        drawerContainerColor = ArcTheme.colors.surface,
        drawerContentColor = ArcTheme.colors.textPrimary,
        modifier = Modifier.fillMaxHeight().width(312.dp),
    ) {
        Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 22.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Surface(shape = CircleShape, color = Color.Black, modifier = Modifier.size(54.dp)) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(Icons.Default.Person, null, tint = ArcTheme.colors.accent, modifier = Modifier.size(30.dp))
                    }
                }
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        text = userSession?.displayName ?: "ARC User",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = userSession?.email ?: "Local account",
                        fontSize = 13.sp,
                        color = ArcTheme.colors.textMuted,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            HorizontalDivider(color = ArcTheme.colors.borderMedium)
            Spacer(Modifier.height(12.dp))
            DrawerDestination("Dashboard", Icons.Default.Dashboard, selectedTab == ArcNavTab.DASHBOARD) { onDestinationSelected(ArcNavTab.DASHBOARD) }
            DrawerDestination("Tasks", Icons.Default.CheckBox, selectedTab == ArcNavTab.TASKS) { onDestinationSelected(ArcNavTab.TASKS) }
            DrawerDestination("Habits", Icons.Default.FlashOn, selectedTab == ArcNavTab.HABITS) { onDestinationSelected(ArcNavTab.HABITS) }
            DrawerDestination("Money Tracker", Icons.Default.AccountBalanceWallet, selectedTab == ArcNavTab.MONEY) { onDestinationSelected(ArcNavTab.MONEY) }
            Spacer(Modifier.height(8.dp))
            HorizontalDivider(color = ArcTheme.colors.borderMedium)
            Spacer(Modifier.height(8.dp))
            DrawerDestination("Secret Vault", Icons.Default.Lock, selectedTab == ArcNavTab.VAULT) { onDestinationSelected(ArcNavTab.VAULT) }
            DrawerDestination("Global Search", Icons.Default.Search, false, onClick = onSearchClick)
            DrawerDestination("Settings & Profile", Icons.Default.Settings, false, onClick = onSettingsClick)
            Spacer(Modifier.weight(1f))
            HorizontalDivider(color = ArcTheme.colors.borderMedium)
            DrawerDestination("Log Out", Icons.AutoMirrored.Filled.ExitToApp, false, danger = true, onClick = onSignOutClick)
            Text(
                "Project Arc  •  1.4.0-native",
                modifier = Modifier.padding(16.dp),
                color = ArcTheme.colors.textMuted,
                fontSize = 12.sp,
            )
        }
    }
}

@Composable
private fun DrawerDestination(
    label: String,
    icon: ImageVector,
    selected: Boolean,
    danger: Boolean = false,
    onClick: () -> Unit,
) {
    val itemColor = if (danger) ArcTheme.colors.danger else if (selected) ArcTheme.colors.accent else ArcTheme.colors.textSecondary
    NavigationDrawerItem(
        label = { Text(label, fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium) },
        icon = { Icon(icon, contentDescription = null) },
        selected = selected,
        onClick = onClick,
        colors = NavigationDrawerItemDefaults.colors(
            selectedContainerColor = ArcTheme.colors.accent.copy(alpha = 0.14f),
            unselectedContainerColor = Color.Transparent,
            selectedIconColor = itemColor,
            selectedTextColor = itemColor,
            unselectedIconColor = itemColor,
            unselectedTextColor = itemColor,
        ),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.padding(vertical = 2.dp),
    )
}

@Composable
private fun MainTopBar(
    selectedTab: ArcNavTab,
    userSession: UserSession?,
    onMenuClick: () -> Unit,
    onNotificationsClick: () -> Unit,
    onSettingsClick: () -> Unit,
) {
    val isDashboard = selectedTab == ArcNavTab.DASHBOARD
    val configuration = LocalConfiguration.current
    val locale = androidx.core.os.ConfigurationCompat.getLocales(configuration)[0] ?: Locale.US
    val dashboardDate = remember(locale) {
        LocalDate.now().format(DateTimeFormatter.ofPattern("EEE, MMM d", locale))
    }
    val title = when (selectedTab) {
        ArcNavTab.DASHBOARD -> "Good ${dayPeriod()}, ${userSession?.displayName?.substringBefore(' ') ?: "there"}"
        ArcNavTab.TASKS -> "Task Manager"
        ArcNavTab.HABITS -> "Habit Tracker"
        ArcNavTab.MONEY -> "Money Tracker"
        ArcNavTab.VAULT -> "Secret Vault"
    }
    Surface(color = ArcTheme.colors.background, modifier = Modifier.fillMaxWidth().statusBarsPadding()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 10.dp, end = ArcDimens.ScreenHorizontalPadding, top = 10.dp, bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onMenuClick) {
                Icon(Icons.Default.Menu, "Open navigation menu", tint = ArcTheme.colors.textPrimary, modifier = Modifier.size(27.dp))
            }
            Column(Modifier.weight(1f)) {
                Text(title, color = ArcTheme.colors.textPrimary, fontSize = if (isDashboard) 20.sp else 25.sp, fontWeight = FontWeight.Bold)
                if (isDashboard) {
                    Text(
                        dashboardDate,
                        color = ArcTheme.colors.textMuted,
                        fontSize = 11.sp,
                    )
                }
            }
            IconButton(onClick = onNotificationsClick) {
                Icon(Icons.Default.NotificationsNone, "Notifications", tint = ArcTheme.colors.textSecondary, modifier = Modifier.size(25.dp))
            }
            IconButton(onClick = onSettingsClick) {
                Icon(Icons.Default.Settings, "Settings", tint = ArcTheme.colors.textSecondary, modifier = Modifier.size(24.dp))
            }
        }
    }
}

private fun dayPeriod(): String = when (java.time.LocalTime.now().hour) {
    in 5..11 -> "Morning"
    in 12..16 -> "Afternoon"
    else -> "Evening"
}
