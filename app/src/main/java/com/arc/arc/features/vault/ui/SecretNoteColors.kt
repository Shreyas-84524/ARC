package com.arc.arc.features.vault.ui

import androidx.compose.ui.graphics.Color

/**
 * Predefined color palette for Secret Notes matching legacy Flutter palette.
 */
data class SecretNoteColorItem(
    val id: String,
    val name: String,
    val lightBackground: Color,
    val darkBackground: Color,
    val lightBorder: Color,
    val darkBorder: Color,
    val dotColor: Color,
) {
    fun backgroundColor(isDark: Boolean): Color =
        if (isDark) darkBackground else lightBackground

    fun borderColor(isDark: Boolean): Color =
        if (isDark) darkBorder else lightBorder
}

object SecretNoteColors {
    const val DEFAULT_COLOR_ID = "default"

    val palette = listOf(
        SecretNoteColorItem(
            id = "default",
            name = "Default",
            lightBackground = Color(0xFFF9FAFB),
            darkBackground = Color(0xFF1E222A),
            lightBorder = Color(0xFFE5E7EB),
            darkBorder = Color(0xFF333842),
            dotColor = Color(0xFF9CA3AF),
        ),
        SecretNoteColorItem(
            id = "amber",
            name = "Amber",
            lightBackground = Color(0xFFFEF3C7),
            darkBackground = Color(0xFF362B15),
            lightBorder = Color(0xFFFDE68A),
            darkBorder = Color(0xFF5E491F),
            dotColor = Color(0xFFF59E0B),
        ),
        SecretNoteColorItem(
            id = "emerald",
            name = "Emerald",
            lightBackground = Color(0xFFD1FAE5),
            darkBackground = Color(0xFF132F23),
            lightBorder = Color(0xFFA7F3D0),
            darkBorder = Color(0xFF1E523D),
            dotColor = Color(0xFF10B981),
        ),
        SecretNoteColorItem(
            id = "sky",
            name = "Sky",
            lightBackground = Color(0xFFE0F2FE),
            darkBackground = Color(0xFF152A3E),
            lightBorder = Color(0xFFBAE6FD),
            darkBorder = Color(0xFF1E486D),
            dotColor = Color(0xFF0284C7),
        ),
        SecretNoteColorItem(
            id = "violet",
            name = "Violet",
            lightBackground = Color(0xFFEDE9FE),
            darkBackground = Color(0xFF271C3D),
            lightBorder = Color(0xFFDDD6FE),
            darkBorder = Color(0xFF45306B),
            dotColor = Color(0xFF8B5CF6),
        ),
        SecretNoteColorItem(
            id = "rose",
            name = "Rose",
            lightBackground = Color(0xFFFFE4E6),
            darkBackground = Color(0xFF3B1B24),
            lightBorder = Color(0xFFFECDD3),
            darkBorder = Color(0xFF652939),
            dotColor = Color(0xFFF43F5E),
        ),
        SecretNoteColorItem(
            id = "orange",
            name = "Orange",
            lightBackground = Color(0xFFFFEDD5),
            darkBackground = Color(0xFF382314),
            lightBorder = Color(0xFFFED7AA),
            darkBorder = Color(0xFF613B1F),
            dotColor = Color(0xFFF97316),
        ),
        SecretNoteColorItem(
            id = "teal",
            name = "Teal",
            lightBackground = Color(0xFFCCFBF1),
            darkBackground = Color(0xFF112F2C),
            lightBorder = Color(0xFF99F6E4),
            darkBorder = Color(0xFF1C524C),
            dotColor = Color(0xFF14B8A6),
        ),
    )

    fun getById(id: String?): SecretNoteColorItem =
        palette.firstOrNull { it.id == id } ?: palette.first()
}
