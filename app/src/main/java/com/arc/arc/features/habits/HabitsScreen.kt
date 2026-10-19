package com.arc.arc.features.habits

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CheckBox
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.components.ArcCard
import com.arc.arc.core.designsystem.components.ArcConfirmationDialog
import com.arc.arc.core.designsystem.components.ArcEmptyState
import com.arc.arc.core.designsystem.components.ArcFilterChip
import com.arc.arc.core.designsystem.components.ArcLoadingState
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.features.habits.engine.HabitGoalType

@Composable
fun HabitsScreen(
    viewModel: HabitsViewModel,
    modifier: Modifier = Modifier,
) {
    val state by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    var selectedTab by remember { mutableStateOf(0) }

    LaunchedEffect(state.userMessage) {
        state.userMessage?.let { msg ->
            snackbarHostState.showSnackbar(msg)
            viewModel.clearUserMessage()
        }
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        snackbarHost = { SnackbarHost(snackbarHostState) },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { viewModel.openCreateEditor() },
                containerColor = ArcTheme.colors.accent,
                contentColor = Color.Black,
                shape = CircleShape,
                modifier = Modifier.semantics { contentDescription = "Add New Habit" },
            ) {
                Icon(imageVector = Icons.Default.Add, contentDescription = null)
            }
        },
        containerColor = ArcTheme.colors.background,
        modifier = modifier.fillMaxSize(),
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
        ) {
            if (state.isLoading && state.allHabits.isEmpty()) {
                ArcLoadingState()
            } else {
                Column(modifier = Modifier.fillMaxSize()) {
                    HabitModeSwitcher(
                        selectedTab = selectedTab,
                        onSelected = { selectedTab = it },
                        modifier = Modifier.padding(horizontal = ArcDimens.SpacingLg, vertical = ArcDimens.SpacingSm),
                    )
                    if (selectedTab == 1) {
                        HabitAnalyticsContent(
                            state = state,
                            onGoalTypeChanged = viewModel::setGoalType,
                            modifier = Modifier.fillMaxSize(),
                        )
                        return@Column
                    }
                    // 1. Top Summary Banner with Progress and Goal Switcher
                    HabitsSummaryCard(
                        summary = state.summary,
                        selectedGoalType = state.selectedGoalType,
                        onGoalTypeChanged = { viewModel.setGoalType(it) },
                        modifier = Modifier.padding(
                            horizontal = ArcDimens.SpacingLg,
                            vertical = ArcDimens.SpacingSm,
                        ),
                    )

                    // 2. Category Filter Chips Row
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState())
                            .padding(horizontal = ArcDimens.SpacingLg, vertical = ArcDimens.SpacingSm),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        ArcFilterChip(
                            label = "All Habits",
                            selected = state.selectedCategory == null,
                            onClick = { viewModel.selectCategory(null) },
                        )
                        HabitConstants.CATEGORIES.forEach { category ->
                            ArcFilterChip(
                                label = category,
                                selected = state.selectedCategory == category,
                                onClick = { viewModel.selectCategory(category) },
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(ArcDimens.SpacingSm))

                    // 3. Habits List or Empty State
                    if (state.filteredHabits.isEmpty()) {
                        ArcEmptyState(
                            icon = Icons.Default.TrackChanges,
                            title = if (state.allHabits.isEmpty()) "No habits tracking yet" else "No Habits Found",
                            description = if (state.allHabits.isEmpty()) {
                                "Build consistency by creating your first daily habit!"
                            } else {
                                "No habits match the selected '${state.selectedCategory}' category filter."
                            },
                            actionLabel = if (state.allHabits.isEmpty()) "Create Habit" else null,
                            onAction = if (state.allHabits.isEmpty()) viewModel::openCreateEditor else null,
                        )
                    } else {
                        LazyColumn(
                            contentPadding = PaddingValues(
                                start = ArcDimens.SpacingLg,
                                end = ArcDimens.SpacingLg,
                                top = ArcDimens.SpacingSm,
                                bottom = 88.dp, // Space for FAB
                            ),
                            verticalArrangement = Arrangement.spacedBy(ArcDimens.SpacingMd),
                            modifier = Modifier.fillMaxSize(),
                        ) {
                            items(
                                items = state.filteredHabits,
                                key = { it.habit.id },
                            ) { itemState ->
                                HabitCard(
                                    state = itemState,
                                    onToggleToday = { completed ->
                                        viewModel.toggleHabitToday(itemState.habit.id, completed)
                                    },
                                    onEditClick = { viewModel.openEditEditor(itemState.habit) },
                                    onDeleteClick = { viewModel.confirmDeleteHabit(itemState.habit) },
                                )
                            }
                        }
                    }
                }
            }

            // Editor Sheet
            if (state.isEditorOpen) {
                HabitEditorSheet(
                    habitToEdit = state.editingHabit,
                    onDismiss = { viewModel.closeEditor() },
                    onSave = { name, category, color, reminder ->
                        viewModel.saveHabit(name, category, color, reminder)
                    },
                )
            }

            // Delete Confirmation Dialog
            state.habitToDelete?.let { habit ->
                ArcConfirmationDialog(
                    title = "Delete Habit",
                    message = "Are you sure you want to delete \"${habit.name}\"? All check-in history for this habit will be permanently deleted.",
                    confirmLabel = "Delete",
                    cancelLabel = "Cancel",
                    onConfirm = { viewModel.deleteHabit() },
                    onDismiss = { viewModel.dismissDeleteDialog() },
                    isDanger = true,
                )
            }
        }
    }
}

