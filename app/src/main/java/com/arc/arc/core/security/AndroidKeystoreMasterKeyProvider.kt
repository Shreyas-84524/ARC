package com.arc.arc.core.security

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory

/**
 * Android Keystore-backed implementation of [IVaultMasterKeyProvider].
 *
 * Keys generated here reside in the device hardware Trusted Execution Environment (TEE)
 * or StrongBox Keymaster, preventing key material exfiltration even if root or physical storage
 * access is achieved.
 *
 * SECURITY AUDIT REMEDIATION (Phase 6):
 * Real hardware backing is dynamically inspected via [KeyInfo] rather than relying on a
 * static/hardcoded assertion.
 */
class AndroidKeystoreMasterKeyProvider(
    private val keyStoreType: String = "AndroidKeyStore"
) : IVaultMasterKeyProvider {

    private val keyStore: KeyStore by lazy {
        KeyStore.getInstance(keyStoreType).apply { load(null) }
    }

    private var cachedSecurityLevel: KeystoreSecurityLevel = KeystoreSecurityLevel.UNKNOWN_OR_UNVERIFIED

    override val isHardwareBacked: Boolean
        get() = securityLevel.isHardwareBacked

    override val securityLevel: KeystoreSecurityLevel
        get() = cachedSecurityLevel

    @Synchronized
    override fun getOrCreateMasterKey(alias: String): SecretKey {
        if (keyStore.containsAlias(alias)) {
            val entry = keyStore.getEntry(alias, null) as? KeyStore.SecretKeyEntry
            if (entry != null) {
                val key = entry.secretKey
                cachedSecurityLevel = inspectKeySecurityLevel(key)
                return key
            }
        }

        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            keyStoreType
        )

        // Attempt StrongBox if supported on Android 9+ (API 28+), fallback gracefully to TEE
        val key = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                try {
                    val strongBoxSpec = KeyGenParameterSpec.Builder(
                        alias,
                        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
                    )
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setKeySize(256)
                        .setIsStrongBoxBacked(true)
                        .build()

                    keyGenerator.init(strongBoxSpec)
                    keyGenerator.generateKey()
                } catch (e: Exception) {
                    // StrongBox unavailable on this device model; fallback to standard hardware TEE
                    generateStandardKey(keyGenerator, alias)
                }
            } else {
                generateStandardKey(keyGenerator, alias)
            }
        } catch (e: Exception) {
            generateStandardKey(keyGenerator, alias)
        }

        cachedSecurityLevel = inspectKeySecurityLevel(key)
        return key
    }

    private fun generateStandardKey(keyGenerator: KeyGenerator, alias: String): SecretKey {
        val spec = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()

        keyGenerator.init(spec)
        return keyGenerator.generateKey()
    }

    override fun getSecurityLevel(alias: String): KeystoreSecurityLevel {
        if (keyStore.containsAlias(alias)) {
            val entry = keyStore.getEntry(alias, null) as? KeyStore.SecretKeyEntry
            if (entry != null) {
                return inspectKeySecurityLevel(entry.secretKey)
            }
        }
        return cachedSecurityLevel
    }

    @Suppress("DEPRECATION")
    private fun inspectKeySecurityLevel(key: SecretKey): KeystoreSecurityLevel {
        return try {
            val factory = SecretKeyFactory.getInstance(key.algorithm, keyStoreType)
            val keyInfo = factory.getKeySpec(key, KeyInfo::class.java) as KeyInfo

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                when (keyInfo.securityLevel) {
                    KeyProperties.SECURITY_LEVEL_STRONGBOX -> KeystoreSecurityLevel.STRONGBOX
                    KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> KeystoreSecurityLevel.TRUSTED_ENVIRONMENT
                    KeyProperties.SECURITY_LEVEL_SOFTWARE -> KeystoreSecurityLevel.SOFTWARE
                    else -> {
                        if (keyInfo.isInsideSecureHardware) KeystoreSecurityLevel.TRUSTED_ENVIRONMENT
                        else KeystoreSecurityLevel.UNKNOWN_OR_UNVERIFIED
                    }
                }
            } else {
                if (keyInfo.isInsideSecureHardware) {
                    KeystoreSecurityLevel.TRUSTED_ENVIRONMENT
                } else {
                    KeystoreSecurityLevel.SOFTWARE
                }
            }
        } catch (e: Exception) {
            KeystoreSecurityLevel.UNKNOWN_OR_UNVERIFIED
        }
    }

    @Synchronized
    override fun deleteMasterKey(alias: String) {
        if (keyStore.containsAlias(alias)) {
            keyStore.deleteEntry(alias)
        }
    }
}
