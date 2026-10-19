package com.arc.arc.auth

import com.arc.arc.core.auth.AuthState
import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.features.auth.LoginViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
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

@OptIn(ExperimentalCoroutinesApi::class)
class AuthFoundationTest {

    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testInitialDevAuthSession() {
        val repo = DevFakeAuthRepository()
        val initial = repo.authState.value
        assertTrue(initial is AuthState.Authenticated)
        val session = (initial as AuthState.Authenticated).user
        assertEquals("dev_uid_shreyas", session.uid)
        assertEquals("Shreyas", session.username)
        assertTrue(session.isAdmin)
        assertTrue(session.isDevFake)
    }

    @Test
    fun testSignOutAndRestore() = runTest {
        val repo = DevFakeAuthRepository()
        repo.signOut()
        assertTrue(repo.authState.value is AuthState.Unauthenticated)
        assertNull(repo.currentUserId)

        // Sign in as Aman
        val result = repo.signInWithEmailAndPassword("Aman", "password")
        assertTrue(result.isSuccess)
        val session = result.getOrThrow()
        assertEquals("dev_uid_aman", session.uid)
        assertFalse(session.isAdmin)
        assertEquals(session.uid, repo.currentUserId)
    }

    @Test
    fun testEmptyCredentialsFailure() = runTest {
        val repo = DevFakeAuthRepository(initialSession = null)
        val result = repo.signInWithEmailAndPassword("", "")
        assertTrue(result.isFailure)
        assertTrue(repo.authState.value is AuthState.Error)
    }

    @Test
    fun testLoginViewModelPresetSignIn() = runTest {
        val repo = DevFakeAuthRepository(initialSession = null)
        val viewModel = LoginViewModel(repo)

        val preset = DevFakeAuthRepository.PRESET_DEV_USERS.first { it.username == "Aman" }
        viewModel.signInAsPreset(preset)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertTrue(state.isSuccess)
        assertNull(state.errorMessage)
        assertFalse(state.isLoading)
        assertEquals("dev_uid_aman", repo.currentUserId)
    }

    @Test
    fun testLoginViewModelEmptyValidation() = runTest {
        val repo = DevFakeAuthRepository(initialSession = null)
        val viewModel = LoginViewModel(repo)

        viewModel.signIn()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertFalse(state.isSuccess)
        assertNotNull(state.errorMessage)
    }
}