@Composable
private fun HabitModeSwitcher(
    selectedTab: Int,
    onSelected: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        color = ArcTheme.colors.surface,
        shape = RoundedCornerShape(18.dp),
        modifier = modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(5.dp)) {
            listOf("Check-in" to Icons.Default.CheckBox, "Analytics" to Icons.Default.BarChart).forEachIndexed { index, item ->
                val selected = selectedTab == index
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (selected) ArcTheme.colors.accent else Color.Transparent)
                        .clickable { onSelected(index) }
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
private fun HabitAnalyticsContent(
    state: HabitsUiState,
    onGoalTypeChanged: (HabitGoalType) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(start = 24.dp, end = 24.dp, top = 16.dp, bottom = 96.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Filter Goal Type", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = ArcTheme.colors.textPrimary)
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    HabitGoalType.entries.forEach { goal ->
                        ArcFilterChip(
                            label = goal.displayName,
                            selected = state.selectedGoalType == goal,
                            onClick = { onGoalTypeChanged(goal) },
                        )
                    }
                }
            }
        }
        item {
            ArcCard(Modifier.fillMaxWidth()) {
                Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("${state.selectedGoalType.displayName} Goal Compliance", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = ArcTheme.colors.textPrimary)
                    Spacer(Modifier.height(28.dp))
                    if (state.allHabits.isEmpty()) {
                        Text("No Habits Created Yet", color = ArcTheme.colors.textMuted)
                        Spacer(Modifier.height(44.dp))
                    } else {
                        CircularProgressIndicator(
                            progress = { state.summary.completionPercentage },
                            color = ArcTheme.colors.accent,
                            trackColor = ArcTheme.colors.surfaceVariant,
                            strokeWidth = 10.dp,
                            modifier = Modifier.size(120.dp),
                        )
                        Spacer(Modifier.height(24.dp))
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        AnalyticsInlineStat("${state.summary.completedCount}", "Completed", ArcTheme.colors.accent)
                        AnalyticsInlineStat("${state.summary.remainingCount}", "Remaining", ArcTheme.colors.textMuted)
                        AnalyticsInlineStat("${(state.summary.completionPercentage * 100).toInt()}%", "Completion %", ArcTheme.colors.accent)
                    }
                }
            }
        }
        item { Text("Goal Group Performance", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = ArcTheme.colors.textPrimary) }
        item {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    AnalyticsMetricCard("${state.summary.maxCurrentStreak} Days", "Current Streak", ArcTheme.colors.accent, Modifier.weight(1f))
                    AnalyticsMetricCard("${state.summary.maxLongestStreak} Days", "Longest Streak", Color(0xFFFFB020), Modifier.weight(1f))
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    AnalyticsMetricCard("${(state.summary.completionPercentage * 100).toInt()}%", "Completion Rate", ArcTheme.colors.accent, Modifier.weight(1f))
                    AnalyticsMetricCard("${state.allHabits.size}", "Total Habits", Color(0xFF29A9FF), Modifier.weight(1f))
                }
            }
        }
        item { Text("Individual Goal Performance", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = ArcTheme.colors.textPrimary) }
        if (state.allHabits.isEmpty()) {
            item {
                ArcCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.fillMaxWidth().padding(28.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Default.CheckBox, null, tint = ArcTheme.colors.textMuted, modifier = Modifier.size(44.dp))
                        Spacer(Modifier.height(12.dp))
                        Text("No habits created yet", fontWeight = FontWeight.Bold, color = ArcTheme.colors.textSecondary)
                        Text("Create habits to track individual performance.", color = ArcTheme.colors.textMuted, fontSize = 13.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun AnalyticsInlineStat(value: String, label: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, color = color, fontWeight = FontWeight.Bold, fontSize = 17.sp)
        Text(label, color = ArcTheme.colors.textMuted, fontSize = 11.sp)
    }
}

@Composable
private fun AnalyticsMetricCard(value: String, label: String, color: Color, modifier: Modifier = Modifier) {
    ArcCard(modifier.height(112.dp)) {
        Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.Center) {
            Text(value, fontSize = 21.sp, fontWeight = FontWeight.Bold, color = color)
            Spacer(Modifier.height(7.dp))
            Text(label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = ArcTheme.colors.textMuted)
        }
    }
}

