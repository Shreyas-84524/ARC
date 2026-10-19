package com.arc.arc.core.model

import java.util.Date

/**
 * Native Kotlin representation of ARC's UserProfile model.
 * Preserves compatibility with Firestore `users/{uid}` and `settings/profile`.
 */
data class UserProfile(
    val id: String,
    val username: String,
    val displayName: String,
    val email: String? = null,
    val photoURL: String? = null,
    val authProvider: String = "password",
    val role: String = "user",
    val createdAt: Date = Date(),
    val updatedAt: Date? = null,
    val lastLoginAt: Date? = null,
) {
    val isAdmin: Boolean
        get() = role.equals("admin", ignoreCase = true)

    fun toMap(): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        map["id"] = id
        map["uid"] = id
        map["username"] = username
        map["displayName"] = displayName
        map["email"] = email
        map["photoURL"] = photoURL
        map["authProvider"] = authProvider
        map["role"] = role
        map["createdAt"] = DateTimeUtils.formatIso(createdAt)
        map["updatedAt"] = (updatedAt ?: createdAt).let { DateTimeUtils.formatIso(it) }
        map["lastLoginAt"] = lastLoginAt?.let { DateTimeUtils.formatIso(it) }
        return map
    }

    companion object {
        val KNOWN_USERNAMES = listOf(
            "Shreyas",
            "Aman",
            "Rohit",
            "Sachi",
            "Yash",
            "Purushottam"
        )

        fun isKnownUsername(username: String): Boolean {
            val clean = username.trim().lowercase()
            return clean == "admin" || KNOWN_USERNAMES.any { it.lowercase() == clean }
        }

        fun emailForUsername(username: String): String {
            val clean = username.trim().lowercase()
            return if (clean == "shreyas") {
                "shigwanshreyas4@gmail.com"
            } else {
                "$clean@arc.app"
            }
        }

        fun fromMap(map: Map<String, Any?>): UserProfile {
            val now = Date()
            val id = (map["id"] as? String) ?: (map["uid"] as? String) ?: ""
            val username = (map["username"] as? String) ?: ""
            val displayName = (map["displayName"] as? String) ?: username
            val createdAtDate = (map["createdAt"] as? String)?.let { DateTimeUtils.parseIso(it) } ?: now
            val updatedAtDate = (map["updatedAt"] as? String)?.let { DateTimeUtils.parseIso(it) }
            val lastLoginAtDate = (map["lastLoginAt"] as? String)?.let { DateTimeUtils.parseIso(it) }

            return UserProfile(
                id = id,
                username = username,
                displayName = displayName,
                email = map["email"] as? String,
                photoURL = map["photoURL"] as? String,
                authProvider = (map["authProvider"] as? String) ?: "password",
                role = (map["role"] as? String) ?: "user",
                createdAt = createdAtDate,
                updatedAt = updatedAtDate,
                lastLoginAt = lastLoginAtDate,
            )
        }
    }
}
