package com.arc.arc.vault

import com.arc.arc.core.datastore.IVaultPreferencesDataStore
import com.arc.arc.core.datastore.VaultConfig
import com.arc.arc.core.security.InMemoryMasterKeyProvider
import com.arc.arc.core.security.InvalidPinException
import com.arc.arc.core.security.KeystoreSecurityLevel
import com.arc.arc.core.security.VaultLockoutException
import com.arc.arc.core.security.VaultNotConfiguredException
import com.arc.arc.core.security.VaultPinManager
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Security audit verification test suite verifying Keystore security levels,
 * hardware backing assertions, rate limiting, and V1/V2 envelope invariants.
 */
class KeystoreSecurityVerificationTest {

    private class InMemoryVaultPrefs : IVaultPreferencesDataStore {
        private val configs = mutableMapOf<String, VaultConfig>()

        override fun getVaultConfigFlow(ownerUid: String): Flow<VaultConfig> =
            MutableStateFlow(configs[ownerUid] ?: VaultConfig())

        override suspend fun getVaultConfig(ownerUid: String): VaultConfig =
            configs[ownerUid] ?: VaultConfig()

        override suspend fun saveVaultConfig(
            ownerUid: String,
            pinLength: Int,
            saltHex: String,
            encryptedDek: String,
            formatVersion: Int
        ) {
            val current = configs[ownerUid] ?: VaultConfig()
            configs[ownerUid] = current.copy(
                pinLength = pinLength,
                saltHex = saltHex,
                encryptedDek = encryptedDek,
                formatVersion = formatVersion,
            )
        }

        override suspend fun setBiometricEnabled(
            ownerUid: String,
            enabled: Boolean,
            biometricEncryptedDek: String?
        ) {
            val current = configs[ownerUid] ?: VaultConfig()
            configs[ownerUid] = current.copy(
                isBiometricEnabled = enabled,
                biometricEncryptedDek = biometricEncryptedDek
            )
        }

        override suspend fun recordFailedAttempt(ownerUid: String, currentTimeMs: Long): VaultConfig {
            val current = configs[ownerUid] ?: VaultConfig()
            val newAttempts = current.failedAttempts + 1
            val lockoutDurationSec = when (newAttempts) {
                in 1..3 -> 0
                4 -> 30
                5 -> 60
                6 -> 300
                else -> 1800
            }
            val lockoutEnd = if (lockoutDurationSec > 0) currentTimeMs + (lockoutDurationSec * 1000L) else 0L
            val updated = current.copy(failedAttempts = newAttempts, lockoutUntilEpochMs = lockoutEnd)
            configs[ownerUid] = updated
            return updated
        }

        override suspend fun resetFailedAttempts(ownerUid: String) {
            val current = configs[ownerUid] ?: return
            configs[ownerUid] = current.copy(failedAttempts = 0, lockoutUntilEpochMs = 0L)
        }

        override suspend fun clearVaultConfig(ownerUid: String) {
            configs.remove(ownerUid)
        }
    }

    private lateinit var prefs: InMemoryVaultPrefs
    private val ownerUid = "shreyas_vault_user"

    @Before
    fun setUp() {
        prefs = InMemoryVaultPrefs()
    }

    @Test
    fun testKeystoreSecurityLevelClassification() {
        assertTrue("STRONGBOX must evaluate as hardware-backed", KeystoreSecurityLevel.STRONGBOX.isHardwareBacked)
        assertTrue("TRUSTED_ENVIRONMENT must evaluate as hardware-backed", KeystoreSecurityLevel.TRUSTED_ENVIRONMENT.isHardwareBacked)
        assertFalse("SOFTWARE must not evaluate as hardware-backed", KeystoreSecurityLevel.SOFTWARE.isHardwareBacked)
        assertFalse("UNKNOWN_OR_UNVERIFIED must not evaluate as hardware-backed", KeystoreSecurityLevel.UNKNOWN_OR_UNVERIFIED.isHardwareBacked)
    }

