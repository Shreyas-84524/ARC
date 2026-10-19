package com.arc.arc.core.designsystem.theme

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * ARC design system dimensions, corner radii, and spacing tokens.
 */
object ArcDimens {
    // Corner Radii (matching Flutter AppTheme)
    val RadiusScreen: Dp = 40.dp
    val RadiusCard: Dp = 24.dp
    val RadiusInput: Dp = 18.dp
    val RadiusButton: Dp = 16.dp
    val RadiusPill: Dp = 999.dp
    val RadiusTag: Dp = 8.dp

    // Touch Target Accessibility
    val MinTouchTarget: Dp = 48.dp
    val ButtonHeight: Dp = 50.dp
    val InputHeight: Dp = 56.dp

    // Spacing
    val SpacingXxs: Dp = 2.dp
    val SpacingXs: Dp = 4.dp
    val SpacingSm: Dp = 8.dp
    val SpacingMd: Dp = 16.dp
    val SpacingLg: Dp = 24.dp
    val SpacingXl: Dp = 32.dp
    val ScreenHorizontalPadding: Dp = 20.dp

    // Elevations
    val ElevationNone: Dp = 0.dp
    val ElevationLow: Dp = 2.dp
    val ElevationMedium: Dp = 4.dp
    val ElevationHigh: Dp = 8.dp
}
