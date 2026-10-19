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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

/**
 * Screen for setting up a new Vault PIN with variable length selection (3 to 6 digits).
 */
@Composable
fun VaultPinSetupScreen(
    onPinSetupCompleted: (pin: String, length: Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    var selectedLength by remember { mutableIntStateOf(6) }
    var step by remember { mutableIntStateOf(1) } // 1: Enter PIN, 2: Confirm PIN
    var firstPin by remember { mutableStateOf("") }
    var confirmPin by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isError by remember { mutableStateOf(false) }

    LaunchedEffect(errorMessage) {
        if (!errorMessage.isNullOrBlank()) {
            isError = true
            delay(600)
            isError = false
        }
    }

    fun handleDigit(digit: String) {
        errorMessage = null
        if (step == 1) {
            if (firstPin.length < selectedLength) {
                val updated = firstPin + digit
                firstPin = updated
                if (updated.length == selectedLength) {
                    step = 2
                }
            }
        } else {
            if (confirmPin.length < selectedLength) {
                val updated = confirmPin + digit
                confirmPin = updated
                if (updated.length == selectedLength) {
                    if (updated == firstPin) {
                        onPinSetupCompleted(firstPin, selectedLength)
                    } else {
                        errorMessage = "PINs did not match. Please try again."
                        step = 1
                        firstPin = ""
                        confirmPin = ""
                    }
                }
            }
        }
    }

    fun handleBackspace() {
        errorMessage = null
        if (step == 1) {
            if (firstPin.isNotEmpty()) {
                firstPin = firstPin.dropLast(1)
            }
        } else {
            if (confirmPin.isNotEmpty()) {
                confirmPin = confirmPin.dropLast(1)
            } else {
                step = 1
                confirmPin = ""
            }
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
                modifier = Modifier.padding(top = 16.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Shield,
                        contentDescription = "Setup Vault",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(32.dp)
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))

                Text(
                    text = if (step == 1) "Create Vault PIN" else "Confirm Vault PIN",
                    style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold),
                    color = MaterialTheme.colorScheme.onBackground
                )

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = if (step == 1) "Choose a PIN to encrypt your local notes" else "Re-enter your PIN to verify",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                // PIN Length selector (only in step 1)
                if (step == 1) {
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "PIN Length:",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        listOf(3, 4, 5, 6).forEach { len ->
                            FilterChip(
                                selected = selectedLength == len,
                                onClick = {
                                    selectedLength = len
                                    firstPin = ""
                                    confirmPin = ""
                                },
                                label = { Text("$len digits") },
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                                    selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
                                )
                            )
                        }
                    }
                }
            }

            // PIN Dots & Error message
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                val currentEntered = if (step == 1) firstPin.length else confirmPin.length
                VaultPinDots(
                    enteredLength = currentEntered,
                    totalLength = selectedLength,
                    isError = isError
                )

                AnimatedVisibility(
                    visible = !errorMessage.isNullOrBlank(),
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

            // Numeric Keypad
            VaultNumericKeypad(
                onDigitClick = { handleDigit(it) },
                onBackspaceClick = { handleBackspace() }
            )
        }
    }
}
