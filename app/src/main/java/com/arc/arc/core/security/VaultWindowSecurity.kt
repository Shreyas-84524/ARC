package com.arc.arc.core.security

import android.app.Activity
import android.os.Build
import android.os.PersistableBundle
import android.view.Window
import android.view.WindowManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalContext

object VaultWindowSecurity {

    /**
     * Toggles [WindowManager.LayoutParams.FLAG_SECURE] on [window] to protect against
     * screenshots, screen recording, and Recent Apps task switcher thumbnails.
     */
    fun setSecureScreenEnabled(window: Window?, enabled: Boolean) {
        if (window == null) return
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}

/**
 * Idiomatic Compose side-effect applying [FLAG_SECURE] to the hosting window while
 * a Vault composable is active in the composition, and restoring window flags upon exit.
 */
@Composable
fun SecureVaultEffect(enabled: Boolean = true) {
    val context = LocalContext.current
    DisposableEffect(enabled) {
        val activity = context as? Activity
        if (enabled && activity != null) {
            VaultWindowSecurity.setSecureScreenEnabled(activity.window, true)
        }
        onDispose {
            if (activity != null) {
                VaultWindowSecurity.setSecureScreenEnabled(activity.window, false)
            }
        }
    }
}
