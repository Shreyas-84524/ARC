package com.arc.arc.core.datastore

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

/**
 * Metadata for a user's secure vault configuration.
 */
data class VaultConfig(
    val pinLength: Int = 6,
    val saltHex: String? = null,
    val encryptedDek: String? = null,
    val isBiometricEnabled: Boolean = false,
    val biometricEncryptedDek: String? = null,
    val failedAttempts: Int = 0,
    val lockoutUntilEpochMs: Long = 0L,
    val formatVersion: Int = 1,
) {
    val isConfigured: Boolean
        get() = !saltHex.isNullOrBlank() && !encryptedDek.isNullOrBlank()

    fun isLockedOut(currentTimeMs: Long): Boolean =
        currentTimeMs < lockoutUntilEpochMs

    fun remainingLockoutSeconds(currentTimeMs: Long): Long =
        if (isLockedOut(currentTimeMs)) {
            ((lockoutUntilEpochMs - currentTimeMs) + 999L) / 1000L
        } else 0L
}

interface IVaultPreferencesDataStore {
    fun getVaultConfigFlow(ownerUid: String): Flow<VaultConfig>
    suspend fun getVaultConfig(ownerUid: String): VaultConfig
    suspend fun saveVaultConfig(
        ownerUid: String,
        pinLength: Int,
        saltHex: String,
        encryptedDek: String,
        formatVersion: Int = 1,
    )
    suspend fun setBiometricEnabled(ownerUid: String, enabled: Boolean, biometricEncryptedDek: String? = null)
    suspend fun recordFailedAttempt(ownerUid: String, currentTimeMs: Long): VaultConfig
    suspend fun resetFailedAttempts(ownerUid: String)
    suspend fun clearVaultConfig(ownerUid: String)
}

/**
 * DataStore persistence for Secret Vault configuration and rate-limiting metadata.
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. Plaintext PINs and unencrypted keys are NEVER stored here.
 * 2. Multi-user partitioning is enforced via [ownerUid] prefixed preference keys.
 * 3. Failed attempt counters and lockout timestamps persist across process restarts
 *    to prevent brute-force attacks via app kill-and-restart.
 */
class VaultPreferencesDataStore(
    private val dataStore: DataStore<Preferences>
) : IVaultPreferencesDataStore {

    private fun pinLengthKey(ownerUid: String) = intPreferencesKey("vault_pin_length_$ownerUid")
    private fun saltKey(ownerUid: String) = stringPreferencesKey("vault_salt_$ownerUid")
    private fun encryptedDekKey(ownerUid: String) = stringPreferencesKey("vault_encrypted_dek_$ownerUid")
    private fun biometricEnabledKey(ownerUid: String) = booleanPreferencesKey("vault_bio_enabled_$ownerUid")
    private fun biometricDekKey(ownerUid: String) = stringPreferencesKey("vault_bio_dek_$ownerUid")
    private fun failedAttemptsKey(ownerUid: String) = intPreferencesKey("vault_failed_attempts_$ownerUid")
    private fun lockoutUntilKey(ownerUid: String) = longPreferencesKey("vault_lockout_until_$ownerUid")
    private fun formatVersionKey(ownerUid: String) = intPreferencesKey("vault_format_version_$ownerUid")

    override fun getVaultConfigFlow(ownerUid: String): Flow<VaultConfig> = dataStore.data.map { prefs ->
        VaultConfig(
            pinLength = prefs[pinLengthKey(ownerUid)] ?: 6,
            saltHex = prefs[saltKey(ownerUid)],
            encryptedDek = prefs[encryptedDekKey(ownerUid)],
            isBiometricEnabled = prefs[biometricEnabledKey(ownerUid)] ?: false,
            biometricEncryptedDek = prefs[biometricDekKey(ownerUid)],
            failedAttempts = prefs[failedAttemptsKey(ownerUid)] ?: 0,
            lockoutUntilEpochMs = prefs[lockoutUntilKey(ownerUid)] ?: 0L,
            formatVersion = prefs[formatVersionKey(ownerUid)] ?: 1,
        )
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
        dataStore.edit { prefs ->
            prefs[pinLengthKey(ownerUid)] = pinLength
            prefs[saltKey(ownerUid)] = saltHex
            prefs[encryptedDekKey(ownerUid)] = encryptedDek
            prefs[failedAttemptsKey(ownerUid)] = 0
            prefs[lockoutUntilKey(ownerUid)] = 0L
            prefs[formatVersionKey(ownerUid)] = formatVersion
        }
    }


    override suspend fun setBiometricEnabled(
        ownerUid: String,
        enabled: Boolean,
        biometricEncryptedDek: String?,
    ) {
        dataStore.edit { prefs ->
            prefs[biometricEnabledKey(ownerUid)] = enabled
            if (biometricEncryptedDek != null) {
                prefs[biometricDekKey(ownerUid)] = biometricEncryptedDek
            } else if (!enabled) {
                prefs.remove(biometricDekKey(ownerUid))
            }
        }
    }

    /**
     * Records a failed PIN entry, calculates lockout backoff, and persists state.
     * Backoff schedule:
     * - Attempts 1-4: No lockout
     * - Attempt 5: 30 seconds
     * - Attempt 6: 60 seconds
     * - Attempt 7+: 120 seconds
     */
    override suspend fun recordFailedAttempt(ownerUid: String, currentTimeMs: Long): VaultConfig {
        var updatedConfig = VaultConfig()
        dataStore.edit { prefs ->
            val attemptsKey = failedAttemptsKey(ownerUid)
            val currentAttempts = (prefs[attemptsKey] ?: 0) + 1
            prefs[attemptsKey] = currentAttempts

            val lockoutSeconds = when {
                currentAttempts >= 7 -> 120L
                currentAttempts == 6 -> 60L
                currentAttempts == 5 -> 30L
                else -> 0L
            }

            val lockoutUntil = if (lockoutSeconds > 0) currentTimeMs + (lockoutSeconds * 1000L) else 0L
            prefs[lockoutUntilKey(ownerUid)] = lockoutUntil

            updatedConfig = VaultConfig(
                pinLength = prefs[pinLengthKey(ownerUid)] ?: 6,
                saltHex = prefs[saltKey(ownerUid)],
                encryptedDek = prefs[encryptedDekKey(ownerUid)],
                isBiometricEnabled = prefs[biometricEnabledKey(ownerUid)] ?: false,
                biometricEncryptedDek = prefs[biometricDekKey(ownerUid)],
                failedAttempts = currentAttempts,
                lockoutUntilEpochMs = lockoutUntil,
            )
        }
        return updatedConfig
    }

    /**
     * Resets failed attempt counter and clears active lockout.
     */
    override suspend fun resetFailedAttempts(ownerUid: String) {
        dataStore.edit { prefs ->
            prefs[failedAttemptsKey(ownerUid)] = 0
            prefs[lockoutUntilKey(ownerUid)] = 0L
        }
    }

    /**
     * Completely wipes vault credentials for [ownerUid] (used during irreversible PIN reset).
     */
    override suspend fun clearVaultConfig(ownerUid: String) {
        dataStore.edit { prefs ->
            prefs.remove(pinLengthKey(ownerUid))
            prefs.remove(saltKey(ownerUid))
            prefs.remove(encryptedDekKey(ownerUid))
            prefs.remove(biometricEnabledKey(ownerUid))
            prefs.remove(biometricDekKey(ownerUid))
            prefs.remove(failedAttemptsKey(ownerUid))
            prefs.remove(lockoutUntilKey(ownerUid))
        }
    }
}
