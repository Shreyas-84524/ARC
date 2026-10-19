package com.arc.arc

import android.app.Application
import com.arc.arc.core.auth.ArcFirebaseConfig
import com.arc.arc.core.di.AppContainer
import com.arc.arc.core.di.DefaultAppContainer
import com.arc.arc.core.sync.ArcSyncWorker

/**
 * Base Application class for ARC.
 * Holds the root dependency container and initializes core background infrastructure.
 */
class ArcApplication : Application() {

    lateinit var container: AppContainer

    override fun onCreate() {
        super.onCreate()
        // Initialize Firebase safely
        ArcFirebaseConfig.initialize(this)
        container = DefaultAppContainer(this)
        // Schedule deferred, battery-friendly periodic background Firestore sync
        try {
            ArcSyncWorker.schedulePeriodicSync(this)
        } catch (_: Exception) {
            // Non-fatal if WorkManager cannot initialize in restricted test harness
        }
    }
}
