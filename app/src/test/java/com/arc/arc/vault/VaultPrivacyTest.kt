package com.arc.arc.vault

import com.arc.arc.core.security.VaultAuthCoordinator
import com.arc.arc.core.security.VaultAuthState
import com.arc.arc.core.security.VaultAutoLockPolicy
import com.arc.arc.core.security.VaultLifecycleManager
import com.arc.arc.core.security.VaultPinManager
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class VaultPrivacyTest {

    private lateinit var preferencesStore: InMemoryVaultPreferencesDataStore
    private lateinit var pinManager: VaultPinManager
    private lateinit var coordinator: VaultAuthCoordinator
    private lateinit var lifecycleManager: VaultLifecycleManager

    private val testUser = "user-alice-vault"

    @Before
    fun setUp() {
        preferencesStore = InMemoryVaultPreferencesDataStore()
        pinManager = VaultPinManager(preferencesStore)
        coordinator = VaultAuthCoordinator(pinManager, preferencesStore)
        lifecycleManager = VaultLifecycleManager(coordinator, policy = VaultAutoLockPolicy.IMMEDIATE)
    }

    @Test
    fun testImmediateAutoLockOnBackgrounding() = runTest {
        coordinator.setupPin(testUser, "123456", 6)
        assertTrue(coordinator.isUnlocked)

        val unlockedState = coordinator.authState.value as VaultAuthState.Unlocked
        val activeDek = unlockedState.activeDek

        // Background app
        lifecycleManager.onAppBackgrounded(1000000L)

        // Must be locked immediately
        assertFalse(coordinator.isUnlocked)
        assertNull(coordinator.getActiveDek())
        // Verify in-memory key zeroing
        assertTrue("In-memory DEK must be zeroed out", activeDek.all { it == 0.toByte() })
    }

    @Test
    fun testTimedAutoLockPolicyWithinGracePeriod() = runTest {
        lifecycleManager.policy = VaultAutoLockPolicy.THIRTY_SECONDS
        coordinator.setupPin(testUser, "123456", 6)
        assertTrue(coordinator.isUnlocked)

        var currentTime = 5000000L
        lifecycleManager.onAppBackgrounded(currentTime)

        // Foreground 15 seconds later (within 30s grace period)
        currentTime += 15_000L
        lifecycleManager.onAppForegrounded(currentTime)

        // Should remain unlocked
        assertTrue("Vault should remain unlocked within timeout grace period", coordinator.isUnlocked)
    }

    @Test
    fun testTimedAutoLockPolicyExceedingTimeout() = runTest {
        lifecycleManager.policy = VaultAutoLockPolicy.THIRTY_SECONDS
        coordinator.setupPin(testUser, "123456", 6)
        assertTrue(coordinator.isUnlocked)

        var currentTime = 5000000L
        lifecycleManager.onAppBackgrounded(currentTime)

        // Foreground 35 seconds later (exceeds 30s timeout)
        currentTime += 35_000L
        lifecycleManager.onAppForegrounded(currentTime)

        // Must now be locked
        assertFalse("Vault must be locked after timeout expires", coordinator.isUnlocked)
        assertNull(coordinator.getActiveDek())
    }

    @Test
    fun testUserSessionTerminatedImmediatelyLocksVault() = runTest {
        coordinator.setupPin(testUser, "999888", 6)
        assertTrue(coordinator.isUnlocked)

        // Simulate user logout or switch
        lifecycleManager.onUserSessionTerminated()

        assertFalse("Vault must lock immediately on session termination", coordinator.isUnlocked)
        assertNull(coordinator.getActiveDek())
    }
}
