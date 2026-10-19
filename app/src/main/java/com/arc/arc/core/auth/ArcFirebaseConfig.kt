package com.arc.arc.core.auth

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions

/**
 * Verified production Firebase configuration for ARC.
 * Matches project: arc-productivity-shreyas (com.arc.arc).
 *
 * Provides safe programmatic initialization ensuring the native Kotlin application
 * maintains seamless continuity with the original Flutter application.
 */
object ArcFirebaseConfig {
    const val PROJECT_ID = "arc-productivity-shreyas"
    const val APPLICATION_ID = "1:729643761637:android:39bc738c98a05bd4dc790c"
    const val API_KEY = "AIzaSyCTp6kyYEFN_yBX-cnRAR45E66dGk4UHVo"
    const val STORAGE_BUCKET = "arc-productivity-shreyas.firebasestorage.app"
    const val GCM_SENDER_ID = "729643761637"
    const val WEB_CLIENT_ID = "729643761637-6l1cekc186jos6m6bdss0l0a6lhp9bfr.apps.googleusercontent.com"

    @Volatile
    private var isInitialized = false

    /**
     * Initializes Firebase safely. Returns true if Firebase is available and active.
     */
    fun initialize(context: Context): Boolean {
        if (isInitialized) return true

        return synchronized(this) {
            try {
                if (FirebaseApp.getApps(context).isNotEmpty()) {
                    isInitialized = true
                    return@synchronized true
                }

                val options = FirebaseOptions.Builder()
                    .setProjectId(PROJECT_ID)
                    .setApplicationId(APPLICATION_ID)
                    .setApiKey(API_KEY)
                    .setStorageBucket(STORAGE_BUCKET)
                    .setGcmSenderId(GCM_SENDER_ID)
                    .build()

                FirebaseApp.initializeApp(context, options)
                isInitialized = true
                true
            } catch (e: Exception) {
                isInitialized = false
                false
            }
        }
    }

    fun isConfigured(context: Context): Boolean {
        return try {
            FirebaseApp.getApps(context).isNotEmpty() || isInitialized
        } catch (_: Exception) {
            false
        }
    }
}
