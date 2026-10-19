package com.arc.arc.vault

import com.arc.arc.core.datastore.IVaultPreferencesDataStore
import com.arc.arc.core.datastore.VaultConfig
import com.arc.arc.core.security.BiometricAuthManager
import com.arc.arc.core.security.InvalidPinException
import com.arc.arc.core.security.VaultAuthCoordinator
import com.arc.arc.core.security.VaultAuthState
import com.arc.arc.core.security.VaultLockoutException
import com.arc.arc.core.security.VaultNotConfiguredException
import com.arc.arc.core.security.VaultPinManager
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

/**
 * In-memory implementation of [IVaultPreferencesDataStore] for lightning-fast, isolated unit testing.
 */
class InMemoryVaultPreferencesDataStore : IVaultPreferencesDataStore {
    private val store = MutableStateFlow<Map<String, VaultConfig>>(emptyMap())

    override fun getVaultConfigFlow(ownerUid: String): Flow<VaultConfig> = store.map { map ->
        map[ownerUid] ?: VaultConfig()
    }

    override suspend fun getVaultConfig(ownerUid: String): VaultConfig =
        getVaultConfigFlow(ownerUid).first()

    override suspend fun saveVaultConfig(
        ownerUid: String,
        pinLength: Int,
        saltHex: String,
        encryptedDek: String,
        formatVersion: Int,
    ) {
        val current = store.value.toMutableMap()
        val existing = current[ownerUid] ?: VaultConfig()
        current[ownerUid] = existing.copy(
            pinLength = pinLength,
            saltHex = saltHex,
            encryptedDek = encryptedDek,
            failedAttempts = 0,
            lockoutUntilEpochMs = 0L,
            formatVersion = formatVersion,
        )
        store.value = current
    }

    override suspend fun setBiometricEnabled(
        ownerUid: String,
        enabled: Boolean,
        biometricEncryptedDek: String?
    ) {
        val current = store.value.toMutableMap()
        val existing = current[ownerUid] ?: VaultConfig()
        current[ownerUid] = existing.copy(
            isBiometricEnabled = enabled,
            biometricEncryptedDek = biometricEncryptedDek
        )
        store.value = current
    }

    override suspend fun recordFailedAttempt(ownerUid: String, currentTimeMs: Long): VaultConfig {
        val current = store.value.toMutableMap()
        val existing = current[ownerUid] ?: VaultConfig()
        val attempts = existing.failedAttempts + 1

        val lockoutSeconds = when {
            attempts >= 7 -> 120L
            attempts == 6 -> 60L
            attempts == 5 -> 30L
            else -> 0L
        }
        val lockoutUntil = if (lockoutSeconds > 0) currentTimeMs + (lockoutSeconds * 1000L) else 0L

        val updated = existing.copy(
            failedAttempts = attempts,
            lockoutUntilEpochMs = lockoutUntil
        )
        current[ownerUid] = updated
        store.value = current
        return updated
    }

    override suspend fun resetFailedAttempts(ownerUid: String) {
        val current = store.value.toMutableMap()
        val existing = current[ownerUid] ?: VaultConfig()
        current[ownerUid] = existing.copy(
            failedAttempts = 0,
            lockoutUntilEpochMs = 0L
        )
        store.value = current
    }

    override suspend fun clearVaultConfig(ownerUid: String) {
        val current = store.value.toMutableMap()
        current.remove(ownerUid)
        store.value = current
    }
}

class VaultAuthTest {

    private lateinit var preferencesStore: InMemoryVaultPreferencesDataStore
    private lateinit var pinManager: VaultPinManager
    private lateinit var coordinator: VaultAuthCoordinator

    private val userAlice = "user-alice-123"
    private val userBob = "user-bob-456"

    @Before
    fun setUp() {
        preferencesStore = InMemoryVaultPreferencesDataStore()
        pinManager = VaultPinManager(preferencesStore)
        coordinator = VaultAuthCoordinator(pinManager, preferencesStore)
    }

    @Test
    fun testPinValidationRules() {
        // Valid PINs (3 to 6 digits)
        assertTrue(pinManager.validatePinFormat("123").isSuccess)
        assertTrue(pinManager.validatePinFormat("1234").isSuccess)
        assertTrue(pinManager.validatePinFormat("12345").isSuccess)
        assertTrue(pinManager.validatePinFormat("123456").isSuccess)

        // Invalid: non-digits
        assertFalse(pinManager.validatePinFormat("12a").isSuccess)
        assertFalse(pinManager.validatePinFormat("abcd").isSuccess)
        assertFalse(pinManager.validatePinFormat("12 45").isSuccess)

        // Invalid: length out of range
        assertFalse(pinManager.validatePinFormat("12").isSuccess) // too short (<3)
        assertFalse(pinManager.validatePinFormat("1234567").isSuccess) // too long (>6)

        // Invalid: mismatched expected length
        assertFalse(pinManager.validatePinFormat("1234", expectedLength = 6).isSuccess)
        assertTrue(pinManager.validatePinFormat("1234", expectedLength = 4).isSuccess)
    }

