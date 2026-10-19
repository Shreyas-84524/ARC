package com.arc.arc.core.designsystem.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

private val DarkColorScheme = darkColorScheme(
    primary = ArcColors.Accent,
    onPrimary = ArcColors.TextPrimaryLight,
    primaryContainer = ArcColors.DarkElevated,
    onPrimaryContainer = ArcColors.TextPrimaryDark,
    secondary = ArcColors.AccentHover,
    onSecondary = ArcColors.TextPrimaryLight,
    background = ArcColors.DarkBg,
    onBackground = ArcColors.TextPrimaryDark,
    surface = ArcColors.DarkSurface,
    onSurface = ArcColors.TextPrimaryDark,
    surfaceVariant = ArcColors.DarkCard,
    onSurfaceVariant = ArcColors.TextSecondaryDark,
    error = ArcColors.Danger,
    onError = Color.White,
)

private val LightColorScheme = lightColorScheme(
    primary = ArcColors.Accent,
    onPrimary = ArcColors.TextPrimaryLight,
    primaryContainer = ArcColors.LightBgSecondary,
    onPrimaryContainer = ArcColors.TextPrimaryLight,
    secondary = ArcColors.DarkAccent,
    onSecondary = Color.White,
    background = ArcColors.LightBg,
    onBackground = ArcColors.TextPrimaryLight,
    surface = ArcColors.LightSurface,
    onSurface = ArcColors.TextPrimaryLight,
    surfaceVariant = ArcColors.LightBgSecondary,
    onSurfaceVariant = ArcColors.TextSecondaryLight,
    error = ArcColors.Danger,
    onError = Color.White,
)

private val DarkCustomColors = ArcCustomColors(
    accent = ArcColors.Accent,
    background = ArcColors.DarkBg,
    backgroundSecondary = ArcColors.DarkBgSecondary,
    surface = ArcColors.DarkSurface,
    card = ArcColors.DarkCard,
    modal = ArcColors.DarkModal,
    textPrimary = ArcColors.TextPrimaryDark,
    textSecondary = ArcColors.TextSecondaryDark,
    textMuted = ArcColors.TextMutedDark,
    textDisabled = ArcColors.TextDisabledDark,
    textPlaceholder = ArcColors.TextPlaceholderDark,
    borderSubtle = ArcColors.BorderSubtleDark,
    borderMedium = ArcColors.BorderMediumDark,
    borderStrong = ArcColors.BorderStrongDark,
)

private val LightCustomColors = ArcCustomColors(
    accent = ArcColors.Accent,
    background = ArcColors.LightBg,
    backgroundSecondary = ArcColors.LightBgSecondary,
    surface = ArcColors.LightSurface,
    card = ArcColors.LightCard,
    modal = ArcColors.LightModal,
    textPrimary = ArcColors.TextPrimaryLight,
    textSecondary = ArcColors.TextSecondaryLight,
    textMuted = ArcColors.TextMutedLight,
    textDisabled = ArcColors.TextDisabledLight,
    textPlaceholder = ArcColors.TextPlaceholderLight,
    borderSubtle = ArcColors.BorderSubtleLight,
    borderMedium = ArcColors.BorderMediumLight,
    borderStrong = ArcColors.BorderStrongLight,
)

val LocalArcColors = staticCompositionLocalOf { DarkCustomColors }

object ArcTheme {
    val colors: ArcCustomColors
        @Composable
        @ReadOnlyComposable
        get() = LocalArcColors.current

    val typography: androidx.compose.material3.Typography
        @Composable
        @ReadOnlyComposable
        get() = MaterialTheme.typography

    val dimens: ArcDimens
        get() = ArcDimens
}

@Composable
fun ArcTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    val customColors = if (darkTheme) DarkCustomColors else LightCustomColors

    CompositionLocalProvider(
        LocalArcColors provides customColors,
    ) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = ArcTypography.Typography,
            content = content,
        )
    }
}
