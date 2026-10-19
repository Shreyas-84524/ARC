package com.arc.arc.core.designsystem.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme

@Composable
fun ArcCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    border: BorderStroke? = BorderStroke(1.dp, ArcTheme.colors.borderSubtle),
    content: @Composable () -> Unit,
) {
    if (onClick != null) {
        Card(
            onClick = onClick,
            modifier = modifier,
            shape = RoundedCornerShape(ArcDimens.RadiusCard),
            colors = CardDefaults.cardColors(
                containerColor = ArcTheme.colors.card,
            ),
            border = border,
            elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        ) {
            content()
        }
    } else {
        Card(
            modifier = modifier,
            shape = RoundedCornerShape(ArcDimens.RadiusCard),
            colors = CardDefaults.cardColors(
                containerColor = ArcTheme.colors.card,
            ),
            border = border,
            elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        ) {
            content()
        }
    }
}
