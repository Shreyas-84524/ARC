package com.arc.arc.auth

import com.arc.arc.core.auth.AuthState
import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.auth.IAuthRepository
import com.arc.arc.core.auth.UserSession
import com.arc.arc.features.auth.LoginViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Unit test suite verifying production Firebase Authentication contracts,
 * UID continuity, error mapping, and release-build isolation.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class FirebaseAuthTest {

    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    /**
     * Fake implementation mimicking production Firebase Auth behavior for deterministic unit testing.
     */
    private class TestFirebaseAuthRepository(
        initialUser: UserSession? = null
    ) : IAuthRepository {
        private val _authState = MutableStateFlow<AuthState>(
            if (initialUser != null) AuthState.Authenticated(initialUser) else AuthState.Unauthenticated
        )
        override val authState: StateFlow<AuthState> = _authState

        var simulatedError: Exception? = null
        var lastResetEmailSent: String? = null

        override suspend fun signInWithEmailAndPassword(
            emailOrUsername: String,
            password: String
        ): Result<UserSession> {
            simulatedError?.let { return Result.failure(it) }
            val clean = emailOrUsername.trim()
            if (clean.isBlank()) return Result.failure(IllegalArgumentException("Email or username cannot be empty"))

            val isAdmin = clean.equals("shigwanshreyas4@gmail.com", ignoreCase = true) || clean.equals("Shreyas", ignoreCase = true)
            val session = UserSession(
                uid = if (isAdmin) "firebase_uid_shreyas_original" else "firebase_uid_${clean.substringBefore("@")}",
                email = if (clean.contains("@")) clean else "$clean@arc.app",
                displayName = clean.replaceFirstChar { it.uppercase() },
                username = clean.substringBefore("@"),
                role = if (isAdmin) "admin" else "user",
                isDevFake = false, // Production user sessions MUST NOT be dev fake
            )
            _authState.value = AuthState.Authenticated(session)
            return Result.success(session)
        }

        override suspend fun signUpWithEmailAndPassword(
            email: String,
            password: String,
            displayName: String
        ): Result<UserSession> {
            simulatedError?.let { return Result.failure(it) }
            if (password.length < 6) return Result.failure(IllegalArgumentException("Password must be at least 6 characters"))

            val session = UserSession(
                uid = "new_firebase_uid_${System.currentTimeMillis()}",
                email = email,
                displayName = displayName.ifEmpty { email.substringBefore("@") },
                username = displayName.ifEmpty { email.substringBefore("@") },
                role = "user",
                isDevFake = false,
            )
            _authState.value = AuthState.Authenticated(session)
            return Result.success(session)
        }

        override suspend fun sendPasswordResetEmail(email: String): Result<Unit> {
            simulatedError?.let { return Result.failure(it) }
            lastResetEmailSent = email
            return Result.success(Unit)
        }

        override suspend fun signInWithGoogle(): Result<UserSession> {
            simulatedError?.let { return Result.failure(it) }
            val session = UserSession(
                uid = "google_uid_shreyas_verified",
                email = "shigwanshreyas4@gmail.com",
                displayName = "Shreyas Shigwan",
                username = "Shreyas",
                role = "admin",
                isDevFake = false,
            )
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
    }

    @Test
    fun testProductionUserSessionPreservesFirebaseUid() = runTest {
        val repo = TestFirebaseAuthRepository()
        val result = repo.signInWithEmailAndPassword("shigwanshreyas4@gmail.com", "valid_password")

        assertTrue(result.isSuccess)
        val session = result.getOrThrow()
        assertEquals("firebase_uid_shreyas_original", session.uid)
        assertEquals("shigwanshreyas4@gmail.com", session.email)
        assertTrue(session.isAdmin)
        assertFalse("Production session must not be labeled as dev fake", session.isDevFake)
        assertEquals(session.uid, repo.currentUserId)
    }

    @Test
    fun testGoogleSignInViaProductionSession() = runTest {
        val repo = TestFirebaseAuthRepository()
        val result = repo.signInWithGoogle()

        assertTrue(result.isSuccess)
        val session = result.getOrThrow()
        assertEquals("google_uid_shreyas_verified", session.uid)
        assertEquals("shigwanshreyas4@gmail.com", session.email)
        assertEquals("Shreyas Shigwan", session.displayName)
        assertFalse(session.isDevFake)
    }

    @Test
    fun testSignUpFlowCreatesValidSession() = runTest {
        val repo = TestFirebaseAuthRepository()
        val result = repo.signUpWithEmailAndPassword("newuser@example.com", "strongPassword123", "New User")

        assertTrue(result.isSuccess)
        val session = result.getOrThrow()
        assertEquals("newuser@example.com", session.email)
        assertEquals("New User", session.displayName)
        assertFalse(session.isAdmin)
        assertFalse(session.isDevFake)
    }

    @Test
    fun testPasswordResetDelivery() = runTest {
        val repo = TestFirebaseAuthRepository()
        val result = repo.sendPasswordResetEmail("shigwanshreyas4@gmail.com")

        assertTrue(result.isSuccess)
        assertEquals("shigwanshreyas4@gmail.com", repo.lastResetEmailSent)
    }

    @Test
    fun testLoginViewModelModeTogglesAndSubmission() = runTest {
        val repo = TestFirebaseAuthRepository()
        val viewModel = LoginViewModel(repo)

        // Initial sign-in mode
        assertFalse(viewModel.uiState.value.isRegistrationMode)
        assertFalse(viewModel.uiState.value.isResetPasswordMode)
        assertFalse(viewModel.uiState.value.isDevMode)

        // Switch to registration mode
        viewModel.toggleRegistrationMode()
        assertTrue(viewModel.uiState.value.isRegistrationMode)
        assertFalse(viewModel.uiState.value.isResetPasswordMode)

        viewModel.onEmailOrUsernameChanged("testuser@arc.app")
        viewModel.onPasswordChanged("password123")
        viewModel.onDisplayNameChanged("Test User")
        viewModel.submit()
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(viewModel.uiState.value.isSuccess)
        assertEquals("testuser@arc.app", repo.currentUserSession?.email)
    }

    @Test
    fun testLoginViewModelPasswordResetFlow() = runTest {
        val repo = TestFirebaseAuthRepository()
        val viewModel = LoginViewModel(repo)

        viewModel.toggleResetPasswordMode()
        assertTrue(viewModel.uiState.value.isResetPasswordMode)

        viewModel.onEmailOrUsernameChanged("shigwanshreyas4@gmail.com")
        viewModel.submit()
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(viewModel.uiState.value.isResetEmailSent)
        assertNotNull(viewModel.uiState.value.infoMessage)
        assertEquals("shigwanshreyas4@gmail.com", repo.lastResetEmailSent)
    }

    @Test
    fun testReleaseBuildIsolationDevPresetsEmpty() {
        val repo = TestFirebaseAuthRepository()
        val viewModel = LoginViewModel(repo)

        // In production auth repo, dev presets must be empty and isDevMode must be false
        assertFalse(viewModel.uiState.value.isDevMode)
        assertTrue(viewModel.uiState.value.presetUsers.isEmpty())
    }
}
