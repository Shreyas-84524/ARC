package com.arc.arc.core.auth

/**
 * Represents the current authentication state across the application.
 */
sealed interface AuthState {
    data object Initializing : AuthState
    data object Unauthenticated : AuthState
    data class Authenticated(val user: UserSession) : AuthState
    data class Error(val message: String) : AuthState
}

/**
 * Immutable user session model.
 * Carries user ownership key (uid) required for user-scoped repository isolation.
 */
data class UserSession(
    val uid: String,
    val email: String?,
    val displayName: String,
    val username: String,
    val photoUrl: String? = null,
    val role: String = "user",
    val isDevFake: Boolean = false,
) {
    val isAdmin: Boolean
        get() = role.equals("admin", ignoreCase = true)
}
