package com.arc.arc.features.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.DeleteSweep
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.arc.arc.core.designsystem.theme.ArcTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
    onNavigateBack: (() -> Unit)? = null,
    onNavigateToVault: (() -> Unit)? = null,
    onSignedOut: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val state by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    var showClearCacheDialog by remember { mutableStateOf(false) }
    var showSignOutDialog by remember { mutableStateOf(false) }

    LaunchedEffect(state.userMessage) {
        state.userMessage?.let { msg ->
            snackbarHostState.showSnackbar(msg)
            viewModel.clearUserMessage()
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Settings & Profile",
                        style = ArcTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                        color = ArcTheme.colors.textPrimary
                    )
                },
                navigationIcon = {
                    if (onNavigateBack != null) {
                        IconButton(onClick = onNavigateBack) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = "Navigate Back",
                                tint = ArcTheme.colors.textPrimary
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = ArcTheme.colors.surface
                )
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = ArcTheme.colors.background
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            SettingsSectionHeader(title = "Account & Security", icon = Icons.Default.AccountCircle)
            SettingsProfileCard(
                displayName = state.userDisplayName,
                email = state.userEmail,
                userId = state.userId
            )

            Spacer(modifier = Modifier.height(20.dp))

            // Appearance Section
            SettingsSectionHeader(title = "Appearance", icon = Icons.Default.DarkMode)
            AppearanceSelector(
                currentTheme = state.themeMode,
                onThemeSelected = { viewModel.setThemeMode(it) }
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Notifications Section
            SettingsSectionHeader(title = "Notifications", icon = Icons.Default.Notifications)
            SettingsToggleRow(
                title = "Master Notifications",
                subtitle = "Enable or disable all application notifications",
                checked = state.masterNotificationsEnabled,
                onCheckedChange = { viewModel.setMasterNotifications(it) }
            )

            if (state.masterNotificationsEnabled) {
                HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp), color = ArcTheme.colors.borderSubtle)

                SettingsToggleRow(
                    title = "Task Reminders",
                    subtitle = "Upcoming task and deadline alerts",
                    checked = state.taskRemindersEnabled,
                    onCheckedChange = { viewModel.setTaskRemindersEnabled(it) }
                )

                SettingsToggleRow(
                    title = "Habit Reminders",
                    subtitle = "Daily streak and habit completion alerts",
                    checked = state.habitRemindersEnabled,
                    onCheckedChange = { viewModel.setHabitRemindersEnabled(it) }
                )

                SettingsToggleRow(
                    title = "Expense Reminders",
                    subtitle = "Evening budget and transaction logging prompts",
                    checked = state.expenseRemindersEnabled,
                    onCheckedChange = { viewModel.setExpenseRemindersEnabled(it) }
                )

                SettingsInfoRow(title = "Daily Reminder Time", value = state.remTime)
                SettingsInfoRow(title = "Evening Check-in", value = state.eveningCheckinTime)
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Money Tracker & Privacy Section
            SettingsSectionHeader(title = "Money Tracker", icon = Icons.Default.Security)
            SettingsToggleRow(
                title = "Automatic Expense Detection",
                subtitle = "Analyze incoming SMS locally without network transmission",
                checked = state.isMoneyDetectionEnabled,
                onCheckedChange = { viewModel.setMoneyDetectionEnabled(it) }
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Vault Security Section
            SettingsSectionHeader(title = "Secret Vault Security", icon = Icons.Default.Lock)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(ArcTheme.colors.surface)
                    .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(12.dp))
                    .clickable { onNavigateToVault?.invoke() }
                    .padding(16.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Secret Notes Security",
                            style = ArcTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                            color = ArcTheme.colors.textPrimary
                        )
                        Text(
                            text = "AES-256-GCM authenticated vault, hardware Keystore keys, PIN & Biometrics",
                            style = ArcTheme.typography.bodySmall,
                            color = ArcTheme.colors.textSecondary
                        )
                    }
                    Icon(
                        imageVector = Icons.Default.Lock,
                        contentDescription = "Vault",
                        tint = ArcTheme.colors.accent,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Local Data Management Section
            SettingsSectionHeader(title = "Backup & Maintenance", icon = Icons.Default.Storage)
            DataStatisticsCard(
                taskCount = state.taskCount,
                habitCount = state.habitCount,
                transactionCount = state.transactionCount,
                secretNoteCount = state.secretNoteCount
            )

            Spacer(modifier = Modifier.height(12.dp))

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(ArcTheme.colors.surface)
                    .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(12.dp))
                    .clickable { showClearCacheDialog = true }
                    .padding(16.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.DeleteSweep,
                        contentDescription = "Clear Cache",
                        tint = ArcTheme.colors.danger,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = "Clear Local Temporary Cache",
                            style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                            color = ArcTheme.colors.danger
                        )
                        Text(
                            text = "Safely cleans temporary runtime indexes without removing user data",
                            style = ArcTheme.typography.bodySmall,
                            color = ArcTheme.colors.textSecondary
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Account & Session Section
            SettingsSectionHeader(title = "Account & Session", icon = Icons.Default.AccountCircle)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(ArcTheme.colors.surface)
                    .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(12.dp))
                    .clickable { showSignOutDialog = true }
                    .padding(16.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ExitToApp,
                        contentDescription = "Sign Out",
                        tint = ArcTheme.colors.danger,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "Sign Out of ARC",
                        style = ArcTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                        color = ArcTheme.colors.danger
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // App Information Section
            SettingsSectionHeader(title = "About ARC", icon = Icons.Default.Info)
            AppInfoCard()

            Spacer(modifier = Modifier.height(32.dp))
        }
    }

    if (showClearCacheDialog) {
        AlertDialog(
            onDismissRequest = { showClearCacheDialog = false },
            title = { Text("Clear Local Cache?") },
            text = { Text("This will clean temporary database queries and memory caches. Your saved tasks, habits, transactions, and secret notes will not be deleted.") },
            confirmButton = {
                TextButton(onClick = {
                    showClearCacheDialog = false
                    viewModel.clearLocalCache()
                }) {
                    Text("Clear Cache", color = ArcTheme.colors.danger)
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearCacheDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    if (showSignOutDialog) {
        AlertDialog(
            onDismissRequest = { showSignOutDialog = false },
            title = { Text("Sign Out of ARC?") },
            text = { Text("Are you sure you want to sign out? Your local records will remain safely persisted on this device.") },
            confirmButton = {
                TextButton(onClick = {
                    showSignOutDialog = false
                    viewModel.signOut(onSignedOut)
                }) {
                    Text("Sign Out", color = ArcTheme.colors.danger)
                }
            },
            dismissButton = {
                TextButton(onClick = { showSignOutDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun SettingsProfileCard(
    displayName: String,
    email: String,
    userId: String,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(ArcTheme.colors.surface)
            .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(16.dp))
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(ArcTheme.colors.accent),
                contentAlignment = Alignment.Center
            ) {
                val initial = displayName.firstOrNull()?.uppercaseChar()?.toString() ?: "A"
                Text(
                    text = initial,
                    style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = Color.White
                )
            }
            Spacer(modifier = Modifier.width(16.dp))
            Column {
                Text(
                    text = displayName,
                    style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = ArcTheme.colors.textPrimary
                )
                Text(
                    text = email,
                    style = ArcTheme.typography.bodySmall,
                    color = ArcTheme.colors.textSecondary
                )
                Text(
                    text = "ID: $userId",
                    style = ArcTheme.typography.labelSmall,
                    color = ArcTheme.colors.textSecondary.copy(alpha = 0.7f)
                )
            }
        }
    }
}

@Composable
private fun SettingsSectionHeader(
    title: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = ArcTheme.colors.accent,
            modifier = Modifier.size(18.dp)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = title,
            style = ArcTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
            color = ArcTheme.colors.accent
        )
    }
}

@Composable
private fun AppearanceSelector(
    currentTheme: String,
    onThemeSelected: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        val options = listOf("dark" to "Dark", "light" to "Light", "system" to "System")
        options.forEach { (mode, label) ->
            val isSelected = currentTheme == mode
            FilterChip(
                selected = isSelected,
                onClick = { onThemeSelected(mode) },
                label = { Text(label) },
                leadingIcon = {
                    if (isSelected) {
                        Icon(
                            imageVector = Icons.Default.Check,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = ArcTheme.colors.accent,
                    selectedLabelColor = Color.White,
                    containerColor = ArcTheme.colors.surface,
                    labelColor = ArcTheme.colors.textPrimary
                )
            )
        }
    }
}

@Composable
private fun SettingsToggleRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = ArcTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Medium),
                color = ArcTheme.colors.textPrimary
            )
            Text(
                text = subtitle,
                style = ArcTheme.typography.bodySmall,
                color = ArcTheme.colors.textSecondary
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = ArcTheme.colors.accent
            )
        )
    }
}

