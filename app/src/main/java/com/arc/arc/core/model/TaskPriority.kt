package com.arc.arc.core.model

enum class TaskPriority(val displayName: String, val level: Int, val emoji: String) {
    HIGH("High", 3, "🔴"),
    MUST("Must", 2, "🟠"),
    LOW("Low", 1, "🟡");

    companion object {
        fun fromString(value: String?): TaskPriority {
            return when (value?.trim()?.lowercase()) {
                "high" -> HIGH
                "must", "much" -> MUST // Backward compatibility for legacy Flutter "Much"
                "low" -> LOW
                else -> LOW
            }
        }
    }
}

object TaskConstants {
    val CATEGORIES = listOf(
        "Work",
        "Personal",
        "Education",
        "Health",
        "Finance",
        "Social",
        "Other"
    )

    const val DEFAULT_CATEGORY = "Work"
}
