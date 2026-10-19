package com.arc.arc.vault

import com.arc.arc.core.datastore.IVaultPreferencesDataStore
import com.arc.arc.core.datastore.VaultConfig
import com.arc.arc.core.security.VaultAuthCoordinator
import com.arc.arc.core.security.VaultAuthState
import com.arc.arc.core.security.VaultCryptoEngine
import com.arc.arc.core.security.VaultPinManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.security.GeneralSecurityException
import java.util.Base64

/**
 * Synthetic security audit tests reproducing threat-model assumptions and verifying
 * cryptographic invariants of ARC's Secret Vault.
 */
class VaultSecurityAuditTest {

    private lateinit var dataStore: InMemoryVaultPreferencesDataStore
    private lateinit var pinManager: VaultPinManager
    private lateinit var authCoordinator: VaultAuthCoordinator

    @Before
    fun setup() {
        dataStore = InMemoryVaultPreferencesDataStore()
        pinManager = VaultPinManager(dataStore)
        authCoordinator = VaultAuthCoordinator(pinManager, dataStore)
    }


    @Test
    fun `offline brute force vulnerability demonstration - low entropy PIN can be cracked offline without rate limit triggers`() = runBlocking {
        // Victim configures vault with a 4-digit PIN "2580"
        val ownerUid = "victim_user_123"
        val targetPin = "2580"
        val setupResult = pinManager.setupPin(ownerUid, targetPin, 4)
        assertTrue("Setup must succeed", setupResult.isSuccess)
        val trueDek = setupResult.getOrThrow()

        // Attacker extracts stored preferences from device flash storage (offline scenario)
        val extractedConfig = dataStore.getVaultConfig(ownerUid)
        assertTrue(extractedConfig.isConfigured)
        val extractedSalt = VaultCryptoEngine.hexToBytes(extractedConfig.saltHex!!)
        val extractedEncryptedDek = extractedConfig.encryptedDek!!

        // Attacker runs an offline cracking loop against candidate PINs
        // Demonstrating that offline decryption succeeds without incrementing dataStore.failedAttempts
        var crackedDek: ByteArray? = null
        var foundPin: String? = null

        // Test candidate space around target PIN (e.g. 2570..2590)
        for (candidateInt in 2575..2585) {
            val candidatePin = candidateInt.toString()
            try {
                // PBKDF2 derivation with extracted salt
                val candidateKek = VaultCryptoEngine.deriveKeyFromPin(
                    pin = candidatePin.toCharArray(),
                    salt = extractedSalt,
                    iterations = VaultCryptoEngine.DEFAULT_PBKDF2_ITERATIONS
                )
                // Attempt unwrapping
                val decryptedDekBase64 = VaultCryptoEngine.decryptFromString(extractedEncryptedDek, candidateKek)
                crackedDek = Base64.getDecoder().decode(decryptedDekBase64)
                foundPin = candidatePin
                break // Success!
            } catch (e: GeneralSecurityException) {
                // Expected failure for wrong candidate (AEAD tag mismatch)
            }
        }

        assertNotNull("Offline cracking must recover the target PIN", foundPin)
        assertEquals("Recovered PIN must match target", targetPin, foundPin)
        assertArrayEquals("Cracked DEK must match true DEK exactly", trueDek, crackedDek)

        // CRITICAL AUDIT FINDING:
        // Because the brute-force attack ran offline against extracted artifacts,
        // the application-level failed attempts counter was NEVER incremented!
        val postAttackConfig = dataStore.getVaultConfig(ownerUid)
        assertEquals("Application rate limiter was completely bypassed offline", 0, postAttackConfig.failedAttempts)
        assertEquals("Application lockout was not triggered", 0L, postAttackConfig.lockoutUntilEpochMs)
    }

    @Test
    fun `tampering with encrypted envelope payload causes AEAD tag verification failure`() = runBlocking {
        val ownerUid = "user_tamper_test"
        val pin = "1234"
        pinManager.setupPin(ownerUid, pin, 4)

        val config = dataStore.getVaultConfig(ownerUid)
        val rawEnvelope = Base64.getDecoder().decode(config.encryptedDek!!)

        // Tamper with the last byte (part of the GCM authentication tag)
        rawEnvelope[rawEnvelope.size - 1] = (rawEnvelope[rawEnvelope.size - 1].toInt() xor 0xFF).toByte()
        val tamperedEncryptedDek = Base64.getEncoder().encodeToString(rawEnvelope)

        dataStore.saveVaultConfig(
            ownerUid = ownerUid,
            pinLength = 4,
            saltHex = config.saltHex!!,
            encryptedDek = tamperedEncryptedDek
        )

        val unlockResult = pinManager.verifyPin(ownerUid, pin)
        assertTrue("Tampered ciphertext must fail verification", unlockResult.isFailure)
    }

    @Test
    fun `vault coordinator zeroizes active DEK from memory upon locking`() = runBlocking {
        val ownerUid = "user_mem_test"
        val pin = "9876"
        val setupResult = authCoordinator.setupPin(ownerUid, pin, 4)
        assertTrue(setupResult.isSuccess)

        val activeDek = authCoordinator.getActiveDek()
        assertNotNull("DEK must be present in unlocked state", activeDek)
        assertTrue("DEK must not be all zeros", activeDek!!.any { it != 0.toByte() })

        // Capture reference to byte array
        val capturedArray = activeDek

        // Lock vault
        authCoordinator.lock()
        assertEquals(VaultAuthState.Locked, authCoordinator.authState.value)
        assertNull("Active DEK must be null after locking", authCoordinator.getActiveDek())

        // Verify the underlying byte array was wiped with zeros
        assertTrue("Underlying DEK bytes in memory must be overwritten with zeros", capturedArray.all { it == 0.toByte() })
    }

    @Test
    fun `cross-user vault isolation prevents User A from decrypting User B vault`() = runBlocking {
        val userA = "user_A"
        val userB = "user_B"

        pinManager.setupPin(userA, "1111", 4)
        pinManager.setupPin(userB, "2222", 4)

        // User A tries to unlock User B using User A's PIN
        val attackResult = pinManager.verifyPin(userB, "1111")
        assertTrue("User A PIN must fail against User B vault", attackResult.isFailure)

        val configB = dataStore.getVaultConfig(userB)
        assertEquals("Failed attempt recorded on target user", 1, configB.failedAttempts)
    }
}
