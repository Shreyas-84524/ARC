package com.arc.arc.vault

import com.arc.arc.core.security.VaultCryptoEngine
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.security.GeneralSecurityException
import javax.crypto.spec.SecretKeySpec

class VaultCryptoTest {

    @Test
    fun encryptAndDecrypt_returnsOriginalPlaintext() {
        val key = VaultCryptoEngine.generateDataEncryptionKey()
        val originalText = "Top-Secret Vault Passphrase: correct-horse-battery-staple-99"

        val encryptedEnvelope = VaultCryptoEngine.encryptToString(originalText, key)
        val decryptedText = VaultCryptoEngine.decryptFromString(encryptedEnvelope, key)

        assertEquals(originalText, decryptedText)
    }

    @Test
    fun encryptTwice_samePlaintextAndKey_generatesDifferentNoncesAndCiphertext() {
        val key = VaultCryptoEngine.generateDataEncryptionKey()
        val originalText = "Confidential Note Content"

        val envelope1 = VaultCryptoEngine.encryptToString(originalText, key)
        val envelope2 = VaultCryptoEngine.encryptToString(originalText, key)

        // Nonces must be unique per AES-GCM specification
        assertNotEquals(envelope1, envelope2)

        // Both envelopes must decrypt back to the identical plaintext
        assertEquals(originalText, VaultCryptoEngine.decryptFromString(envelope1, key))
        assertEquals(originalText, VaultCryptoEngine.decryptFromString(envelope2, key))
    }

    @Test(expected = GeneralSecurityException::class)
    fun decrypt_tamperedCiphertext_throwsIntegrityException() {
        val key = VaultCryptoEngine.generateDataEncryptionKey()
        val originalText = "Sensitive bank PIN: 9944"

        val envelopeBytes = VaultCryptoEngine.encrypt(originalText.toByteArray(), key)

        // Tamper with the last byte of ciphertext/tag
        envelopeBytes[envelopeBytes.size - 1] = (envelopeBytes[envelopeBytes.size - 1].toInt() xor 0xFF).toByte()

        // Decryption must reject the tampered payload
        VaultCryptoEngine.decrypt(envelopeBytes, key)
    }

    @Test(expected = GeneralSecurityException::class)
    fun decrypt_wrongKey_throwsIntegrityException() {
        val key1 = VaultCryptoEngine.generateDataEncryptionKey()
        val key2 = VaultCryptoEngine.generateDataEncryptionKey()
        val originalText = "Secret payload"

        val envelope = VaultCryptoEngine.encryptToString(originalText, key1)

        // Attempt decryption with wrong key
        VaultCryptoEngine.decryptFromString(envelope, key2)
    }

    @Test(expected = GeneralSecurityException::class)
    fun decrypt_truncatedEnvelope_throwsSecurityException() {
        val key = VaultCryptoEngine.generateDataEncryptionKey()
        val invalidEnvelope = ByteArray(10) // Too short (< 29 bytes)

        VaultCryptoEngine.decrypt(invalidEnvelope, key)
    }

    @Test(expected = GeneralSecurityException::class)
    fun decrypt_unsupportedVersion_throwsSecurityException() {
        val key = VaultCryptoEngine.generateDataEncryptionKey()
        val envelope = VaultCryptoEngine.encrypt("Test".toByteArray(), key)
        envelope[0] = 0x99.toByte() // Invalid version

        VaultCryptoEngine.decrypt(envelope, key)
    }

    @Test
    fun pbkdf2KeyDerivation_isDeterministicAndSaltSensitive() {
        val pin = "845241".toCharArray()
        val salt1 = VaultCryptoEngine.generateSalt()
        val salt2 = VaultCryptoEngine.generateSalt()

        val key1 = VaultCryptoEngine.deriveKeyFromPin(pin, salt1, iterations = 10_000)
        val key1Repeat = VaultCryptoEngine.deriveKeyFromPin(pin, salt1, iterations = 10_000)
        val key2 = VaultCryptoEngine.deriveKeyFromPin(pin, salt2, iterations = 10_000)

        // Same PIN + same salt -> identical key
        assertArrayEquals(key1.encoded, key1Repeat.encoded)

        // Same PIN + different salt -> distinct key
        assertFalse(key1.encoded.contentEquals(key2.encoded))
    }

    @Test
    fun constantTimeEquals_validatesMatchesAndMismatches() {
        val a = byteArrayOf(1, 2, 3, 4, 5)
        val b = byteArrayOf(1, 2, 3, 4, 5)
        val c = byteArrayOf(1, 2, 3, 4, 6)
        val d = byteArrayOf(1, 2, 3)

        assertTrue(VaultCryptoEngine.constantTimeEquals(a, b))
        assertFalse(VaultCryptoEngine.constantTimeEquals(a, c))
        assertFalse(VaultCryptoEngine.constantTimeEquals(a, d))
    }

    @Test
    fun hexEncodingAndDecoding_roundTripsCleanly() {
        val bytes = byteArrayOf(0x00, 0x0F, 0x1A, 0x7F, 0x80.toByte(), 0xFF.toByte())
        val hex = VaultCryptoEngine.bytesToHex(bytes)
        assertEquals("000f1a7f80ff", hex)

        val decoded = VaultCryptoEngine.hexToBytes(hex)
        assertArrayEquals(bytes, decoded)
    }
}
