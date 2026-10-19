package com.arc.arc.features.vault.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.arc.arc.core.datastore.IVaultPreferencesDataStore
import com.arc.arc.core.model.SecretNoteModel
import com.arc.arc.core.security.IBiometricAuthManager
import com.arc.arc.core.security.VaultAuthCoordinator
import com.arc.arc.core.security.VaultAuthState
import com.arc.arc.features.vault.data.ISecretNoteRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class SecretNotesUiState(
    val authState: VaultAuthState = VaultAuthState.Locked,
    val notes: List<SecretNoteModel> = emptyList(),
    val selectedNote: SecretNoteModel? = null,
    val isEditorOpen: Boolean = false,
    val expectedPinLength: Int = 6,
    val isBiometricAvailable: Boolean = false,
    val errorMessage: String? = null,
    val isLoading: Boolean = false,
)

/**
 * ViewModel orchestrating Secret Vault authentication, decrypted note streams,
 * and zero-knowledge lifecycle management.
 */
class SecretNotesViewModel(
    private val repository: ISecretNoteRepository,
    private val authCoordinator: VaultAuthCoordinator,
    private val preferencesStore: IVaultPreferencesDataStore,
    private val biometricAuthManager: IBiometricAuthManager? = null,
) : ViewModel() {

    private val _uiState = MutableStateFlow(SecretNotesUiState())
    val uiState: StateFlow<SecretNotesUiState> = _uiState.asStateFlow()

    private var notesObservationJob: Job? = null
    private var currentOwnerUid: String = ""

    init {
        // Observe coordinator state changes
        viewModelScope.launch {
            authCoordinator.authState.collectLatest { state ->
                _uiState.update { it.copy(authState = state) }
                when (state) {
                    is VaultAuthState.Unlocked -> {
                        observeNotes(currentOwnerUid, state.activeDek)
                    }
                    is VaultAuthState.Locked,
                    is VaultAuthState.LockedOut,
                    is VaultAuthState.Unconfigured -> {
                        stopNotesObservation()
                    }
                    is VaultAuthState.Authenticating -> {}
                }
            }
        }
    }

    fun initialize(ownerUid: String) {
        currentOwnerUid = ownerUid
        viewModelScope.launch {
            val config = preferencesStore.getVaultConfig(ownerUid)
            _uiState.update {
                it.copy(
                    expectedPinLength = config.pinLength,
                    isBiometricAvailable = config.isBiometricEnabled
                )
            }
            authCoordinator.refreshState(ownerUid)
        }
    }

    fun unlockWithPin(ownerUid: String, pin: String) {
        currentOwnerUid = ownerUid
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            val result = authCoordinator.unlockWithPin(ownerUid, pin)
            _uiState.update {
                it.copy(
                    isLoading = false,
                    errorMessage = result.exceptionOrNull()?.message
                )
            }
        }
    }

    fun setupPin(ownerUid: String, pin: String, length: Int) {
        currentOwnerUid = ownerUid
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            val result = authCoordinator.setupPin(ownerUid, pin, length)
            _uiState.update {
                it.copy(
                    isLoading = false,
                    expectedPinLength = length,
                    errorMessage = result.exceptionOrNull()?.message
                )
            }
        }
    }

    fun unlockWithBiometricDek(dek: ByteArray) {
        authCoordinator.unlockWithBiometrics(dek)
    }

    fun lockVault() {
        authCoordinator.lock()
        stopNotesObservation()
        _uiState.update {
            it.copy(
                selectedNote = null,
                isEditorOpen = false,
                notes = emptyList() // Clear decrypted notes from UI state
            )
        }
    }

    fun openNoteEditor(note: SecretNoteModel?) {
        _uiState.update {
            it.copy(
                selectedNote = note,
                isEditorOpen = true
            )
        }
    }

    fun closeNoteEditor() {
        _uiState.update {
            it.copy(
                selectedNote = null,
                isEditorOpen = false
            )
        }
    }

    fun saveNote(note: SecretNoteModel) {
        val dek = authCoordinator.getActiveDek() ?: return
        viewModelScope.launch {
            val result = repository.saveNote(note, dek)
            if (result.isSuccess) {
                closeNoteEditor()
            } else {
                _uiState.update { it.copy(errorMessage = result.exceptionOrNull()?.message) }
            }
        }
    }

    fun deleteNote(id: String, ownerUid: String) {
        viewModelScope.launch {
            val result = repository.deleteNote(id, ownerUid)
            if (result.isSuccess) {
                closeNoteEditor()
            } else {
                _uiState.update { it.copy(errorMessage = result.exceptionOrNull()?.message) }
            }
        }
    }

    fun resetVault(ownerUid: String) {
        viewModelScope.launch {
            authCoordinator.lock()
            stopNotesObservation()
            preferencesStore.clearVaultConfig(ownerUid)
            repository.deleteAllForUser(ownerUid)
            authCoordinator.refreshState(ownerUid)
            _uiState.update {
                it.copy(
                    notes = emptyList(),
                    selectedNote = null,
                    isEditorOpen = false
                )
            }
        }
    }

    fun clearErrorMessage() {
        _uiState.update { it.copy(errorMessage = null) }
    }

    private fun observeNotes(ownerUid: String, dek: ByteArray) {
        notesObservationJob?.cancel()
        notesObservationJob = viewModelScope.launch {
            repository.getNotesFlow(ownerUid, dek).collectLatest { decryptedList ->
                _uiState.update { it.copy(notes = decryptedList) }
            }
        }
    }

    private fun stopNotesObservation() {
        notesObservationJob?.cancel()
        notesObservationJob = null
        _uiState.update { it.copy(notes = emptyList()) }
    }
}
