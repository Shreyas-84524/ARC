package com.arc.arc.features.dashboard

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AttachMoney
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CheckBox
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.QueryBuilder
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.components.ArcCard
import com.arc.arc.core.designsystem.components.ArcEmptyState
import com.arc.arc.core.designsystem.components.ArcLoadingState
import com.arc.arc.core.designsystem.components.ArcPriorityBadge
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TaskPriority
import com.arc.arc.core.utilities.CurrencyFormatter
import java.text.SimpleDateFormat

@Composable
fun DashboardScreen(
    viewModel: DashboardViewModel,
    onNavigateToTasks: () -> Unit,
    onNavigateToHabits: () -> Unit,
    onNavigateToMoney: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val state by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    val configuration = LocalConfiguration.current
    val locale = androidx.core.os.ConfigurationCompat.getLocales(configuration)[0] ?: java.util.Locale.US
    val activityDateFormat = remember(locale) { SimpleDateFormat("MMM d, h:mm a", locale) }
    val deadlineDateFormat = remember(locale) { SimpleDateFormat("MMM d", locale) }

    LaunchedEffect(state.userMessage) {
        state.userMessage?.let { msg ->
            snackbarHostState.showSnackbar(msg)
            viewModel.clearUserMessage()
        }
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = ArcTheme.colors.background,
        modifier = modifier.fillMaxSize(),
    ) { paddingValues ->
        if (state.isLoading) {
            ArcLoadingState()
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentPadding = PaddingValues(
                    start = ArcDimens.SpacingLg,
                    end = ArcDimens.SpacingLg,
                    top = ArcDimens.SpacingMd,
                    bottom = ArcDimens.SpacingXl,
                ),
                verticalArrangement = Arrangement.spacedBy(ArcDimens.SpacingLg),
            ) {
                // 1. Today's Progress Card
                item(key = "progress_card") {
                    ProgressOverviewCard(
                        state = state,
                    )
                }

                // 2. Productivity Score Banner
                item(key = "score_banner") {
                    ProductivityScoreBanner(
                        score = state.productivityScore,
                    )
                }

                // 3. Reference-aligned 2 x 2 quick metrics grid.
                item(key = "metrics_row") {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            MetricCard(
                                title = "Remaining Budget",
                                value = CurrencyFormatter.formatPaise(state.remainingBudgetPaise),
                                subtitle = "Monthly balance",
                                icon = Icons.Default.AttachMoney,
                                accentColor = ArcTheme.colors.accent,
                                modifier = Modifier.weight(1f),
                            )
                            MetricCard(
                                title = "Daily Streak",
                                value = "${state.maxStreakDays} Days",
                                subtitle = "Keep it going!",
                                icon = Icons.Default.LocalFireDepartment,
                                accentColor = ArcTheme.colors.accent,
                                modifier = Modifier.weight(1f),
                            )
                        }
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            MetricCard(
                                title = "Monthly Expenses",
                                value = CurrencyFormatter.formatPaise(state.monthlyExpensesPaise),
                                subtitle = "Spending so far",
                                icon = Icons.Default.QueryBuilder,
                                accentColor = ArcTheme.colors.danger,
                                modifier = Modifier.weight(1f),
                            )
                            MetricCard(
                                title = "Tasks Done",
                                value = "${state.completedTasksCount}/${state.totalTasksCount}",
                                subtitle = "All time",
                                icon = Icons.Default.CheckCircle,
                                accentColor = ArcTheme.colors.accent,
                                modifier = Modifier.weight(1f),
                            )
                        }
                    }
                }

                // 4. Today's Tasks Checklist
                item(key = "tasks_section") {
                    SectionHeader(
                        title = "Today's Tasks",
                        actionLabel = "View All",
                        onActionClick = onNavigateToTasks,
                    )

                    Spacer(modifier = Modifier.height(ArcDimens.SpacingSm))

                    if (state.todayTasks.isEmpty()) {
                        ArcCard(modifier = Modifier.fillMaxWidth()) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(ArcDimens.SpacingMd),
                            ) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = null,
                                    tint = ArcTheme.colors.accent,
                                    modifier = Modifier.size(24.dp),
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Text(
                                    text = "All caught up for today! No pending tasks.",
                                    style = ArcTheme.typography.bodyMedium,
                                    color = ArcTheme.colors.textSecondary,
                                )
                            }
                        }
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            state.todayTasks.take(4).forEach { task ->
                                TodayTaskRow(
                                    task = task,
                                    onToggle = { viewModel.toggleTask(task.id) },
                                )
                            }
                        }
                    }
                }

                // 5. Upcoming Deadlines
                if (state.upcomingDeadlines.isNotEmpty()) {
                    item(key = "upcoming_section") {
                        SectionHeader(
                            title = "Upcoming Deadlines",
                            actionLabel = null,
                            onActionClick = null,
                        )

                        Spacer(modifier = Modifier.height(ArcDimens.SpacingSm))

                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            state.upcomingDeadlines.forEach { item ->
                                UpcomingTaskCard(
                                    item = item,
                                    dateFormat = deadlineDateFormat,
                                )
                            }
                        }
                    }
                }

                // 6. Recent Activity Feed
                item(key = "activity_section") {
                    SectionHeader(
                        title = "Recent Activity",
                        actionLabel = null,
                        onActionClick = null,
                    )

                    Spacer(modifier = Modifier.height(ArcDimens.SpacingSm))

                    if (state.recentActivities.isEmpty()) {
                        ArcCard(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                text = "No recent activity recorded yet.",
                                style = ArcTheme.typography.bodyMedium,
                                color = ArcTheme.colors.textSecondary,
                                modifier = Modifier.padding(ArcDimens.SpacingMd),
                            )
                        }
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            state.recentActivities.forEach { activity ->
                                ActivityRow(
                                    activity = activity,
                                    dateFormat = activityDateFormat,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(
    title: String,
    actionLabel: String?,
    onActionClick: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
        modifier = modifier.fillMaxWidth(),
    ) {
        Text(
            text = title,
            style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            color = ArcTheme.colors.textPrimary,
        )

        if (actionLabel != null && onActionClick != null) {
            TextButton(
                onClick = onActionClick,
                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = actionLabel,
                        style = ArcTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = ArcTheme.colors.accent,
                    )
                    Spacer(modifier = Modifier.width(2.dp))
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = ArcTheme.colors.accent,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun ProgressOverviewCard(
    state: DashboardUiState,
    modifier: Modifier = Modifier,
) {
    ArcCard(modifier = modifier.fillMaxWidth()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Today's Progress",
                    style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = ArcTheme.colors.textPrimary,
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "Completed: ${state.completedTodayTasksCount} / ${state.totalTodayTasksCount} Tasks",
                    style = ArcTheme.typography.bodyMedium,
                    color = ArcTheme.colors.textSecondary,
                )
                Text(
                    text = "Completed: ${state.completedTodayHabitsCount} / ${state.totalHabitsCount} Habits",
                    style = ArcTheme.typography.bodyMedium,
                    color = ArcTheme.colors.textSecondary,
                )
            }

            Spacer(modifier = Modifier.width(16.dp))

            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier.size(68.dp),
            ) {
                CircularProgressIndicator(
                    progress = { state.progressPercentage },
                    color = ArcTheme.colors.accent,
                    trackColor = Color.Black.copy(alpha = 0.28f),
                    strokeWidth = 6.dp,
                    modifier = Modifier.fillMaxSize(),
                )
                Text(
                    text = "${(state.progressPercentage * 100).toInt()}%",
                    style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                    color = ArcTheme.colors.textPrimary,
                )
            }
        }
    }
}

@Composable
private fun ProductivityScoreBanner(
    score: Int,
    modifier: Modifier = Modifier,
) {
    Surface(
        color = ArcTheme.colors.accent.copy(alpha = 0.12f),
        shape = RoundedCornerShape(ArcDimens.RadiusCard),
        modifier = modifier.fillMaxWidth(),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 14.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.weight(1f),
            ) {
                Icon(
                    imageVector = Icons.Default.AutoAwesome,
                    contentDescription = null,
                    tint = ArcTheme.colors.accent,
                    modifier = Modifier.size(24.dp),
                )
                Spacer(modifier = Modifier.width(12.dp))
                Column {
                    Text(
                        text = "Productivity Score",
                        style = ArcTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                        color = ArcTheme.colors.textPrimary,
                    )
                    Text(
                        text = "Based on tasks & habit completion",
                        style = ArcTheme.typography.labelSmall,
                        color = ArcTheme.colors.textSecondary,
                    )
                }
            }

            Surface(
                color = ArcTheme.colors.accent,
                shape = RoundedCornerShape(20.dp),
            ) {
                Text(
                    text = "$score / 100",
                    style = ArcTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                    color = Color.Black,
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
                )
            }
        }
    }
}

