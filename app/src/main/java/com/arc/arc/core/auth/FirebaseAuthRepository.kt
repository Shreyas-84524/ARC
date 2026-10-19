package com.arc.arc.core.auth

import android.content.Context
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.arc.arc.core.model.UserProfile
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.FirebaseNetworkException
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseAuthException
import com.google.firebase.auth.FirebaseAuthInvalidCredentialsException
import com.google.firebase.auth.FirebaseAuthInvalidUserException
import com.google.firebase.auth.FirebaseAuthUserCollisionException
import com.google.firebase.auth.FirebaseAuthWeakPasswordException
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.auth.UserProfileChangeRequest
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

/**
 * Production Firebase Authentication repository for ARC.
 *
 * Implements:
 * - Email/Password login and registration
 * - Google Sign-In via Android Credential Manager
 * - Persistent sessions and restoration
 * - Password reset & email validation
 * - UID continuity for existing Flutter users
 * - Full error mapping and network resilience
 */
class FirebaseAuthRepository(
    private val context: Context,
    private val firebaseAuth: FirebaseAuth = FirebaseAuth.getInstance(),
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : IAuthRepository {

    private val credentialManager: CredentialManager by lazy {
        CredentialManager.create(context)
    }

    private val _authState = MutableStateFlow<AuthState>(AuthState.Initializing)
    override val authState: StateFlow<AuthState> = _authState.asStateFlow()

    init {
        // Listen to Firebase auth state changes (token changes, logout, revocation)
        firebaseAuth.addAuthStateListener { auth ->
            val user = auth.currentUser
            if (user != null) {
                _authState.value = AuthState.Authenticated(mapFirebaseUser(user))
            } else {
                if (_authState.value !is AuthState.Initializing) {
                    _authState.value = AuthState.Unauthenticated
                }
            }
        }
        // Initial session check
        val currentUser = firebaseAuth.currentUser
        _authState.value = if (currentUser != null) {
            AuthState.Authenticated(mapFirebaseUser(currentUser))
        } else {
            AuthState.Unauthenticated
        }
    }

    override suspend fun signInWithEmailAndPassword(
        emailOrUsername: String,
        password: String
    ): Result<UserSession> = withContext(ioDispatcher) {
        val clean = emailOrUsername.trim()
        if (clean.isBlank()) {
            val err = "Email or username cannot be empty"
            _authState.value = AuthState.Error(err)
            return@withContext Result.failure(IllegalArgumentException(err))
        }

        // Support username login by resolving synthetic email if necessary
        val email = if (clean.contains("@")) clean else UserProfile.emailForUsername(clean)

        try {
            val result = firebaseAuth.signInWithEmailAndPassword(email, password).await()
            val user = result.user ?: throw IllegalStateException("Firebase returned null user upon sign-in")
            val session = mapFirebaseUser(user)
            _authState.value = AuthState.Authenticated(session)
            Result.success(session)
        } catch (e: Exception) {
            val userMessage = mapAuthException(e)
            _authState.value = AuthState.Error(userMessage)
            Result.failure(Exception(userMessage, e))
        }
    }

    override suspend fun signUpWithEmailAndPassword(
        email: String,
        password: String,
        displayName: String
    ): Result<UserSession> = withContext(ioDispatcher) {
        val cleanEmail = email.trim()
        if (cleanEmail.isBlank() || !cleanEmail.contains("@")) {
            val err = "Please enter a valid email address"
            _authState.value = AuthState.Error(err)
            return@withContext Result.failure(IllegalArgumentException(err))
        }

        if (password.length < 6) {
            val err = "Password must be at least 6 characters"
            _authState.value = AuthState.Error(err)
            return@withContext Result.failure(IllegalArgumentException(err))
        }

        try {
            val result = firebaseAuth.createUserWithEmailAndPassword(cleanEmail, password).await()
            val user = result.user ?: throw IllegalStateException("Firebase returned null user upon registration")

            val name = displayName.trim().ifEmpty { cleanEmail.substringBefore("@") }
            val profileUpdate = UserProfileChangeRequest.Builder()
                .setDisplayName(name)
                .build()
            user.updateProfile(profileUpdate).await()

            val session = mapFirebaseUser(user)
            _authState.value = AuthState.Authenticated(session)
            Result.success(session)
        } catch (e: Exception) {
            val userMessage = mapAuthException(e)
            _authState.value = AuthState.Error(userMessage)
            Result.failure(Exception(userMessage, e))
        }
    }

    override suspend fun sendPasswordResetEmail(email: String): Result<Unit> = withContext(ioDispatcher) {
        val clean = email.trim()
        if (clean.isBlank() || !clean.contains("@")) {
            return@withContext Result.failure(IllegalArgumentException("Please enter a valid email address"))
        }

        try {
            firebaseAuth.sendPasswordResetEmail(clean).await()
            Result.success(Unit)
        } catch (e: Exception) {
            val userMessage = mapAuthException(e)
            Result.failure(Exception(userMessage, e))
        }
    }

    override suspend fun signInWithGoogle(): Result<UserSession> = withContext(ioDispatcher) {
        try {
            val googleIdOption = GetGoogleIdOption.Builder()
                .setFilterByAuthorizedAccounts(false)
                .setServerClientId(ArcFirebaseConfig.WEB_CLIENT_ID)
                .setAutoSelectEnabled(false)
                .build()

            val request = GetCredentialRequest.Builder()
                .addCredentialOption(googleIdOption)
                .build()

            val response = credentialManager.getCredential(context, request)
            val credential = response.credential

            if (credential is CustomCredential && credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                val googleIdTokenCredential = GoogleIdTokenCredential.createFrom(credential.data)
                signInWithGoogleCredential(googleIdTokenCredential.idToken)
            } else {
                val err = "Unexpected credential type returned from Google Sign-In"
                _authState.value = AuthState.Error(err)
                Result.failure(IllegalStateException(err))
            }
        } catch (e: GetCredentialCancellationException) {
            // User cancelled the prompt; return failure without setting global error
            Result.failure(e)
        } catch (e: GetCredentialException) {
            val userMessage = "Google Sign-In failed: ${e.message}"
            _authState.value = AuthState.Error(userMessage)
            Result.failure(Exception(userMessage, e))
        } catch (e: Exception) {
            val userMessage = mapAuthException(e)
            _authState.value = AuthState.Error(userMessage)
            Result.failure(Exception(userMessage, e))
        }
    }

    override suspend fun signInWithGoogleCredential(idToken: String): Result<UserSession> = withContext(ioDispatcher) {
        try {
            val credential = GoogleAuthProvider.getCredential(idToken, null)
            val result = firebaseAuth.signInWithCredential(credential).await()
            val user = result.user ?: throw IllegalStateException("Firebase returned null user upon Google credential auth")
            val session = mapFirebaseUser(user)
            _authState.value = AuthState.Authenticated(session)
            Result.success(session)
        } catch (e: Exception) {
            val userMessage = mapAuthException(e)
            _authState.value = AuthState.Error(userMessage)
            Result.failure(Exception(userMessage, e))
        }
    }

    override suspend fun signOut(): Result<Unit> = withContext(ioDispatcher) {
        try {
            firebaseAuth.signOut()
            try {
                credentialManager.clearCredentialState(ClearCredentialStateRequest())
            } catch (_: Exception) {}
            _authState.value = AuthState.Unauthenticated
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun restoreSession(): Result<UserSession?> = withContext(ioDispatcher) {
        val currentUser = firebaseAuth.currentUser
        if (currentUser != null) {
            val session = mapFirebaseUser(currentUser)
            _authState.value = AuthState.Authenticated(session)
            Result.success(session)
        } else {
            _authState.value = AuthState.Unauthenticated
            Result.success(null)
        }
    }

    private fun mapFirebaseUser(user: FirebaseUser): UserSession {
        val email = user.email
        val displayName = user.displayName ?: email?.substringBefore("@") ?: "User"
        val username = user.displayName?.split(" ")?.firstOrNull() ?: email?.substringBefore("@") ?: "User"
        val isAdmin = email.equals("shigwanshreyas4@gmail.com", ignoreCase = true)

        return UserSession(
            uid = user.uid,
            email = email,
            displayName = displayName,
            username = username,
            photoUrl = user.photoUrl?.toString(),
            role = if (isAdmin) "admin" else "user",
            isDevFake = false,
        )
    }

    private fun mapAuthException(e: Exception): String {
        return when (e) {
            is FirebaseAuthInvalidUserException -> "No account found with this email or username."
            is FirebaseAuthInvalidCredentialsException -> "Invalid email or password."
            is FirebaseAuthUserCollisionException -> "An account with this email already exists."
            is FirebaseAuthWeakPasswordException -> "The chosen password is too weak. Please use at least 6 characters."
            is FirebaseNetworkException -> "Network connection unavailable. Please check your internet connection."
            is FirebaseAuthException -> e.localizedMessage ?: "Authentication error: ${e.errorCode}"
            else -> e.localizedMessage ?: "An unexpected authentication error occurred."
        }
    }
}