    @Test
    fun testVariablePinLengthSetupAndUnlock() = runTest {
        // Test 3-digit PIN setup
        val setup3 = pinManager.setupPin(userAlice, "789", 3)
        assertTrue(setup3.isSuccess)
        val dek3 = setup3.getOrThrow()
        assertEquals(32, dek3.size)

        // Unlock with 3-digit PIN
        val unlock3 = pinManager.verifyPin(userAlice, "789")
        assertTrue(unlock3.isSuccess)
        assertArrayEquals(dek3, unlock3.getOrThrow())

        // Test 6-digit PIN setup for Bob
        val setup6 = pinManager.setupPin(userBob, "123456", 6)
        assertTrue(setup6.isSuccess)
        val dek6 = setup6.getOrThrow()
        assertEquals(32, dek6.size)

        val unlock6 = pinManager.verifyPin(userBob, "123456")
        assertTrue(unlock6.isSuccess)
        assertArrayEquals(dek6, unlock6.getOrThrow())
    }

    @Test
    fun testIncorrectPinFailsAndIncrementsAttempts() = runTest {
        pinManager.setupPin(userAlice, "987654", 6)

        val failedVerify = pinManager.verifyPin(userAlice, "111111")
        assertTrue(failedVerify.isFailure)
        val exception = failedVerify.exceptionOrNull()
        assertTrue(exception is InvalidPinException)
        assertEquals(1, (exception as InvalidPinException).attempts)
        assertEquals(0L, exception.lockoutSeconds)

        val config = preferencesStore.getVaultConfig(userAlice)
        assertEquals(1, config.failedAttempts)
    }

    @Test
    fun testPersistentLockoutEnforcement() = runTest {
        pinManager.setupPin(userAlice, "123456", 6)
        var currentTime = 1000000L

        // Attempts 1 to 4: failed attempts increment, no lockout
        for (i in 1..4) {
            val res = pinManager.verifyPin(userAlice, "000000", currentTime)
            assertTrue(res.isFailure)
            val ex = res.exceptionOrNull() as InvalidPinException
            assertEquals(i, ex.attempts)
            assertEquals(0L, ex.lockoutSeconds)
        }

        // Attempt 5: triggers 30-second lockout
        val res5 = pinManager.verifyPin(userAlice, "000000", currentTime)
        assertTrue(res5.isFailure)
        val ex5 = res5.exceptionOrNull() as InvalidPinException
        assertEquals(5, ex5.attempts)
        assertEquals(30L, ex5.lockoutSeconds)

        val config5 = preferencesStore.getVaultConfig(userAlice)
        assertTrue(config5.isLockedOut(currentTime))
        assertEquals(currentTime + 30_000L, config5.lockoutUntilEpochMs)

        // Attempting during active lockout fails immediately with VaultLockoutException
        val lockedOutAttempt = pinManager.verifyPin(userAlice, "123456", currentTime + 10_000L)
        assertTrue(lockedOutAttempt.isFailure)
        val lockoutEx = lockedOutAttempt.exceptionOrNull()
        assertTrue(lockoutEx is VaultLockoutException)
        assertEquals(20L, (lockoutEx as VaultLockoutException).remainingSeconds)

        // Advance time past the 30s lockout (e.g. 31s later) -> attempt 6
        currentTime += 31_000L
        val res6 = pinManager.verifyPin(userAlice, "000000", currentTime)
        assertTrue(res6.isFailure)
        val ex6 = res6.exceptionOrNull() as InvalidPinException
        assertEquals(6, ex6.attempts)
        assertEquals(60L, ex6.lockoutSeconds) // 60s lockout for attempt 6

        // Advance past 60s lockout -> attempt 7
        currentTime += 61_000L
        val res7 = pinManager.verifyPin(userAlice, "000000", currentTime)
        assertTrue(res7.isFailure)
        val ex7 = res7.exceptionOrNull() as InvalidPinException
        assertEquals(7, ex7.attempts)
        assertEquals(120L, ex7.lockoutSeconds) // 120s lockout for attempt 7+

        // Advance past 120s lockout and enter CORRECT PIN -> resets failed attempts
        currentTime += 121_000L
        val successRes = pinManager.verifyPin(userAlice, "123456", currentTime)
        assertTrue(successRes.isSuccess)
        val resetConfig = preferencesStore.getVaultConfig(userAlice)
        assertEquals(0, resetConfig.failedAttempts)
        assertEquals(0L, resetConfig.lockoutUntilEpochMs)
    }

