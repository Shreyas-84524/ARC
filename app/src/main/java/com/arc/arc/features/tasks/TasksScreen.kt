package com.arc.arc.features.tasks

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.components.ArcConfirmationDialog
import com.arc.arc.core.designsystem.components.ArcEmptyState
import com.arc.arc.core.designsystem.components.ArcFilterChip
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.model.TaskConstants

@Composable
fun TasksScreen(
    viewModel: TasksViewModel,
    modifier: Modifier = Modifier,
) {
    val uiState by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    var isSortMenuOpen by remember { mutableStateOf(false) }
    var isCategoryMenuOpen by remember { mutableStateOf(false) }

    // Handle user feedback (undo completion)
    LaunchedEffect(uiState.userFeedbackMessage) {
        val message = uiState.userFeedbackMessage
        if (message != null) {
            val result = snackbarHostState.showSnackbar(
                message = message,
                actionLabel = "Undo",
                duration = SnackbarDuration.Short,
            )
            if (result == SnackbarResult.ActionPerformed) {
                viewModel.undoToggle()
            }
            viewModel.clearFeedbackMessage()
        }
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        modifier = modifier.fillMaxSize(),
        containerColor = ArcTheme.colors.background,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        floatingActionButton = {
            FloatingActionButton(
                onClick = viewModel::openCreateTask,
                containerColor = ArcTheme.colors.accent,
                contentColor = Color(0xFF111827),
                shape = CircleShape,
                elevation = androidx.compose.material3.FloatingActionButtonDefaults.elevation(defaultElevation = 6.dp),
            ) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "Create Task",
                    modifier = Modifier.size(26.dp),
                )
            }
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            // Task Statistics Strip
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = ArcDimens.ScreenHorizontalPadding, vertical = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                StatBadge(
                    label = "Total",
                    value = uiState.statistics.totalTasks.toString(),
                    onClick = { viewModel.setStatusFilter(TaskStatusFilter.ALL) },
                    modifier = Modifier.weight(1f),
                )
                StatBadge(
                    label = "Pending",
                    value = uiState.statistics.pendingTasks.toString(),
                    onClick = { viewModel.setStatusFilter(TaskStatusFilter.PENDING) },
                    modifier = Modifier.weight(1f),
                )
                StatBadge(
                    label = "Overdue",
                    value = uiState.statistics.overdueTasks.toString(),
                    isError = uiState.statistics.overdueTasks > 0,
                    onClick = { viewModel.setStatusFilter(TaskStatusFilter.OVERDUE) },
                    modifier = Modifier.weight(1f),
                )
            }

            Spacer(modifier = Modifier.height(4.dp))

            // Sort & Category Dropdowns Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = ArcDimens.ScreenHorizontalPadding),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                // Sort Dropdown Button
                Box(modifier = Modifier.weight(1f)) {
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = ArcTheme.colors.surface,
                        border = androidx.compose.foundation.BorderStroke(1.dp, ArcTheme.colors.borderSubtle),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { isSortMenuOpen = true },
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column {
                                Text("Sort By", fontSize = 10.sp, color = ArcTheme.colors.textMuted)
                                Text(uiState.sortOption.displayName, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = ArcTheme.colors.textPrimary)
                            }
                            Icon(
                                imageVector = Icons.Default.ArrowDropDown,
                                contentDescription = null,
                                tint = ArcTheme.colors.textSecondary,
                            )
                        }
                    }
                    DropdownMenu(
                        expanded = isSortMenuOpen,
                        onDismissRequest = { isSortMenuOpen = false },
                        modifier = Modifier.background(ArcTheme.colors.surface),
                    ) {
                        TaskSort.entries.forEach { sort ->
                            DropdownMenuItem(
                                text = { Text(sort.displayName, color = ArcTheme.colors.textPrimary) },
                                onClick = {
                                    viewModel.setSortOption(sort)
                                    isSortMenuOpen = false
                                },
                            )
                        }
                    }
                }

                // Category Dropdown Button
                Box(modifier = Modifier.weight(1f)) {
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = ArcTheme.colors.surface,
                        border = androidx.compose.foundation.BorderStroke(1.dp, ArcTheme.colors.borderSubtle),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { isCategoryMenuOpen = true },
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column {
                                Text("Category", fontSize = 10.sp, color = ArcTheme.colors.textMuted)
                                Text(uiState.categoryFilter ?: "All", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = ArcTheme.colors.textPrimary)
                            }
                            Icon(
                                imageVector = Icons.Default.ArrowDropDown,
                                contentDescription = null,
                                tint = ArcTheme.colors.textSecondary,
                            )
                        }
                    }
                    DropdownMenu(
                        expanded = isCategoryMenuOpen,
                        onDismissRequest = { isCategoryMenuOpen = false },
                        modifier = Modifier.background(ArcTheme.colors.surface),
                    ) {
                        DropdownMenuItem(
                            text = { Text("All Categories", color = ArcTheme.colors.textPrimary) },
                            onClick = {
                                viewModel.setCategoryFilter(null)
                                isCategoryMenuOpen = false
                            },
                        )
                        TaskConstants.CATEGORIES.forEach { category ->
                            DropdownMenuItem(
                                text = { Text(category, color = ArcTheme.colors.textPrimary) },
                                onClick = {
                                    viewModel.setCategoryFilter(category)
                                    isCategoryMenuOpen = false
                                },
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Horizontal Filter Chips (All Tasks, Pending, Upcoming, Overdue, Completed)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = ArcDimens.ScreenHorizontalPadding),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                TaskStatusFilter.entries.forEach { filter ->
                    ArcFilterChip(
                        label = filter.displayName,
                        selected = uiState.statusFilter == filter,
                        onClick = { viewModel.setStatusFilter(filter) },
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Task List or Empty State
            if (uiState.filteredTasks.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    ArcEmptyState(
                        icon = Icons.Default.Checklist,
                        title = "No tasks found",
                        description = "Add your first task to stay organized and boost productivity.",
                        actionLabel = "Create Task",
                        onAction = viewModel::openCreateTask,
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = ArcDimens.ScreenHorizontalPadding,
                        end = ArcDimens.ScreenHorizontalPadding,
                        top = 4.dp,
                        bottom = 88.dp, // Space for FAB
                    ),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    items(
                        items = uiState.filteredTasks,
                        key = { it.id },
                    ) { task ->
                        TaskCard(
                            task = task,
                            onToggleCompletion = { viewModel.toggleTask(task.id) },
                            onClick = { viewModel.openEditTask(task) },
                            onDeleteClick = { viewModel.requestDelete(task) },
                        )
                    }
                }
            }
        }
    }

    // Task Editor Sheet
    if (uiState.isEditorOpen) {
        TaskEditorSheet(
            taskToEdit = uiState.editingTask,
            onSave = { title, desc, cat, prio, labels, dueD, dueT, rem ->
                viewModel.saveTask(title, desc, cat, prio, labels, dueD, dueT, rem)
            },
            onDismiss = viewModel::closeEditor,
        )
    }

    // Delete Confirmation Dialog
    if (uiState.isDeleteDialogOpen && uiState.deletingTask != null) {
        ArcConfirmationDialog(
            title = "Delete Task",
            message = "Are you sure you want to delete \"${uiState.deletingTask!!.title}\"? This cannot be undone.",
            confirmLabel = "Delete",
            isDanger = true,
            onConfirm = viewModel::confirmDelete,
            onDismiss = viewModel::dismissDeleteDialog,
        )
    }
}

@Composable
private fun StatBadge(
    label: String,
    value: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isError: Boolean = false,
) {
    val bgColor = if (isError) ArcTheme.colors.danger.copy(alpha = 0.12f) else ArcTheme.colors.card
    val borderColor = if (isError) ArcTheme.colors.danger.copy(alpha = 0.35f) else ArcTheme.colors.borderSubtle
    val valueColor = if (isError) ArcTheme.colors.danger else ArcTheme.colors.textPrimary

    Surface(
        shape = RoundedCornerShape(12.dp),
        color = bgColor,
        border = androidx.compose.foundation.BorderStroke(1.dp, borderColor),
        modifier = modifier.clickable(onClick = onClick),
    ) {
        Column(
            modifier = Modifier.padding(vertical = 10.dp, horizontal = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = value,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = valueColor,
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = label,
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                color = if (isError) ArcTheme.colors.danger else ArcTheme.colors.textMuted,
            )
        }
    }
}
