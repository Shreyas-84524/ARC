package com.arc.arc.core.auth

import kotlinx.coroutines.flow.StateFlow

/**
 * Authentication repository interface defining authentication contracts for ARC.
 */
interface IAuthRepository {
    val authState: StateFlow<AuthState>

    val currentUserId: String?
        get() = (authState.value as? AuthState.Authenticated)?.user?.uid

    val currentUserSession: UserSession?
        get() = (authState.value as? AuthState.Authenticated)?.user

    suspend fun signInWithEmailAndPassword(emailOrUsername: String, password: String): Result<UserSession>

    suspend fun signUpWithEmailAndPassword(email: String, password: String, displayName: String): Result<UserSession>

    suspend fun sendPasswordResetEmail(email: String): Result<Unit>

    suspend fun signInWithGoogle(): Result<UserSession>

    suspend fun signInWithGoogleCredential(idToken: String): Result<UserSession> = signInWithGoogle()

    suspend fun signOut(): Result<Unit>

    suspend fun restoreSession(): Result<UserSession?>
}
