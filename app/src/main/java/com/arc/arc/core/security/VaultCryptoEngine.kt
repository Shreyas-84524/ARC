package com.arc.arc.core.security

import java.security.GeneralSecurityException
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Production-grade authenticated cryptographic engine for ARC's Secret Vault.
 *
 * Cryptographic Invariants:
 * 1. Cipher: AES-256-GCM (AES/GCM/NoPadding) with authenticated integrity check.
 * 2. Nonce/IV: 96-bit (12-byte) cryptographically unique random nonce per encryption operation.
 * 3. Tag: 128-bit authentication tag appended by the GCM cipher.
 * 4. Key Derivation: PBKDF2WithHmacSHA256 (RFC 2898) with 100,000 iterations and 32-byte salt.
 * 5. Envelope Format:
 *    [Version (1 byte)][Nonce/IV (12 bytes)][Ciphertext + GCM Tag (N bytes)]
 */
object VaultCryptoEngine {

    const val ENVELOPE_VERSION_V1: Byte = 0x01
    const val GCM_IV_LENGTH_BYTES = 12 // 96 bits
    const val GCM_TAG_LENGTH_BITS = 128 // 16 bytes
    const val KEY_LENGTH_BITS = 256
    const val KEY_LENGTH_BYTES = 32
    const val DEFAULT_PBKDF2_ITERATIONS = 100_000
    const val SALT_LENGTH_BYTES = 32

    private const val MIN_ENVELOPE_LENGTH = 1 + GCM_IV_LENGTH_BYTES + (GCM_TAG_LENGTH_BITS / 8) // 29 bytes

    private val secureRandom = SecureRandom()

    /**
     * Generates a cryptographically secure random salt of [lengthBytes].
     */
    fun generateSalt(lengthBytes: Int = SALT_LENGTH_BYTES): ByteArray {
        val salt = ByteArray(lengthBytes)
        secureRandom.nextBytes(salt)
        return salt
    }

    /**
     * Generates a random 256-bit AES data encryption key (DEK).
     */
    fun generateDataEncryptionKey(): SecretKey {
        val keyBytes = ByteArray(KEY_LENGTH_BYTES)
        secureRandom.nextBytes(keyBytes)
        return SecretKeySpec(keyBytes, "AES")
    }

    /**
     * Derives a 256-bit AES key from a PIN using PBKDF2WithHmacSHA256.
     */
    fun deriveKeyFromPin(
        pin: CharArray,
        salt: ByteArray,
        iterations: Int = DEFAULT_PBKDF2_ITERATIONS,
    ): SecretKey {
        require(pin.isNotEmpty()) { "PIN cannot be empty" }
        require(salt.size >= 16) { "Salt must be at least 16 bytes" }
        require(iterations >= 10_000) { "Iterations must be at least 10,000" }

        val factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val spec = PBEKeySpec(pin, salt, iterations, KEY_LENGTH_BITS)
        val secretKey = factory.generateSecret(spec)
        return SecretKeySpec(secretKey.encoded, "AES")
    }

    /**
     * Converts a 32-byte array to an AES [SecretKey].
     */
    fun toSecretKey(keyBytes: ByteArray): SecretKey {
        require(keyBytes.size == KEY_LENGTH_BYTES) { "Key must be exactly $KEY_LENGTH_BYTES bytes (256-bit)" }
        return SecretKeySpec(keyBytes, "AES")
    }

    /**
     * Encrypts plaintext bytes into a versioned AES-GCM envelope.
     * Enforces unique 12-byte IV per invocation.
     */
    fun encrypt(plaintext: ByteArray, key: SecretKey): ByteArray {
        val iv = ByteArray(GCM_IV_LENGTH_BYTES)
        secureRandom.nextBytes(iv)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val spec = GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv)
        cipher.init(Cipher.ENCRYPT_MODE, key, spec)

        val ciphertextWithTag = cipher.doFinal(plaintext)

        val envelope = ByteArray(1 + iv.size + ciphertextWithTag.size)
        envelope[0] = ENVELOPE_VERSION_V1
        System.arraycopy(iv, 0, envelope, 1, iv.size)
        System.arraycopy(ciphertextWithTag, 0, envelope, 1 + iv.size, ciphertextWithTag.size)

