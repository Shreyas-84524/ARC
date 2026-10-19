package com.arc.arc.core.security

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle

object VaultClipboardHelper {

    /**
     * Safely copies sensitive content to clipboard.
     * On Android 13+ (API 33+), sets [ClipDescription.EXTRA_IS_SENSITIVE] to true
     * to prevent clipboard visual preview popups from leaking decrypted secrets.
     */
    fun copySensitiveText(
        context: Context,
        label: String,
        content: String
    ): Boolean {
        return try {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                ?: return false

            val clipData = ClipData.newPlainText(label, content)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                clipData.description.extras = PersistableBundle().apply {
                    putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                }
            }
            clipboard.setPrimaryClip(clipData)
            true
        } catch (_: Exception) {
            false
        }
    }
}
