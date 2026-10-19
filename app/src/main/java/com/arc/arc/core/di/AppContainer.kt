package com.arc.arc.core.di

import android.content.Context
import com.arc.arc.BuildConfig
import com.arc.arc.core.auth.ArcFirebaseConfig
import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.auth.FirebaseAuthRepository
import com.arc.arc.core.auth.IAuthRepository
import com.arc.arc.core.database.ArcDatabase
import com.arc.arc.core.database.RoomHabitDataSource
import com.arc.arc.core.database.RoomSecretNoteDataSource
import com.arc.arc.core.database.RoomTaskDataSource
import com.arc.arc.core.database.RoomTransactionDataSource
import com.arc.arc.core.datastore.AppPreferencesDataStore
import com.arc.arc.core.datastore.IVaultPreferencesDataStore
import com.arc.arc.core.datastore.VaultPreferencesDataStore
import com.arc.arc.core.datastore.arcDataStore
import com.arc.arc.core.migration.HiveToRoomMigrator
import com.arc.arc.core.notifications.ArcNotificationManager
import com.arc.arc.core.notifications.IArcNotificationManager
import com.arc.arc.core.security.AndroidKeystoreMasterKeyProvider
import com.arc.arc.core.security.BiometricAuthManager
import com.arc.arc.core.security.IBiometricAuthManager
import com.arc.arc.core.security.IVaultMasterKeyProvider
import com.arc.arc.core.security.VaultAuthCoordinator
import com.arc.arc.core.security.VaultLifecycleManager
import com.arc.arc.core.security.VaultPinManager
import com.arc.arc.core.sync.FirestoreSyncManager
import com.arc.arc.core.sync.IFirestoreSyncManager
import com.arc.arc.features.habits.data.IHabitRepository
import com.arc.arc.features.habits.data.OfflineFirstHabitRepository
import com.arc.arc.features.money.data.ITransactionRepository
import com.arc.arc.features.money.data.OfflineFirstTransactionRepository
import com.arc.arc.features.search.GlobalSearchRepository
import com.arc.arc.features.search.IGlobalSearchRepository
import com.arc.arc.features.tasks.data.ITaskRepository
import com.arc.arc.features.tasks.data.OfflineFirstTaskRepository
import com.arc.arc.features.vault.data.ISecretNoteRepository
import com.arc.arc.features.vault.data.OfflineFirstSecretNoteRepository

/**
 * Dependency injection container for ARC.
 * Provides singleton data sources, database, repository, sync, and security instances.
 */
interface AppContainer {
    val database: ArcDatabase
    val taskDataSource: RoomTaskDataSource
    val taskRepository: ITaskRepository
    val habitDataSource: RoomHabitDataSource
    val habitRepository: IHabitRepository
    val transactionDataSource: RoomTransactionDataSource
    val transactionRepository: ITransactionRepository
    val preferencesDataStore: AppPreferencesDataStore
    val authRepository: IAuthRepository
    val secretNoteDataSource: RoomSecretNoteDataSource
    val secretNoteRepository: ISecretNoteRepository
    val vaultPreferencesDataStore: IVaultPreferencesDataStore
    val vaultMasterKeyProvider: IVaultMasterKeyProvider
    val vaultPinManager: VaultPinManager
    val vaultAuthCoordinator: VaultAuthCoordinator
    val biometricAuthManager: IBiometricAuthManager
    val vaultLifecycleManager: VaultLifecycleManager
    val globalSearchRepository: IGlobalSearchRepository
    val notificationManager: IArcNotificationManager
    val syncManager: IFirestoreSyncManager
    val dataMigrator: HiveToRoomMigrator
}

class DefaultAppContainer(
    private val context: Context,
    customAuthRepository: IAuthRepository? = null,
    customSyncManager: IFirestoreSyncManager? = null,
) : AppContainer {

    override val database: ArcDatabase by lazy {
        ArcDatabase.getInstance(context)
    }

    override val taskDataSource: RoomTaskDataSource by lazy {
        RoomTaskDataSource(database)
    }

    override val taskRepository: ITaskRepository by lazy {
        OfflineFirstTaskRepository(taskDataSource)
    }

    override val habitDataSource: RoomHabitDataSource by lazy {
        RoomHabitDataSource(database)
    }

    override val habitRepository: IHabitRepository by lazy {
        OfflineFirstHabitRepository(habitDataSource)
    }

    override val transactionDataSource: RoomTransactionDataSource by lazy {
        RoomTransactionDataSource(database)
    }

    override val transactionRepository: ITransactionRepository by lazy {
        OfflineFirstTransactionRepository(transactionDataSource)
    }

    override val preferencesDataStore: AppPreferencesDataStore by lazy {
        AppPreferencesDataStore(context.arcDataStore)
    }

    override val authRepository: IAuthRepository by lazy {
        customAuthRepository ?: if (!BuildConfig.DEBUG) {
            // Production release builds: NEVER instantiate fake auth
            ArcFirebaseConfig.initialize(context)
            FirebaseAuthRepository(context)
        } else {
            // Debug builds: if Firebase is initialized, provide real FirebaseAuthRepository;
            // otherwise fallback to isolated DevFakeAuthRepository for local testing.
            val firebaseReady = ArcFirebaseConfig.initialize(context)
            if (firebaseReady) {
                FirebaseAuthRepository(context)
            } else {
                DevFakeAuthRepository()
            }
        }
    }

    override val secretNoteDataSource: RoomSecretNoteDataSource by lazy {
        RoomSecretNoteDataSource(database)
    }

    override val secretNoteRepository: ISecretNoteRepository by lazy {
        OfflineFirstSecretNoteRepository(secretNoteDataSource)
    }

    override val vaultPreferencesDataStore: IVaultPreferencesDataStore by lazy {
        VaultPreferencesDataStore(context.arcDataStore)
    }

    override val vaultMasterKeyProvider: IVaultMasterKeyProvider by lazy {
        AndroidKeystoreMasterKeyProvider()
    }

    override val vaultPinManager: VaultPinManager by lazy {
        VaultPinManager(vaultPreferencesDataStore, vaultMasterKeyProvider)
    }

    override val vaultAuthCoordinator: VaultAuthCoordinator by lazy {
        VaultAuthCoordinator(vaultPinManager, vaultPreferencesDataStore)
    }

    override val biometricAuthManager: IBiometricAuthManager by lazy {
        BiometricAuthManager()
    }

    override val vaultLifecycleManager: VaultLifecycleManager by lazy {
        VaultLifecycleManager(vaultAuthCoordinator)
    }

    override val globalSearchRepository: IGlobalSearchRepository by lazy {
        GlobalSearchRepository(taskRepository, habitRepository, transactionRepository)
    }

    override val notificationManager: IArcNotificationManager by lazy {
        ArcNotificationManager(context)
    }

    override val syncManager: IFirestoreSyncManager by lazy {
        customSyncManager ?: FirestoreSyncManager(database)
    }

    override val dataMigrator: HiveToRoomMigrator by lazy {
        HiveToRoomMigrator(database)
    }
}
