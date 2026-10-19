package com.arc.arc.core.security

import javax.crypto.SecretKey

/**
 * Security level classification for Android Keystore master wrapping keys.
 */
enum class KeystoreSecurityLevel {
    STRONGBOX,
    TRUSTED_ENVIRONMENT,
    SOFTWARE,
    UNKNOWN_OR_UNVERIFIED;

    val isHardwareBacked: Boolean
        get() = this == STRONGBOX || this == TRUSTED_ENVIRONMENT
}

/**
 * Contract for acquiring or generating hardware-backed master wrapping keys.
 *
 * CRITICAL DEFENSE-IN-DEPTH:
 * Shields small-PIN vaults against offline dictionary attacks. The master key is rooted
 * in hardware (TEE / StrongBox) and cannot be extracted from flash storage dumps.
 */
interface IVaultMasterKeyProvider {
    val isHardwareBacked: Boolean
    val securityLevel: KeystoreSecurityLevel
        get() = if (isHardwareBacked) KeystoreSecurityLevel.TRUSTED_ENVIRONMENT else KeystoreSecurityLevel.SOFTWARE

    fun getOrCreateMasterKey(alias: String): SecretKey
    fun deleteMasterKey(alias: String)
    fun getSecurityLevel(alias: String): KeystoreSecurityLevel = securityLevel
}

/**
 * In-memory provider for unit tests and local JVM execution.
 */
class InMemoryMasterKeyProvider(
    override val isHardwareBacked: Boolean = false,
    override val securityLevel: KeystoreSecurityLevel = if (isHardwareBacked) KeystoreSecurityLevel.TRUSTED_ENVIRONMENT else KeystoreSecurityLevel.SOFTWARE
) : IVaultMasterKeyProvider {
    private val keys = mutableMapOf<String, SecretKey>()

    override fun getOrCreateMasterKey(alias: String): SecretKey {
        return keys.getOrPut(alias) {
            VaultCryptoEngine.generateDataEncryptionKey()
        }
    }

    override fun deleteMasterKey(alias: String) {
        keys.remove(alias)
    }

    override fun getSecurityLevel(alias: String): KeystoreSecurityLevel = securityLevel
}
