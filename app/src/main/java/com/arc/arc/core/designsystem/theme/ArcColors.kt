package com.arc.arc.core.designsystem.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

/**
 * ARC design system colors preserving 100% visual parity with Flutter ARC's AppColors.
 */
object ArcColors {
    // Accent (Neon Lime)
    val Accent = Color(0xFFD6FF24)
    val AccentHover = Color(0xFFE4FF58)
    val AccentPressed = Color(0xFFB8D91A)
    val AccentGlow = Color(0x66D6FF24)
    val DarkAccent = Color(0xFF5C7000)

    // Priorities
    val PriorityHigh = Color(0xFFFF4D4F)
    val PriorityMust = Color(0xFFFF9F43)
    val PriorityLow = Color(0xFFFFC857)

    // Status
    val Success = Color(0xFFD7FF2F)
    val Info = Color(0xFF1890FF)
    val Warning = Color(0xFFFAAD14)
    val Danger = Color(0xFFFF4D4F)
    val Income = Color(0xFFD7FF2F)

    // Dark Backgrounds
    val DarkBg = Color(0xFF101010)
    val DarkBgSecondary = Color(0xFF181818)
    val DarkSurface = Color(0xFF1D1D1F)
    val DarkCard = Color(0xFF232323)
    val DarkElevated = Color(0xFF292929)
    val DarkModal = Color(0xFF1C1C1E)

    // Light Backgrounds
    val LightBg = Color(0xFFF9FAFB)
    val LightBgSecondary = Color(0xFFF3F4F6)
    val LightSurface = Color(0xFFFFFFFF)
    val LightCard = Color(0xFFFFFFFF)
    val LightElevated = Color(0xFFFFFFFF)
    val LightModal = Color(0xFFFFFFFF)

    // Dark Text
    val TextPrimaryDark = Color(0xFFFFFFFF)
    val TextSecondaryDark = Color(0xFFD6D6D6)
    val TextMutedDark = Color(0xFF8A8A8A)
    val TextDisabledDark = Color(0xFF5A5A5A)
    val TextPlaceholderDark = Color(0xFF757575)

    // Light Text
    val TextPrimaryLight = Color(0xFF111827)
    val TextSecondaryLight = Color(0xFF4B5563)
    val TextMutedLight = Color(0xFF9CA3AF)
    val TextDisabledLight = Color(0xFFD1D5DB)
    val TextPlaceholderLight = Color(0xFF9CA3AF)

    // Dark Borders
    val BorderSubtleDark = Color(0x0DFFFFFF)
    val BorderMediumDark = Color(0x14FFFFFF)
    val BorderStrongDark = Color(0x1EFFFFFF)

    // Light Borders
    val BorderSubtleLight = Color(0x0D000000)
    val BorderMediumLight = Color(0x14000000)
    val BorderStrongLight = Color(0x26000000)
}

@Immutable
data class ArcCustomColors(
    val accent: Color,
    val background: Color,
    val backgroundSecondary: Color,
    val surface: Color,
    val card: Color,
    val modal: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textMuted: Color,
    val textDisabled: Color,
    val textPlaceholder: Color,
    val borderSubtle: Color,
    val borderMedium: Color,
    val borderStrong: Color,
    val priorityHigh: Color = ArcColors.PriorityHigh,
    val priorityMust: Color = ArcColors.PriorityMust,
    val priorityLow: Color = ArcColors.PriorityLow,
    val success: Color = ArcColors.Success,
    val danger: Color = ArcColors.Danger,
    val surfaceVariant: Color = card,
)
