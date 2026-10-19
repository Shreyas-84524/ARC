package com.arc.arc.features.tasks

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.components.ArcCard
import com.arc.arc.core.designsystem.theme.ArcColors
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.model.DateTimeUtils
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TaskPriority

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TaskCard(
    task: TaskModel,
    onToggleCompletion: () -> Unit,
    onClick: () -> Unit,
    onDeleteClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val priorityColor = when (task.priorityEnum) {
        TaskPriority.HIGH -> ArcColors.PriorityHigh
        TaskPriority.MUST -> ArcColors.PriorityMust
        TaskPriority.LOW -> ArcColors.PriorityLow
    }

    val alphaAnim by animateFloatAsState(
        targetValue = if (task.completed) 0.6f else 1.0f,
        label = "taskCardAlpha",
    )

    ArcCard(
        modifier = modifier
            .fillMaxWidth()
            .alpha(alphaAnim),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.Top,
        ) {
            // Priority circle checkbox
            Box(
                modifier = Modifier
                    .padding(top = 2.dp)
                    .size(24.dp)
                    .clip(CircleShape)
                    .background(if (task.completed) priorityColor else Color.Transparent)
                    .border(2.dp, priorityColor, CircleShape)
                    .clickable(
                        role = Role.Checkbox,
                        onClick = onToggleCompletion,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                if (task.completed) {
                    Icon(
                        imageVector = Icons.Default.Check,
                        contentDescription = "Completed",
                        tint = Color.White,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.width(14.dp))

            // Main Details
            Column(
                modifier = Modifier.weight(1f),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = task.title,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (task.completed) ArcTheme.colors.textDisabled else ArcTheme.colors.textPrimary,
                        textDecoration = if (task.completed) TextDecoration.LineThrough else null,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )

                    IconButton(
                        onClick = onDeleteClick,
                        modifier = Modifier.size(28.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Default.Delete,
                            contentDescription = "Delete task",
                            tint = ArcTheme.colors.textMuted,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }

                if (task.description.isNotBlank()) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = task.description,
                        fontSize = 13.sp,
                        color = ArcTheme.colors.textMuted,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        textDecoration = if (task.completed) TextDecoration.LineThrough else null,
                        lineHeight = 18.sp,
                    )
                }

                Spacer(modifier = Modifier.height(10.dp))

                // Tags row (Date, Category, Labels)
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    // Due Date Tag
                    if (task.dueDate != null) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .background(
                                    color = ArcTheme.colors.backgroundSecondary,
                                    shape = RoundedCornerShape(6.dp),
                                )
                                .padding(horizontal = 8.dp, vertical = 3.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Default.CalendarToday,
                                contentDescription = null,
                                tint = ArcTheme.colors.textMuted,
                                modifier = Modifier.size(12.dp),
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            val dateText = DateTimeUtils.formatDisplayShort(task.dueDate) +
                                    (task.dueTime?.let { ", $it" } ?: "")
                            Text(
                                text = dateText,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Medium,
                                color = ArcTheme.colors.textMuted,
                            )
                        }
                    }

                    // Category Pill
                    Box(
                        modifier = Modifier
                            .background(
                                color = ArcTheme.colors.backgroundSecondary,
                                shape = RoundedCornerShape(6.dp),
                            )
                            .border(
                                width = 1.dp,
                                color = ArcTheme.colors.borderSubtle,
                                shape = RoundedCornerShape(6.dp),
                            )
                            .padding(horizontal = 8.dp, vertical = 3.dp),
                    ) {
                        Text(
                            text = task.category,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = ArcTheme.colors.textSecondary,
                        )
                    }

                    // Label Hashtags
                    task.labels.forEach { label ->
                        Box(
                            modifier = Modifier
                                .background(
                                    color = ArcColors.AccentGlow,
                                    shape = RoundedCornerShape(6.dp),
                                )
                                .padding(horizontal = 8.dp, vertical = 3.dp),
                        ) {
                            Text(
                                text = "#$label",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = ArcTheme.colors.accent,
                            )
                        }
                    }
                }
            }
        }
    }
}
