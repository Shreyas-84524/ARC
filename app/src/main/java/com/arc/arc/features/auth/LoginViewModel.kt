package com.arc.arc.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.auth.IAuthRepository
import com.arc.arc.core.auth.UserSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class LoginUiState(
    val emailOrUsername: String = "",
    val password: String = "",
    val displayName: String = "",
    val isRegistrationMode: Boolean = false,
    val isResetPasswordMode: Boolean = false,
    val isResetEmailSent: Boolean = false,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val infoMessage: String? = null,
    val isSuccess: Boolean = false,
    val isDevMode: Boolean = false,
    val presetUsers: List<UserSession> = emptyList(),
)

class LoginViewModel(
    private val authRepository: IAuthRepository
) : ViewModel() {

    private val isDevRepo = authRepository is DevFakeAuthRepository

    private val _uiState = MutableStateFlow(
        LoginUiState(
            isDevMode = isDevRepo,
            presetUsers = if (isDevRepo) DevFakeAuthRepository.PRESET_DEV_USERS else emptyList(),
        )
    )
    val uiState: StateFlow<LoginUiState> = _uiState.asStateFlow()

    fun onEmailOrUsernameChanged(value: String) {
        _uiState.update { it.copy(emailOrUsername = value, errorMessage = null, infoMessage = null) }
    }

    fun onPasswordChanged(value: String) {
        _uiState.update { it.copy(password = value, errorMessage = null, infoMessage = null) }
    }

    fun onDisplayNameChanged(value: String) {
        _uiState.update { it.copy(displayName = value, errorMessage = null, infoMessage = null) }
    }

    fun toggleRegistrationMode() {
        _uiState.update {
            it.copy(
                isRegistrationMode = !it.isRegistrationMode,
                isResetPasswordMode = false,
                errorMessage = null,
                infoMessage = null
            )
        }
    }

    fun toggleResetPasswordMode() {
        _uiState.update {
            it.copy(
                isResetPasswordMode = !it.isResetPasswordMode,
                errorMessage = null,
                infoMessage = null,
                isResetEmailSent = false
            )
        }
    }

    fun submit() {
        val state = _uiState.value
        if (state.isResetPasswordMode) {
            sendPasswordReset()
        } else if (state.isRegistrationMode) {
            signUp()
        } else {
            signIn()
        }
    }

    fun signIn() {
        val currentState = _uiState.value
        if (currentState.emailOrUsername.isBlank()) {
            _uiState.update { it.copy(errorMessage = "Please enter an email or username") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null, infoMessage = null) }
            val result = authRepository.signInWithEmailAndPassword(
                currentState.emailOrUsername,
                currentState.password,
            )
            result.fold(
                onSuccess = {
                    _uiState.update { it.copy(isLoading = false, isSuccess = true) }
                },
                onFailure = { error ->
                    _uiState.update { it.copy(isLoading = false, errorMessage = error.message ?: "Authentication failed") }
                }
            )
        }
    }

    fun signUp() {
        val currentState = _uiState.value
        if (currentState.emailOrUsername.isBlank()) {
            _uiState.update { it.copy(errorMessage = "Please enter an email address") }
            return
        }
        if (currentState.password.length < 6) {
            _uiState.update { it.copy(errorMessage = "Password must be at least 6 characters") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null, infoMessage = null) }
            val result = authRepository.signUpWithEmailAndPassword(
                email = currentState.emailOrUsername,
                password = currentState.password,
                displayName = currentState.displayName,
            )
            result.fold(
                onSuccess = {
                    _uiState.update { it.copy(isLoading = false, isSuccess = true) }
                },
                onFailure = { error ->
                    _uiState.update { it.copy(isLoading = false, errorMessage = error.message ?: "Registration failed") }
                }
            )
        }
    }

    fun sendPasswordReset() {
        val email = _uiState.value.emailOrUsername.trim()
        if (email.isBlank() || !email.contains("@")) {
            _uiState.update { it.copy(errorMessage = "Please enter a valid email for password reset") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null, infoMessage = null) }
            val result = authRepository.sendPasswordResetEmail(email)
            result.fold(
                onSuccess = {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            isResetEmailSent = true,
                            infoMessage = "Password reset instructions sent to $email."
                        )
                    }
                },
                onFailure = { error ->
                    _uiState.update { it.copy(isLoading = false, errorMessage = error.message ?: "Failed to send reset email") }
                }
            )
        }
    }

    fun signInWithGoogle() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null, infoMessage = null) }
            val result = authRepository.signInWithGoogle()
            result.fold(
                onSuccess = {
                    _uiState.update { it.copy(isLoading = false, isSuccess = true) }
                },
                onFailure = { error ->
                    if (error is androidx.credentials.exceptions.GetCredentialCancellationException) {
                        _uiState.update { it.copy(isLoading = false) }
                    } else {
                        _uiState.update { it.copy(isLoading = false, errorMessage = error.message ?: "Google Sign-In failed") }
                    }
                }
            )
        }
    }

    fun signInAsPreset(user: UserSession) {
        if (!isDevRepo) return
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null, infoMessage = null) }
            val result = authRepository.signInWithEmailAndPassword(user.username, "dev_password")
            result.fold(
                onSuccess = {
                    _uiState.update { it.copy(isLoading = false, isSuccess = true) }
                },
                onFailure = { error ->
                    _uiState.update { it.copy(isLoading = false, errorMessage = error.message ?: "Preset login failed") }
                }
            )
        }
    }

    companion object {
        fun factory(authRepository: IAuthRepository): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return LoginViewModel(authRepository) as T
            }
        }
    }
}
