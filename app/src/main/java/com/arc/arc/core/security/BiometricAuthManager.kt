package com.arc.arc.core.security

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import java.util.concurrent.atomic.AtomicBoolean

enum class BiometricStatus {
    READY,
    NONE_ENROLLED,
    NO_HARDWARE,
    UNAVAILABLE
}

interface IBiometricAuthManager {
    fun canAuthenticate(context: Context): BiometricStatus
    fun canPrompt(): Boolean
    fun onPromptDismissed()
    fun authenticate(
        activity: FragmentActivity,
        title: String = "Unlock Secret Vault",
        subtitle: String = "Confirm biometric credentials to access encrypted notes",
        negativeButtonText: String = "Use PIN",
        onSuccess: (BiometricPrompt.AuthenticationResult) -> Unit,
        onError: (Int, CharSequence) -> Unit,
    )
}

/**
 * Biometric authentication manager with an atomic single-prompt lock guard.
 *
 * CRITICAL DEFENSE-IN-DEPTH:
 * Directly solves Flutter Legacy Issue 1 ("Biometric Authentication Prompting Twice on Vault Entry").
 * Concurrent route guards, recompositions, or multiple lifecycle events are prevented
 * from spawning duplicate biometric dialogs by the atomic [isPromptInFlight] CAS guard.
 */
class BiometricAuthManager : IBiometricAuthManager {

    private val isPromptInFlight = AtomicBoolean(false)

    override fun canAuthenticate(context: Context): BiometricStatus {
        val biometricManager = BiometricManager.from(context)
        return when (biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS -> BiometricStatus.READY
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> BiometricStatus.NONE_ENROLLED
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> BiometricStatus.NO_HARDWARE
            else -> BiometricStatus.UNAVAILABLE
        }
    }

    override fun canPrompt(): Boolean {
        return isPromptInFlight.compareAndSet(false, true)
    }

    override fun onPromptDismissed() {
        isPromptInFlight.set(false)
    }

    override fun authenticate(
        activity: FragmentActivity,
        title: String,
        subtitle: String,
        negativeButtonText: String,
        onSuccess: (BiometricPrompt.AuthenticationResult) -> Unit,
        onError: (Int, CharSequence) -> Unit,
    ) {
        if (!canPrompt()) {
            // A prompt is already actively in-flight; silently reject duplicate launch
            return
        }

        val executor = ContextCompat.getMainExecutor(activity)
        val prompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    onPromptDismissed()
                    onSuccess(result)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    onPromptDismissed()
                    onError(errorCode, errString)
                }

                override fun onAuthenticationFailed() {
                    // Biometric failed single attempt, dialog remains open for retry
                }
            }
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setNegativeButtonText(negativeButtonText)
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build()

        try {
            prompt.authenticate(promptInfo)
        } catch (e: Exception) {
            onPromptDismissed()
            onError(BiometricPrompt.ERROR_UNABLE_TO_PROCESS, e.message ?: "Authentication error")
        }
    }
}
