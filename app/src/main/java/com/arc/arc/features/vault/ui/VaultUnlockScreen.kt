package com.arc.arc.features.vault.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.security.VaultAuthState
import kotlinx.coroutines.delay

/**
 * Screen for unlocking the encrypted secret vault via PIN or Biometrics.
 */
@Composable
fun VaultUnlockScreen(
    authState: VaultAuthState,
    expectedPinLength: Int,
    isBiometricAvailable: Boolean,
    onPinEntered: (String) -> Unit,
    onBiometricClick: () -> Unit,
    onResetVault: () -> Unit,
    errorMessage: String? = null,
    modifier: Modifier = Modifier,
) {
    var enteredPin by remember { mutableStateOf("") }
    var isError by remember { mutableStateOf(false) }
    var showResetDialog by remember { mutableStateOf(false) }

    val isLockedOut = authState is VaultAuthState.LockedOut
    val lockoutRemaining = (authState as? VaultAuthState.LockedOut)?.remainingSeconds ?: 0L

    // React to errorMessage
    LaunchedEffect(errorMessage) {
        if (!errorMessage.isNullOrBlank()) {
            isError = true
            delay(500)
            enteredPin = ""
            isError = false
        }
    }

    // Auto-submit when PIN length is reached
    fun handleDigit(digit: String) {
        if (isLockedOut) return
        if (enteredPin.length < expectedPinLength) {
            val updated = enteredPin + digit
            enteredPin = updated
            if (updated.length == expectedPinLength) {
                onPinEntered(updated)
            }
        }
    }

    fun handleBackspace() {
        if (isLockedOut) return
        if (enteredPin.isNotEmpty()) {
            enteredPin = enteredPin.dropLast(1)
        }
    }

    Surface(
        modifier = modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier
                .fillMaxSize()
                .padding(vertical = 32.dp, horizontal = 24.dp)
        ) {
            // Header
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(top = 24.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Lock,
                        contentDescription = "Vault Locked",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(36.dp)
                    )
                }

                Spacer(modifier = Modifier.height(20.dp))

                Text(
                    text = "Secret Vault",
                    style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold),
                    color = MaterialTheme.colorScheme.onBackground
                )

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = if (isLockedOut) "Vault temporarily locked" else "Enter your PIN to decrypt notes",
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (isLockedOut) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // PIN Dots / Lockout message
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                if (isLockedOut) {
                    Surface(
                        color = MaterialTheme.colorScheme.errorContainer,
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Warning,
                                contentDescription = "Locked out",
                                tint = MaterialTheme.colorScheme.error
                            )
                            Spacer(modifier = Modifier.size(12.dp))
                            Text(
                                text = "Too many failed attempts. Try again in ${lockoutRemaining}s.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onErrorContainer,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                } else {
                    VaultPinDots(
                        enteredLength = enteredPin.length,
                        totalLength = expectedPinLength,
                        isError = isError
                    )
                }

                AnimatedVisibility(
                    visible = !errorMessage.isNullOrBlank() && !isLockedOut,
                    enter = fadeIn(),
                    exit = fadeOut()
                ) {
                    Text(
                        text = errorMessage ?: "",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.padding(top = 12.dp),
                        textAlign = TextAlign.Center
                    )
                }
            }

            // Numeric Keypad & Reset option
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                VaultNumericKeypad(
                    onDigitClick = { handleDigit(it) },
                    onBackspaceClick = { handleBackspace() },
                    onBiometricClick = if (isBiometricAvailable) onBiometricClick else null
                )

                Spacer(modifier = Modifier.height(16.dp))

                TextButton(onClick = { showResetDialog = true }) {
                    Text(
                        text = "Forgot PIN?",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }

    // Reset Vault confirmation dialog
    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            icon = {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.error
                )
            },
            title = {
                Text(text = "Reset Vault PIN?")
            },
            text = {
                Text(
                    text = "Zero-Knowledge Warning: Because notes are strongly encrypted with your PIN, resetting your PIN will permanently wipe all existing secret notes. They cannot be recovered without the original PIN.",
                    style = MaterialTheme.typography.bodyMedium
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showResetDialog = false
                        onResetVault()
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("Wipe and Reset", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}
