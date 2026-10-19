package com.arc.arc.features.habits

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.components.ArcCard
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme

@Composable
fun HabitCard(
    state: HabitItemUiState,
    onToggleToday: (Boolean) -> Unit,
    onEditClick: () -> Unit,
    onDeleteClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val habitColor = Color(state.habit.colorValue.toInt())
    val isCompleted = state.isCompletedToday

    val buttonColor by animateColorAsState(
        targetValue = if (isCompleted) habitColor else Color.Transparent,
        animationSpec = tween(durationMillis = 200),
        label = "buttonColor",
    )

    ArcCard(
        modifier = modifier
            .fillMaxWidth()
            .semantics { contentDescription = "Habit: ${state.habit.name}" },
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(ArcDimens.SpacingMd),
        ) {
            // Header Row: Checkbox, Name, Category, Edit/Delete
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                // Circular Check-in button
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(buttonColor)
                        .border(
                            width = 2.dp,
                            color = if (isCompleted) habitColor else ArcTheme.colors.borderSubtle,
                            shape = CircleShape,
                        )
                        .clickable { onToggleToday(!isCompleted) }
                        .semantics {
                            contentDescription = if (isCompleted) "Mark ${state.habit.name} incomplete" else "Mark ${state.habit.name} complete for today"
                        },
                ) {
                    if (isCompleted) {
                        Icon(
                            imageVector = Icons.Default.Check,
                            contentDescription = null,
                            tint = Color.Black,
                            modifier = Modifier.size(20.dp),
                        )
                    }
                }

                Spacer(modifier = Modifier.width(ArcDimens.SpacingMd))

                // Name, Category, Reminder
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = state.habit.name,
                        style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = ArcTheme.colors.textPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )

                    Spacer(modifier = Modifier.height(2.dp))

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Surface(
                            color = habitColor.copy(alpha = 0.15f),
                            shape = RoundedCornerShape(4.dp),
                        ) {
                            Text(
                                text = state.habit.category,
                                style = ArcTheme.typography.labelSmall.copy(fontSize = 11.sp),
                                color = habitColor,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            )
                        }

                        if (!state.habit.reminderTime.isNullOrBlank()) {
                            Spacer(modifier = Modifier.width(8.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Default.Alarm,
                                    contentDescription = null,
                                    tint = ArcTheme.colors.textSecondary,
                                    modifier = Modifier.size(12.dp),
                                )
                                Spacer(modifier = Modifier.width(3.dp))
                                Text(
                                    text = state.habit.reminderTime,
                                    style = ArcTheme.typography.labelSmall.copy(fontSize = 11.sp),
                                    color = ArcTheme.colors.textSecondary,
                                )
                            }
                        }
                    }
                }

                // Edit and Delete
                IconButton(
                    onClick = onEditClick,
                    modifier = Modifier.size(32.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.Edit,
                        contentDescription = "Edit Habit",
                        tint = ArcTheme.colors.textSecondary,
                        modifier = Modifier.size(16.dp),
                    )
                }

                IconButton(
                    onClick = onDeleteClick,
                    modifier = Modifier.size(32.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.Delete,
                        contentDescription = "Delete Habit",
                        tint = ArcTheme.colors.textSecondary,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.height(ArcDimens.SpacingSm))

            // Middle: Streak badge & 7-Day History
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth(),
            ) {
                // Streak badge
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .background(
                            color = if (state.metrics.currentStreak > 0) ArcTheme.colors.accent.copy(alpha = 0.12f) else ArcTheme.colors.surfaceVariant,
                            shape = RoundedCornerShape(12.dp),
                        )
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.LocalFireDepartment,
                        contentDescription = null,
                        tint = if (state.metrics.currentStreak > 0) Color(0xFFF97316) else ArcTheme.colors.textSecondary,
                        modifier = Modifier.size(14.dp),
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "${state.metrics.currentStreak}d streak",
                        style = ArcTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                        color = if (state.metrics.currentStreak > 0) ArcTheme.colors.textPrimary else ArcTheme.colors.textSecondary,
                    )
                    if (state.metrics.longestStreak > state.metrics.currentStreak) {
                        Text(
                            text = " (best: ${state.metrics.longestStreak}d)",
                            style = ArcTheme.typography.labelSmall.copy(fontSize = 10.sp),
                            color = ArcTheme.colors.textSecondary,
                        )
                    }
                }

                // 7-day mini tracker
                Row(
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    state.last7DaysStatus.forEach { (date, done) ->
                        val dayLabel = date.dayOfWeek.name.take(1)
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Text(
                                text = dayLabel,
                                style = ArcTheme.typography.labelSmall.copy(fontSize = 9.sp),
                                color = ArcTheme.colors.textSecondary,
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Box(
                                modifier = Modifier
                                    .size(14.dp)
                                    .clip(CircleShape)
                                    .background(if (done) habitColor else ArcTheme.colors.surfaceVariant)
                                    .border(
                                        width = 1.dp,
                                        color = if (done) habitColor else ArcTheme.colors.borderSubtle,
                                        shape = CircleShape,
                                    ),
                            )
                        }
                    }
                }
            }
        }
    }
}
