package com.arc.arc.core.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.Box
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.theme.ArcColors
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.model.TaskPriority

@Composable
fun ArcPriorityBadge(
    priority: TaskPriority,
    modifier: Modifier = Modifier,
) {
    val color = when (priority) {
        TaskPriority.HIGH -> ArcColors.PriorityHigh
        TaskPriority.MUST -> ArcColors.PriorityMust
        TaskPriority.LOW -> ArcColors.PriorityLow
    }

    Row(
        modifier = modifier
            .background(color.copy(alpha = 0.15f), shape = RoundedCornerShape(ArcDimens.RadiusTag))
            .border(1.dp, color.copy(alpha = 0.3f), shape = RoundedCornerShape(ArcDimens.RadiusTag))
            .padding(horizontal = 8.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        androidx.compose.foundation.layout.Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(color)
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = priority.displayName,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = color,
        )
    }
}
