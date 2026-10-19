package com.arc.arc.vault

import com.arc.arc.core.model.SecretChecklistItemModel
import com.arc.arc.core.model.SecretNoteModel
import com.arc.arc.core.security.VaultAuthCoordinator
import com.arc.arc.core.security.VaultAuthState
import com.arc.arc.core.security.VaultPinManager
import com.arc.arc.features.vault.ui.SecretNotesViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Date

@OptIn(ExperimentalCoroutinesApi::class)
class SecretNotesModuleTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var repository: InMemorySecretNoteRepository
    private lateinit var preferencesStore: InMemoryVaultPreferencesDataStore
    private lateinit var pinManager: VaultPinManager
    private lateinit var coordinator: VaultAuthCoordinator
    private lateinit var viewModel: SecretNotesViewModel

    private val ownerUid = "user-alice-789"

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        repository = InMemorySecretNoteRepository()
        preferencesStore = InMemoryVaultPreferencesDataStore()
        pinManager = VaultPinManager(preferencesStore)
        coordinator = VaultAuthCoordinator(pinManager, preferencesStore)
        viewModel = SecretNotesViewModel(repository, coordinator, preferencesStore)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testUnconfiguredInitialState() = runTest {
        viewModel.initialize(ownerUid)
        advanceUntilIdle()

        assertEquals(VaultAuthState.Unconfigured, viewModel.uiState.value.authState)
        assertTrue(viewModel.uiState.value.notes.isEmpty())
        assertFalse(viewModel.uiState.value.isEditorOpen)
    }

    @Test
    fun testSetupPinAndCreateNoteLifecycle() = runTest {
        viewModel.initialize(ownerUid)
        advanceUntilIdle()

        // Setup 6-digit PIN
        viewModel.setupPin(ownerUid, "654321", 6)
        advanceUntilIdle()

        assertTrue(viewModel.uiState.value.authState is VaultAuthState.Unlocked)

        // Create a new secret note
        val note = SecretNoteModel(
            id = "note-secret-1",
            ownerUid = ownerUid,
            title = "Hardware Wallet Seed",
            description = "24-word recovery mnemonic",
            color = "emerald",
            checklist = listOf(
                SecretChecklistItemModel(id = "c1", text = "Backup to titanium plate", isCompleted = true)
            )
        )

        viewModel.saveNote(note)
        advanceUntilIdle()

        // Verify note is in decrypted UI state
        assertEquals(1, viewModel.uiState.value.notes.size)
        val decrypted = viewModel.uiState.value.notes.first()
        assertEquals("Hardware Wallet Seed", decrypted.title)
        assertEquals("24-word recovery mnemonic", decrypted.description)
        assertEquals("emerald", decrypted.color)
        assertTrue(decrypted.checklist.first().isCompleted)
    }

    @Test
    fun testLockingVaultWipesDecryptedNotesFromState() = runTest {
        viewModel.initialize(ownerUid)
        advanceUntilIdle()
        viewModel.setupPin(ownerUid, "123456", 6)
        advanceUntilIdle()

        viewModel.saveNote(SecretNoteModel(id = "n1", ownerUid = ownerUid, title = "Classified"))
        advanceUntilIdle()
        assertEquals(1, viewModel.uiState.value.notes.size)

        // Lock vault
        viewModel.lockVault()
        advanceUntilIdle()

        assertEquals(VaultAuthState.Locked, viewModel.uiState.value.authState)
        // Decrypted notes list MUST be cleared from state on lock
        assertTrue("UI state must purge decrypted notes on lock", viewModel.uiState.value.notes.isEmpty())
        assertNull(coordinator.getActiveDek())

        // Unlock with wrong PIN -> fails
        viewModel.unlockWithPin(ownerUid, "000000")
        advanceUntilIdle()
        assertEquals(VaultAuthState.Locked, viewModel.uiState.value.authState)
        assertTrue(viewModel.uiState.value.notes.isEmpty())
        assertNotNull(viewModel.uiState.value.errorMessage)

        // Unlock with correct PIN -> restores decrypted notes
        viewModel.unlockWithPin(ownerUid, "123456")
        advanceUntilIdle()
        assertTrue(viewModel.uiState.value.authState is VaultAuthState.Unlocked)
        assertEquals(1, viewModel.uiState.value.notes.size)
        assertEquals("Classified", viewModel.uiState.value.notes.first().title)
    }

    @Test
    fun testDeleteNote() = runTest {
        viewModel.initialize(ownerUid)
        advanceUntilIdle()
        viewModel.setupPin(ownerUid, "987654", 6)
        advanceUntilIdle()

        viewModel.saveNote(SecretNoteModel(id = "note-del", ownerUid = ownerUid, title = "To Delete"))
        advanceUntilIdle()
        assertEquals(1, viewModel.uiState.value.notes.size)

        viewModel.deleteNote("note-del", ownerUid)
        advanceUntilIdle()
        assertEquals(0, viewModel.uiState.value.notes.size)
    }

    @Test
    fun testResetVaultWipesEverything() = runTest {
        viewModel.initialize(ownerUid)
        advanceUntilIdle()
        viewModel.setupPin(ownerUid, "112233", 6)
        advanceUntilIdle()

        viewModel.saveNote(SecretNoteModel(id = "n1", ownerUid = ownerUid, title = "Top Secret"))
        advanceUntilIdle()

        viewModel.resetVault(ownerUid)
        advanceUntilIdle()

        assertEquals(VaultAuthState.Unconfigured, viewModel.uiState.value.authState)
        assertTrue(viewModel.uiState.value.notes.isEmpty())
        assertNull(coordinator.getActiveDek())
        assertEquals(0, repository.getNoteCount(ownerUid))
    }
}