@Composable
private fun SettingsInfoRow(
    title: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            style = ArcTheme.typography.bodyMedium,
            color = ArcTheme.colors.textPrimary
        )
        Text(
            text = value,
            style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            color = ArcTheme.colors.accent
        )
    }
}

@Composable
private fun DataStatisticsCard(
    taskCount: Int,
    habitCount: Int,
    transactionCount: Int,
    secretNoteCount: Int,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(ArcTheme.colors.surface)
            .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(12.dp))
            .padding(16.dp)
    ) {
        Column {
            Text(
                text = "Room SQLite Storage Footprint",
                style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = ArcTheme.colors.textPrimary
            )
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                StatItem(label = "Tasks", count = taskCount)
                StatItem(label = "Habits", count = habitCount)
                StatItem(label = "Expenses", count = transactionCount)
                StatItem(label = "Vault Notes", count = secretNoteCount)
            }
        }
    }
}

@Composable
private fun StatItem(label: String, count: Int) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = "$count",
            style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            color = ArcTheme.colors.accent
        )
        Text(
            text = label,
            style = ArcTheme.typography.labelSmall,
            color = ArcTheme.colors.textSecondary
        )
    }
}

@Composable
private fun AppInfoCard(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(ArcTheme.colors.surface)
            .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(12.dp))
            .padding(16.dp)
    ) {
        Column {
            Text(
                text = "ARC — Native Productivity & Finance",
                style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = ArcTheme.colors.textPrimary
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Version: 2.0.0 (Native Release Candidate)",
                style = ArcTheme.typography.bodySmall,
                color = ArcTheme.colors.textSecondary
            )
            Text(
                text = "Build: 2026.1 • Architecture: Kotlin + Jetpack Compose + Room",
                style = ArcTheme.typography.bodySmall,
                color = ArcTheme.colors.textSecondary
            )
            Text(
                text = "Status: Local-Only Development Mode (Zero Cloud Leakage)",
                style = ArcTheme.typography.bodySmall.copy(color = ArcTheme.colors.accent),
            )
        }
    }
}
