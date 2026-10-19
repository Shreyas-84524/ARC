package com.arc.arc.core.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.CheckBox
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.arc.arc.core.designsystem.theme.ArcTheme

enum class ArcNavTab(
    val title: String,
    val icon: ImageVector,
    val route: String,
) {
    DASHBOARD("Dashboard", Icons.Default.Dashboard, "dashboard"),
    TASKS("Tasks", Icons.Default.CheckBox, "tasks"),
    HABITS("Habits", Icons.Default.FlashOn, "habits"),
    MONEY("Money", Icons.Default.AccountBalanceWallet, "money"),
    VAULT("Vault", Icons.Default.Lock, "vault");
}

@Composable
fun ArcBottomNavigationBar(
    currentRoute: String,
    onTabSelected: (ArcNavTab) -> Unit,
    modifier: Modifier = Modifier,
) {
    androidx.compose.foundation.layout.Column(
        modifier = modifier
            .fillMaxWidth()
            .background(ArcTheme.colors.surface)
            .navigationBarsPadding(),
    ) {
        HorizontalDivider(
            color = ArcTheme.colors.borderSubtle,
            thickness = 1.dp,
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(72.dp)
                .padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ArcNavTab.entries.filterNot { it == ArcNavTab.VAULT }.forEach { tab ->
                val isSelected = currentRoute == tab.route

                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(64.dp)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                            role = Role.Tab,
                            onClick = { onTabSelected(tab) },
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        modifier = Modifier
                            .size(width = 64.dp, height = 48.dp)
                            .background(
                                color = if (isSelected) ArcTheme.colors.accent.copy(alpha = 0.16f) else androidx.compose.ui.graphics.Color.Transparent,
                                shape = RoundedCornerShape(16.dp),
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = tab.icon,
                            contentDescription = tab.title,
                            tint = if (isSelected) ArcTheme.colors.accent else ArcTheme.colors.textMuted,
                            modifier = Modifier.size(26.dp),
                        )
                    }
                }
            }
        }
    }
}