@Composable
private fun MetricCard(
    title: String,
    value: String,
    subtitle: String,
    icon: ImageVector,
    accentColor: Color,
    modifier: Modifier = Modifier,
) {
    ArcCard(modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = title,
                    style = ArcTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                    color = ArcTheme.colors.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = accentColor,
                    modifier = Modifier.size(16.dp),
                )
            }
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = value,
                style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = ArcTheme.colors.textPrimary,
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = ArcTheme.typography.labelSmall.copy(fontSize = 10.sp),
                color = ArcTheme.colors.textMuted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun TodayHabitCard(
    item: DashboardHabitItem,
    onToggle: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val habitColor = Color(item.habit.colorValue.toInt())
    val isDone = item.isCompletedToday

    val buttonBg by animateColorAsState(
        targetValue = if (isDone) habitColor else Color.Transparent,
        animationSpec = tween(durationMillis = 200),
        label = "buttonBg",
    )

    ArcCard(
        modifier = modifier
            .width(180.dp)
            .clickable { onToggle(!isDone) },
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(buttonBg)
                    .border(
                        width = 2.dp,
                        color = if (isDone) habitColor else ArcTheme.colors.borderSubtle,
                        shape = CircleShape,
                    ),
            ) {
                if (isDone) {
                    Icon(
                        imageVector = Icons.Default.Check,
                        contentDescription = null,
                        tint = Color.Black,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.width(10.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.habit.name,
                    style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                    color = ArcTheme.colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = item.habit.category,
                    style = ArcTheme.typography.labelSmall.copy(fontSize = 11.sp),
                    color = ArcTheme.colors.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun TodayTaskRow(
    task: TaskModel,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val priorityColor = when (task.priorityEnum) {
        TaskPriority.HIGH -> ArcTheme.colors.priorityHigh
        TaskPriority.MUST -> ArcTheme.colors.priorityMust
        TaskPriority.LOW -> ArcTheme.colors.priorityLow
    }

    ArcCard(
        modifier = modifier
            .fillMaxWidth()
            .clickable { onToggle() },
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(24.dp)
                    .clip(CircleShape)
                    .background(if (task.completed) priorityColor else Color.Transparent)
                    .border(
                        width = 2.dp,
                        color = priorityColor,
                        shape = CircleShape,
                    ),
            ) {
                if (task.completed) {
                    Icon(
                        imageVector = Icons.Default.Check,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(14.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = task.title,
                    style = ArcTheme.typography.bodyMedium.copy(
                        fontWeight = FontWeight.SemiBold,
                        textDecoration = if (task.completed) TextDecoration.LineThrough else null,
                    ),
                    color = if (task.completed) ArcTheme.colors.textDisabled else ArcTheme.colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = "${task.category} • ${task.displayPriority}",
                    style = ArcTheme.typography.labelSmall,
                    color = ArcTheme.colors.textSecondary,
                )
            }

            ArcPriorityBadge(priority = task.priorityEnum)
        }
    }
}

@Composable
private fun UpcomingTaskCard(
    item: DashboardTaskItem,
    dateFormat: SimpleDateFormat,
    modifier: Modifier = Modifier,
) {
    val dateText = item.task.dueDate?.let { dateFormat.format(it) } ?: ""

    ArcCard(modifier = modifier.fillMaxWidth()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
        ) {
            Icon(
                imageVector = Icons.Default.CalendarMonth,
                contentDescription = null,
                tint = ArcTheme.colors.accent,
                modifier = Modifier.size(22.dp),
            )

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.task.title,
                    style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                    color = ArcTheme.colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = "Due in ${item.daysUntilDue} day${if (item.daysUntilDue > 1) "s" else ""} ($dateText)",
                    style = ArcTheme.typography.labelSmall,
                    color = ArcTheme.colors.textSecondary,
                )
            }

            ArcPriorityBadge(priority = item.task.priorityEnum)
        }
    }
}

@Composable
private fun ActivityRow(
    activity: DashboardActivityItem,
    dateFormat: SimpleDateFormat,
    modifier: Modifier = Modifier,
) {
    val (icon, iconColor) = when (activity.type) {
        DashboardActivityType.TASK -> Pair(Icons.Default.CheckBox, Color(0xFF1890FF))
        DashboardActivityType.HABIT -> Pair(Icons.Default.LocalFireDepartment, Color(0xFFF97316))
        DashboardActivityType.TRANSACTION -> Pair(Icons.Default.AttachMoney, Color(0xFF10B981))
    }

    ArcCard(modifier = modifier.fillMaxWidth()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
        ) {
            Surface(
                color = iconColor.copy(alpha = 0.12f),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.size(34.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = iconColor,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = activity.title,
                    style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = ArcTheme.colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = "${activity.subtitle} • ${dateFormat.format(activity.timestamp)}",
                    style = ArcTheme.typography.labelSmall,
                    color = ArcTheme.colors.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun FinancialDashboardCard(
    monthlyExpensesPaise: Long,
    monthlyBudgetPaise: Long,
    remainingBudgetPaise: Long,
    onNavigateToMoney: () -> Unit,
    modifier: Modifier = Modifier,
) {
    ArcCard(
        modifier = modifier
            .fillMaxWidth()
            .clickable { onNavigateToMoney() },
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Surface(
                        color = Color(0xFF10B981).copy(alpha = 0.15f),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.size(36.dp),
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Default.AttachMoney,
                                contentDescription = null,
                                tint = Color(0xFF10B981),
                                modifier = Modifier.size(20.dp),
                            )
                        }
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = "Monthly Finances",
                            style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = ArcTheme.colors.textPrimary,
                        )
                        Text(
                            text = "Expenses & budget tracking",
                            style = ArcTheme.typography.labelSmall,
                            color = ArcTheme.colors.textSecondary,
                        )
                    }
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "View",
                        style = ArcTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = ArcTheme.colors.accent,
                    )
                    Spacer(modifier = Modifier.width(2.dp))
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = ArcTheme.colors.accent,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column {
                    Text(
                        text = "Spent this month",
                        style = ArcTheme.typography.labelSmall,
                        color = ArcTheme.colors.textSecondary,
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = CurrencyFormatter.formatPaise(monthlyExpensesPaise),
                        style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = ArcTheme.colors.textPrimary,
                    )
                }

                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        text = if (monthlyBudgetPaise > 0L) "Remaining Budget" else "Budget Status",
                        style = ArcTheme.typography.labelSmall,
                        color = ArcTheme.colors.textSecondary,
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    if (monthlyBudgetPaise > 0L) {
                        val isOver = remainingBudgetPaise < 0L
                        Text(
                            text = CurrencyFormatter.formatPaise(remainingBudgetPaise),
                            style = ArcTheme.typography.titleMedium.copy(
                                fontWeight = FontWeight.Bold,
                                color = if (isOver) ArcTheme.colors.danger else ArcTheme.colors.success,
                            ),
                        )
                    } else {
                        Text(
                            text = "No budget set",
                            style = ArcTheme.typography.bodyMedium.copy(color = ArcTheme.colors.textSecondary),
                        )
                    }
                }
            }

            if (monthlyBudgetPaise > 0L) {
                Spacer(modifier = Modifier.height(10.dp))
                val spentProgress = (monthlyExpensesPaise.toFloat() / monthlyBudgetPaise.toFloat()).coerceIn(0f, 1f)
                val isOverBudget = monthlyExpensesPaise > monthlyBudgetPaise

                LinearProgressIndicator(
                    progress = { spentProgress },
                    color = if (isOverBudget) ArcTheme.colors.danger else ArcTheme.colors.accent,
                    trackColor = ArcTheme.colors.surfaceVariant,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp)),
                )
            }
        }
    }
}
