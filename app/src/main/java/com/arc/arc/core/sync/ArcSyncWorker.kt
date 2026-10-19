package com.arc.arc.core.sync

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.arc.arc.ArcApplication
import java.util.concurrent.TimeUnit

/**
 * Background WorkManager worker for periodic and deferred Cloud Firestore synchronization.
 */
class ArcSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        val app = applicationContext as? ArcApplication ?: return Result.failure()
        val container = app.container
        val uid = container.authRepository.currentUserId

        if (uid.isNullOrBlank()) {
            return Result.success() // No authenticated session to sync
        }

        return try {
            val syncManager = (container as? com.arc.arc.core.di.DefaultAppContainer)?.syncManager
                ?: return Result.success()

            // 1. Flush local pending mutations to cloud
            val pushResult = syncManager.pushPendingMutations(uid)
            if (pushResult.isFailure) {
                return Result.retry()
            }

            // 2. Pull remote updates to local Room
            val pullResult = syncManager.pullInitialData(uid)
            if (pullResult.isFailure) {
                return Result.retry()
            }

            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    companion object {
        private const val PERIODIC_SYNC_WORK_NAME = "arc_periodic_firestore_sync"
        private const val IMMEDIATE_SYNC_WORK_NAME = "arc_immediate_firestore_sync"

        fun schedulePeriodicSync(context: Context, repeatIntervalHours: Long = 1) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = PeriodicWorkRequestBuilder<ArcSyncWorker>(repeatIntervalHours, TimeUnit.HOURS)
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                PERIODIC_SYNC_WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
        }

        fun triggerImmediateSync(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<ArcSyncWorker>()
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                IMMEDIATE_SYNC_WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                request
            )
        }
    }
}
