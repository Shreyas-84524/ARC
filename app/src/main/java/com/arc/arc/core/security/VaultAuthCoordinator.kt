package com.arc.arc.core.security

import com.arc.arc.core.datastore.IVaultPreferencesDataStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Arrays

sealed interface VaultAuthState {
    object Unconfigured : VaultAuthState
    object Locked : VaultAuthState
    data class Authenticating(val inProgress: Boolean = true) : VaultAuthState
    data class Unlocked(val activeDek: ByteArray, val unlockedAtEpochMs: Long) : VaultAuthState {
        override fun toString(): String = "Unlocked(activeDek=[REDACTED], unlockedAtEpochMs=$unlockedAtEpochMs)"
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (other !is Unlocked) return false
            return unlockedAtEpochMs == other.unlockedAtEpochMs && activeDek.contentEquals(other.activeDek)
        }
        override fun hashCode(): Int = 31 * activeDek.contentHashCode() + unlockedAtEpochMs.hashCode()
    }
    data class LockedOut(val remainingSeconds: Long, val lockedUntilEpochMs: Long) : VaultAuthState
}

/**
 * Central state machine and session coordinator for ARC Vault authentication.
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. Vault session is LOCKED by default.
 * 2. Unlocking requires successful cryptographic authentication (PIN or Biometric).
 * 3. Calling [lock] securely zeroes out the in-memory DEK byte array.
 * 4. Switching users or signing out triggers an immediate [lock].
 */
class VaultAuthCoordinator(
    private val pinManager: VaultPinManager,
    private val preferencesDataStore: IVaultPreferencesDataStore,
) {
    private val _authState = MutableStateFlow<VaultAuthState>(VaultAuthState.Locked)
    val authState: StateFlow<VaultAuthState> = _authState.asStateFlow()

    val isUnlocked: Boolean
        get() = _authState.value is VaultAuthState.Unlocked

    fun getActiveDek(): ByteArray? =
        (_authState.value as? VaultAuthState.Unlocked)?.activeDek

    /**
     * Initializes or refreshes vault auth state for [ownerUid].
     */
    suspend fun refreshState(ownerUid: String, currentTimeMs: Long = System.currentTimeMillis()) {
        val config = preferencesDataStore.getVaultConfig(ownerUid)
        when {
            !config.isConfigured -> {
                _authState.value = VaultAuthState.Unconfigured
            }
            config.isLockedOut(currentTimeMs) -> {
                _authState.value = VaultAuthState.LockedOut(
                    remainingSeconds = config.remainingLockoutSeconds(currentTimeMs),
                    lockedUntilEpochMs = config.lockoutUntilEpochMs
                )
            }
            _authState.value !is VaultAuthState.Unlocked -> {
                _authState.value = VaultAuthState.Locked
            }
        }
    }

    /**
     * Configures the initial PIN and unlocks the vault session with the generated DEK.
     */
    suspend fun setupPin(ownerUid: String, pin: String, pinLength: Int = pin.length): Result<ByteArray> {
        val result = pinManager.setupPin(ownerUid, pin, pinLength)
        if (result.isSuccess) {
            val dek = result.getOrThrow()
            _authState.value = VaultAuthState.Unlocked(
                activeDek = dek,
                unlockedAtEpochMs = System.currentTimeMillis()
            )
        }
        return result
    }

    /**
     * Authenticates with user-entered PIN, transitions state to [VaultAuthState.Unlocked] on success,
     * or [VaultAuthState.LockedOut] if lockout threshold is reached.
     */
    suspend fun unlockWithPin(
        ownerUid: String,
        pin: String,
        currentTimeMs: Long = System.currentTimeMillis()
    ): Result<ByteArray> {
        _authState.value = VaultAuthState.Authenticating()
        val result = pinManager.verifyPin(ownerUid, pin, currentTimeMs)
        if (result.isSuccess) {
            val dek = result.getOrThrow()
            _authState.value = VaultAuthState.Unlocked(
                activeDek = dek,
                unlockedAtEpochMs = currentTimeMs
            )
        } else {
            val config = preferencesDataStore.getVaultConfig(ownerUid)
            if (config.isLockedOut(currentTimeMs)) {
                _authState.value = VaultAuthState.LockedOut(
                    remainingSeconds = config.remainingLockoutSeconds(currentTimeMs),
                    lockedUntilEpochMs = config.lockoutUntilEpochMs
                )
            } else {
                _authState.value = VaultAuthState.Locked
            }
        }
        return result
    }

    /**
     * Unlocks the vault using a biometric-decrypted DEK.
     */
    fun unlockWithBiometrics(dek: ByteArray, currentTimeMs: Long = System.currentTimeMillis()): Result<ByteArray> {
        return if (dek.size == 32) {
            _authState.value = VaultAuthState.Unlocked(
                activeDek = dek,
                unlockedAtEpochMs = currentTimeMs
            )
            Result.success(dek)
        } else {
            Result.failure(IllegalArgumentException("Invalid DEK length for biometric unlock"))
        }
    }

    /**
     * Securely locks the vault session. Zeroes out all active DEK bytes in memory.
     */
    fun lock() {
        val current = _authState.value
        if (current is VaultAuthState.Unlocked) {
            Arrays.fill(current.activeDek, 0.toByte())
        }
        _authState.value = VaultAuthState.Locked
    }
}