@Composable
private fun HabitsSummaryCard(
    summary: com.arc.arc.features.habits.engine.HabitProgressSummary,
    selectedGoalType: HabitGoalType,
    onGoalTypeChanged: (HabitGoalType) -> Unit,
    modifier: Modifier = Modifier,
) {
    ArcCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(ArcDimens.SpacingMd)) {
            // Segmented Control: Daily / Weekly / Monthly
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(ArcTheme.colors.surfaceVariant, RoundedCornerShape(10.dp))
                    .padding(3.dp),
            ) {
                HabitGoalType.entries.forEach { goalType ->
                    val isSelected = selectedGoalType == goalType
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(8.dp))
                            .background(if (isSelected) ArcTheme.colors.surface else Color.Transparent)
                            .clickable { onGoalTypeChanged(goalType) }
                            .padding(vertical = 6.dp),
                    ) {
                        Text(
                            text = goalType.displayName,
                            style = ArcTheme.typography.labelMedium.copy(
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            ),
                            color = if (isSelected) ArcTheme.colors.accent else ArcTheme.colors.textSecondary,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(ArcDimens.SpacingMd))

            // Progress Ring and Stats
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                // Circular Progress
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.size(64.dp),
                ) {
                    CircularProgressIndicator(
                        progress = { summary.completionPercentage },
                        color = ArcTheme.colors.accent,
                        trackColor = ArcTheme.colors.surfaceVariant,
                        strokeWidth = 6.dp,
                        modifier = Modifier.fillMaxSize(),
                    )
                    Text(
                        text = "${(summary.completionPercentage * 100).toInt()}%",
                        style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                        color = ArcTheme.colors.textPrimary,
                    )
                }

                Spacer(modifier = Modifier.width(ArcDimens.SpacingLg))

                // Stats Columns
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "${summary.completedCount} Completed • ${summary.remainingCount} Remaining",
                        style = ArcTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                        color = ArcTheme.colors.textPrimary,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.LocalFireDepartment,
                            contentDescription = null,
                            tint = Color(0xFFF97316),
                            modifier = Modifier.size(16.dp),
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "Top Streak: ${summary.maxCurrentStreak}d (Best: ${summary.maxLongestStreak}d)",
                            style = ArcTheme.typography.bodySmall,
                            color = ArcTheme.colors.textSecondary,
                        )
                    }
                }
            }
        }
    }
}