    @Test
    fun testChangePinPreservesUnderlyingDek() = runTest {
        val initialSetup = pinManager.setupPin(userAlice, "111222", 6)
        val originalDek = initialSetup.getOrThrow()

        // Change PIN from 111222 to 999888
        val changeResult = pinManager.changePin(userAlice, "111222", "999888", 6)
        assertTrue(changeResult.isSuccess)
        val preservedDek = changeResult.getOrThrow()
        assertArrayEquals("DEK must remain identical after PIN change", originalDek, preservedDek)

        // Old PIN no longer works
        val oldPinAttempt = pinManager.verifyPin(userAlice, "111222")
        assertTrue(oldPinAttempt.isFailure)

        // New PIN works and returns identical DEK
        val newPinAttempt = pinManager.verifyPin(userAlice, "999888")
        assertTrue(newPinAttempt.isSuccess)
        assertArrayEquals(originalDek, newPinAttempt.getOrThrow())
    }

    @Test
    fun testVaultAuthCoordinatorStateMachine() = runTest {
        coordinator.refreshState(userAlice)
        assertEquals(VaultAuthState.Unconfigured, coordinator.authState.value)
        assertFalse(coordinator.isUnlocked)

        // Setup PIN
        val setupResult = coordinator.setupPin(userAlice, "654321", 6)
        assertTrue(setupResult.isSuccess)
        assertTrue(coordinator.isUnlocked)
        val stateUnlocked = coordinator.authState.value as VaultAuthState.Unlocked
        val activeDek = stateUnlocked.activeDek.clone()
        assertEquals(32, activeDek.size)

        // Lock vault -> active key should be wiped with zeroes
        coordinator.lock()
        assertEquals(VaultAuthState.Locked, coordinator.authState.value)
        assertFalse(coordinator.isUnlocked)
        assertNull(coordinator.getActiveDek())
        // Verify in-memory zeroing
        assertTrue("In-memory DEK must be zeroed on lock", stateUnlocked.activeDek.all { it == 0.toByte() })

        // Unlock with PIN
        val unlockResult = coordinator.unlockWithPin(userAlice, "654321")
        assertTrue(unlockResult.isSuccess)
        assertTrue(coordinator.isUnlocked)
        assertArrayEquals(activeDek, coordinator.getActiveDek())
    }

    @Test
    fun testBiometricSinglePromptCasGuard() {
        val biometricManager = BiometricAuthManager()

        // First prompt check: succeeds (takes lock)
        assertTrue(biometricManager.canPrompt())

        // Concurrent/duplicate prompt check: fails (lock already held!)
        // Defense against Flutter legacy issue 1 (double prompt race condition)
        assertFalse(biometricManager.canPrompt())
        assertFalse(biometricManager.canPrompt())

        // Prompt dismissed / completed: releases lock
        biometricManager.onPromptDismissed()

        // Next prompt is permitted
        assertTrue(biometricManager.canPrompt())
        biometricManager.onPromptDismissed()
    }

    @Test
    fun testMultiUserVaultIsolation() = runTest {
        coordinator.setupPin(userAlice, "111111", 6)
        coordinator.lock()

        val bobPreferencesStore = InMemoryVaultPreferencesDataStore()
        val bobPinManager = VaultPinManager(bobPreferencesStore)
        val bobCoordinator = VaultAuthCoordinator(bobPinManager, bobPreferencesStore)
        bobCoordinator.setupPin(userBob, "222222", 6)
        bobCoordinator.lock()

        // Alice cannot unlock with Bob's PIN
        val aliceWithBobPin = coordinator.unlockWithPin(userAlice, "222222")
        assertTrue(aliceWithBobPin.isFailure)

        // Bob cannot unlock with Alice's PIN
        val bobWithAlicePin = bobCoordinator.unlockWithPin(userBob, "111111")
        assertTrue(bobWithAlicePin.isFailure)

        // Both unlock with their own PIN
        assertTrue(coordinator.unlockWithPin(userAlice, "111111").isSuccess)
        assertTrue(bobCoordinator.unlockWithPin(userBob, "222222").isSuccess)
    }
}