    @Test
    fun testInMemoryMasterKeyProviderSecurityLevels() {
        val hardwareProvider = InMemoryMasterKeyProvider(isHardwareBacked = true, securityLevel = KeystoreSecurityLevel.STRONGBOX)
        assertTrue(hardwareProvider.isHardwareBacked)
        assertEquals(KeystoreSecurityLevel.STRONGBOX, hardwareProvider.securityLevel)
        assertEquals(KeystoreSecurityLevel.STRONGBOX, hardwareProvider.getSecurityLevel("test_alias"))

        val softwareProvider = InMemoryMasterKeyProvider(isHardwareBacked = false, securityLevel = KeystoreSecurityLevel.SOFTWARE)
        assertFalse(softwareProvider.isHardwareBacked)
        assertEquals(KeystoreSecurityLevel.SOFTWARE, softwareProvider.securityLevel)
    }

    @Test
    fun testV2EnvelopeSetupAndVerification() = runBlocking {
        val masterKeyProvider = InMemoryMasterKeyProvider(isHardwareBacked = true, securityLevel = KeystoreSecurityLevel.STRONGBOX)
        val pinManager = VaultPinManager(prefs, masterKeyProvider)

        val pin = "1234"
        val setupResult = pinManager.setupPin(ownerUid, pin)
        assertTrue(setupResult.isSuccess)
        val initialDek = setupResult.getOrThrow()
        assertEquals(32, initialDek.size)

        // Verify that formatVersion is stored as V2 (hardware-bound)
        val storedConfig = prefs.getVaultConfig(ownerUid)
        assertTrue(storedConfig.isConfigured)
        assertEquals(VaultPinManager.FORMAT_VERSION_V2_KEYSTORE, storedConfig.formatVersion)

        // Verify correct PIN unwraps identical DEK
        val verifyResult = pinManager.verifyPin(ownerUid, pin)
        assertTrue(verifyResult.isSuccess)
        assertTrue(initialDek.contentEquals(verifyResult.getOrThrow()))
    }

    @Test
    fun testWrongPinTriggersLockoutAndResetOnSuccess() = runBlocking {
        val masterKeyProvider = InMemoryMasterKeyProvider(isHardwareBacked = true)
        val pinManager = VaultPinManager(prefs, masterKeyProvider)

        val pin = "5678"
        pinManager.setupPin(ownerUid, pin)

        // 3 failed attempts: no lockout yet
        for (i in 1..3) {
            val failResult = pinManager.verifyPin(ownerUid, "0000")
            assertTrue(failResult.isFailure)
            assertTrue(failResult.exceptionOrNull() is InvalidPinException)
        }
        assertEquals(3, prefs.getVaultConfig(ownerUid).failedAttempts)
        assertFalse(prefs.getVaultConfig(ownerUid).isLockedOut(System.currentTimeMillis()))

        // 4th failed attempt: triggers 30s lockout
        val now = System.currentTimeMillis()
        val fourthFail = pinManager.verifyPin(ownerUid, "0000", now)
        assertTrue(fourthFail.isFailure)
        assertEquals(4, prefs.getVaultConfig(ownerUid).failedAttempts)
        assertTrue(prefs.getVaultConfig(ownerUid).isLockedOut(now))

        // Subsequent attempt while locked out returns VaultLockoutException
        val lockedAttempt = pinManager.verifyPin(ownerUid, pin, now + 5000)
        assertTrue(lockedAttempt.isFailure)
        assertTrue(lockedAttempt.exceptionOrNull() is VaultLockoutException)

        // After lockout expires, correct PIN resets failed attempts
        val afterExpiry = now + 35000
        val successResult = pinManager.verifyPin(ownerUid, pin, afterExpiry)
        assertTrue(successResult.isSuccess)
        assertEquals(0, prefs.getVaultConfig(ownerUid).failedAttempts)
        assertFalse(prefs.getVaultConfig(ownerUid).isLockedOut(afterExpiry))
    }

    @Test
    fun testV2VaultRequiresMasterKeyProvider() = runBlocking {
        // Setup vault in V2
        val masterKeyProvider = InMemoryMasterKeyProvider(isHardwareBacked = true)
        val pinManager = VaultPinManager(prefs, masterKeyProvider)
        pinManager.setupPin(ownerUid, "9876")

        // Try to unlock with a PinManager that has NO masterKeyProvider (e.g. key invalidated or missing)
        val unprovisionedPinManager = VaultPinManager(prefs, null)
        val result = unprovisionedPinManager.verifyPin(ownerUid, "9876")

        assertTrue(result.isFailure)
        // Must fail with GeneralSecurityException and not silently fall back to unencrypted V1
        assertNotNull(result.exceptionOrNull())
    }
}