        return envelope
    }

    fun encrypt(plaintext: ByteArray, keyBytes: ByteArray): ByteArray =
        encrypt(plaintext, toSecretKey(keyBytes))

    /**
     * Encrypts a string into a Base64-encoded versioned envelope.
     */
    fun encryptToString(plaintext: String, key: SecretKey): String {
        val encryptedBytes = encrypt(plaintext.toByteArray(Charsets.UTF_8), key)
        return Base64.getEncoder().encodeToString(encryptedBytes)
    }

    fun encryptToString(plaintext: String, keyBytes: ByteArray): String =
        encryptToString(plaintext, toSecretKey(keyBytes))

    /**
     * Decrypts a versioned AES-GCM envelope.
     * Validates version, extracts IV, and verifies GCM authentication tag.
     */
    @Throws(GeneralSecurityException::class)
    fun decrypt(envelope: ByteArray, key: SecretKey): ByteArray {
        if (envelope.size < MIN_ENVELOPE_LENGTH) {
            throw GeneralSecurityException("Invalid envelope: payload too short (${envelope.size} bytes)")
        }

        val version = envelope[0]
        if (version != ENVELOPE_VERSION_V1) {
            throw GeneralSecurityException("Unsupported envelope version: $version")
        }

        val iv = ByteArray(GCM_IV_LENGTH_BYTES)
        System.arraycopy(envelope, 1, iv, 0, GCM_IV_LENGTH_BYTES)

        val ciphertextOffset = 1 + GCM_IV_LENGTH_BYTES
        val ciphertextLength = envelope.size - ciphertextOffset
        val ciphertextWithTag = ByteArray(ciphertextLength)
        System.arraycopy(envelope, ciphertextOffset, ciphertextWithTag, 0, ciphertextLength)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val spec = GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)

        return try {
            cipher.doFinal(ciphertextWithTag)
        } catch (e: AEADBadTagException) {
            throw GeneralSecurityException("Ciphertext integrity verification failed (tampered data or wrong key)", e)
        } catch (e: Exception) {
            throw GeneralSecurityException("Decryption failed: ${e.message}", e)
        }
    }

    @Throws(GeneralSecurityException::class)
    fun decrypt(envelope: ByteArray, keyBytes: ByteArray): ByteArray =
        decrypt(envelope, toSecretKey(keyBytes))

    /**
     * Decrypts a Base64-encoded envelope into a plaintext string.
     */
    @Throws(GeneralSecurityException::class)
    fun decryptFromString(envelopeString: String, key: SecretKey): String {
        val envelopeBytes = try {
            Base64.getDecoder().decode(envelopeString.trim())
        } catch (e: Exception) {
            throw GeneralSecurityException("Malformed Base64 envelope", e)
        }
        val decryptedBytes = decrypt(envelopeBytes, key)
        return String(decryptedBytes, Charsets.UTF_8)
    }

    @Throws(GeneralSecurityException::class)
    fun decryptFromString(envelopeString: String, keyBytes: ByteArray): String =
        decryptFromString(envelopeString, toSecretKey(keyBytes))

    /**
     * Constant-time comparison between two byte arrays to prevent timing attacks.
     */
    fun constantTimeEquals(a: ByteArray, b: ByteArray): Boolean {
        if (a.size != b.size) return false
        var result = 0
        for (i in a.indices) {
            result = result or (a[i].toInt() xor b[i].toInt())
        }
        return result == 0
    }

    /**
     * Converts byte array to lowercase hexadecimal string.
     */
    fun bytesToHex(bytes: ByteArray): String {
        val hexChars = CharArray(bytes.size * 2)
        val lookup = "0123456789abcdef"
        for (i in bytes.indices) {
            val v = bytes[i].toInt() and 0xFF
            hexChars[i * 2] = lookup[v ushr 4]
            hexChars[i * 2 + 1] = lookup[v and 0x0F]
        }
        return String(hexChars)
    }

    /**
     * Converts hexadecimal string to byte array.
     */
    fun hexToBytes(hex: String): ByteArray {
        val clean = hex.trim()
        val len = clean.length
        require(len % 2 == 0) { "Hex string must have an even length" }
        val data = ByteArray(len / 2)
        for (i in 0 until len step 2) {
            val h = Character.digit(clean[i], 16)
            val l = Character.digit(clean[i + 1], 16)
            require(h != -1 && l != -1) { "Invalid hex character at index $i" }
            data[i / 2] = ((h shl 4) + l).toByte()
        }
        return data
    }
}
