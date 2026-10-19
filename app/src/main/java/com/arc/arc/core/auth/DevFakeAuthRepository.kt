package com.arc.arc.core.auth

import com.arc.arc.core.model.UserProfile
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * EXPLICITLY LABELED DEVELOPMENT-ONLY FAKE AUTHENTICATION REPOSITORY.
 *
 * Safeguards:
 * 1. This fake repository is isolated to development and local testing.
 * 2. It does not communicate with any production Firebase endpoint.
 * 3. It provides deterministic sessions for verified ARC user accounts.
 * 4. All sessions are clearly tagged with isDevFake = true.
 */
class DevFakeAuthRepository(
    initialSession: UserSession? = DEFAULT_DEV_USER
) : IAuthRepository {

    companion object {
        val DEFAULT_DEV_USER = UserSession(
            uid = "dev_uid_shreyas",
            email = "shigwanshreyas4@gmail.com",
            displayName = "Shreyas Shigwan",
            username = "Shreyas",
            role = "admin",
            isDevFake = true,
        )

        val PRESET_DEV_USERS = listOf(
            DEFAULT_DEV_USER,
            UserSession(
                uid = "dev_uid_aman",
                email = "aman@arc.app",
                displayName = "Aman",
                username = "Aman",
                role = "user",
                isDevFake = true,
            ),
            UserSession(
                uid = "dev_uid_rohit",
                email = "rohit@arc.app",
                displayName = "Rohit",
                username = "Rohit",
                role = "user",
                isDevFake = true,
            ),
            UserSession(
                uid = "dev_uid_demo",
                email = "demo@arc.app",
                displayName = "Demo User",
                username = "Demo",
                role = "user",
                isDevFake = true,
            ),
        )
    }

    private val _authState = MutableStateFlow<AuthState>(
        if (initialSession != null) AuthState.Authenticated(initialSession) else AuthState.Unauthenticated
    )
    override val authState: StateFlow<AuthState> = _authState.asStateFlow()

    override suspend fun signInWithEmailAndPassword(
        emailOrUsername: String,
        password: String,
    ): Result<UserSession> {
        val clean = emailOrUsername.trim()
        if (clean.isBlank()) {
            val err = "Email or username cannot be empty"
            _authState.value = AuthState.Error(err)
            return Result.failure(IllegalArgumentException(err))
        }

        // Match preset user or create dev session
        val matchedPreset = PRESET_DEV_USERS.find {
            it.username.equals(clean, ignoreCase = true) || it.email.equals(clean, ignoreCase = true)
        }

        val session = matchedPreset ?: UserSession(
            uid = "dev_uid_${clean.lowercase().replace(" ", "_")}",
            email = if (clean.contains("@")) clean else UserProfile.emailForUsername(clean),
            displayName = clean.replaceFirstChar { it.uppercase() },
            username = clean,
            role = if (clean.equals("admin", ignoreCase = true)) "admin" else "user",
            isDevFake = true,
        )

        _authState.value = AuthState.Authenticated(session)
        return Result.success(session)
    }

    override suspend fun signUpWithEmailAndPassword(
        email: String,
        password: String,
        displayName: String,
    ): Result<UserSession> {
        val clean = email.trim()
        if (clean.isBlank() || !clean.contains("@")) {
            return Result.failure(IllegalArgumentException("Invalid email format"))
        }
        val name = displayName.trim().ifEmpty { clean.substringBefore("@") }
        val session = UserSession(
            uid = "dev_uid_${clean.substringBefore("@").lowercase().replace(" ", "_")}",
            email = clean,
            displayName = name,
            username = name,
            role = "user",
            isDevFake = true,
        )
        _authState.value = AuthState.Authenticated(session)
        return Result.success(session)
    }

    override suspend fun sendPasswordResetEmail(email: String): Result<Unit> {
        if (email.isBlank() || !email.contains("@")) {
            return Result.failure(IllegalArgumentException("Invalid email format"))
        }
        return Result.success(Unit)
    }

    override suspend fun signInWithGoogle(): Result<UserSession> {
        val session = DEFAULT_DEV_USER
        _authState.value = AuthState.Authenticated(session)
        return Result.success(session)
    }

    override suspend fun signInWithGoogleCredential(idToken: String): Result<UserSession> {
        val session = DEFAULT_DEV_USER
        _authState.value = AuthState.Authenticated(session)
        return Result.success(session)
    }

    override suspend fun signOut(): Result<Unit> {
        _authState.value = AuthState.Unauthenticated
        return Result.success(Unit)
    }

    override suspend fun restoreSession(): Result<UserSession?> {
        val current = (_authState.value as? AuthState.Authenticated)?.user
        return Result.success(current)
    }

    fun switchUser(session: UserSession) {
        _authState.value = AuthState.Authenticated(session)
    }
}
