package com.arc.arc.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import com.arc.arc.core.designsystem.theme.ArcTheme as CoreArcTheme

@Composable
fun ArcTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    CoreArcTheme(darkTheme = darkTheme, content = content)
}
