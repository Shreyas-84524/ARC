package com.arc.arc.core.security

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

enum class VaultAutoLockPolicy(val timeoutMs: Long) {
    IMMEDIATE(0L),
    THIRTY_SECONDS(30_000L),
    ONE_MINUTE(60_000L),
    FIVE_MINUTES(300_000L),
}

/**
 * Manages vault auto-lock triggers across Android app lifecycle events,
 * background timeouts, and user session changes.
 */
class VaultLifecycleManager(
    private val coordinator: VaultAuthCoordinator,
    var policy: VaultAutoLockPolicy = VaultAutoLockPolicy.IMMEDIATE,
) : DefaultLifecycleObserver {

    private var backgroundedEpochMs: Long = 0L

    override fun onStop(owner: LifecycleOwner) {
        onAppBackgrounded(System.currentTimeMillis())
    }

    override fun onStart(owner: LifecycleOwner) {
        onAppForegrounded(System.currentTimeMillis())
    }

    fun onAppBackgrounded(currentTimeMs: Long) {
        backgroundedEpochMs = currentTimeMs
        if (policy == VaultAutoLockPolicy.IMMEDIATE) {
            coordinator.lock()
        }
    }

    fun onAppForegrounded(currentTimeMs: Long) {
        if (coordinator.isUnlocked && policy != VaultAutoLockPolicy.IMMEDIATE && backgroundedEpochMs > 0L) {
            val elapsed = currentTimeMs - backgroundedEpochMs
            if (elapsed >= policy.timeoutMs) {
                coordinator.lock()
            }
        }
        backgroundedEpochMs = 0L
    }

    /**
     * Triggered immediately when the active user logs out or switches accounts.
     * Enforces strict multi-user privacy isolation.
     */
    fun onUserSessionTerminated() {
        coordinator.lock()
        backgroundedEpochMs = 0L
    }
}
