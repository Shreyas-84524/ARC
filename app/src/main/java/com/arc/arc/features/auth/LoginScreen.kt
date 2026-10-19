package com.arc.arc.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.components.ArcCard
import com.arc.arc.core.designsystem.components.ArcErrorState
import com.arc.arc.core.designsystem.components.ArcFilterChip
import com.arc.arc.core.designsystem.components.ArcPrimaryButton
import com.arc.arc.core.designsystem.components.ArcTextField
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme

@Composable
fun LoginScreen(
    viewModel: LoginViewModel,
    onLoginSuccess: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(uiState.isSuccess) {
        if (uiState.isSuccess) {
            onLoginSuccess()
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = ArcTheme.colors.background,
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = ArcDimens.ScreenHorizontalPadding)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Spacer(modifier = Modifier.height(24.dp))

            // Brand Header
            Text(
                text = "ARC",
                fontSize = 42.sp,
                fontWeight = FontWeight.Bold,
                color = ArcTheme.colors.accent,
                letterSpacing = (-1.0).sp,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Productivity System",
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = ArcTheme.colors.textSecondary,
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Development Mode Warning Banner (Shown ONLY in Dev Fake mode)
            if (uiState.isDevMode && uiState.presetUsers.isNotEmpty()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            color = ArcTheme.colors.accent.copy(alpha = 0.12f),
                            shape = RoundedCornerShape(ArcDimens.RadiusCard),
                        )
                        .border(
                            width = 1.dp,
                            color = ArcTheme.colors.accent.copy(alpha = 0.35f),
                            shape = RoundedCornerShape(ArcDimens.RadiusCard),
                        )
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = Icons.Default.Info,
                        contentDescription = "Development Notice",
                        tint = ArcTheme.colors.accent,
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "Development Authentication Mode",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            color = ArcTheme.colors.textPrimary,
                        )
                        Text(
                            text = "Isolated local session with preset accounts. Real Firebase active in production.",
                            fontSize = 12.sp,
                            color = ArcTheme.colors.textMuted,
                            lineHeight = 16.sp,
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Quick select preset accounts
                ArcCard(
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Quick Sign-In (Select Dev Profile)",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            color = ArcTheme.colors.textPrimary,
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            uiState.presetUsers.forEach { user ->
                                ArcFilterChip(
                                    label = if (user.isAdmin) "${user.username} (Admin)" else user.username,
                                    selected = uiState.emailOrUsername.equals(user.username, ignoreCase = true),
                                    onClick = { viewModel.signInAsPreset(user) },
                                )
                            }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Title for current auth mode
            Text(
                text = when {
                    uiState.isResetPasswordMode -> "Reset Password"
                    uiState.isRegistrationMode -> "Create Account"
                    else -> "Sign In"
                },
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = ArcTheme.colors.textPrimary,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Start,
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Name field (Registration only)
            if (uiState.isRegistrationMode) {
                ArcTextField(
                    value = uiState.displayName,
                    onValueChange = viewModel::onDisplayNameChanged,
                    label = "Full Name",
                    placeholder = "e.g. Shreyas Shigwan",
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.Person,
                            contentDescription = null,
                            tint = ArcTheme.colors.textPlaceholder,
                        )
                    },
                )
                Spacer(modifier = Modifier.height(12.dp))
            }

            // Email / Username input
            ArcTextField(
                value = uiState.emailOrUsername,
                onValueChange = viewModel::onEmailOrUsernameChanged,
                label = if (uiState.isRegistrationMode || uiState.isResetPasswordMode) "Email Address" else "Email or Username",
                placeholder = if (uiState.isRegistrationMode || uiState.isResetPasswordMode) "user@domain.com" else "e.g. Shreyas or user@arc.app",
                leadingIcon = {
                    Icon(
                        imageVector = if (uiState.isRegistrationMode || uiState.isResetPasswordMode) Icons.Default.Email else Icons.Default.Person,
                        contentDescription = null,
                        tint = ArcTheme.colors.textPlaceholder,
                    )
                },
            )

            // Password input (hidden during password reset)
            if (!uiState.isResetPasswordMode) {
                Spacer(modifier = Modifier.height(12.dp))
                ArcTextField(
                    value = uiState.password,
                    onValueChange = viewModel::onPasswordChanged,
                    label = "Password",
                    placeholder = if (uiState.isRegistrationMode) "At least 6 characters" else "Enter password",
                    visualTransformation = PasswordVisualTransformation(),
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.Lock,
                            contentDescription = null,
                            tint = ArcTheme.colors.textPlaceholder,
                        )
                    },
                )
            }

            // Error display
            if (!uiState.errorMessage.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(12.dp))
                ArcErrorState(message = uiState.errorMessage!!)
            }

            // Info / Success message display
            if (!uiState.infoMessage.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = uiState.infoMessage!!,
                    color = ArcTheme.colors.accent,
                    fontSize = 13.sp,
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.Start,
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Primary Action Button
            ArcPrimaryButton(
                text = when {
                    uiState.isResetPasswordMode -> "Send Reset Link"
                    uiState.isRegistrationMode -> "Register"
                    else -> "Sign In"
                },
                onClick = viewModel::submit,
                isLoading = uiState.isLoading,
            )

            // Google Sign-In Button (shown during normal sign-in / registration)
            if (!uiState.isResetPasswordMode) {
                Spacer(modifier = Modifier.height(12.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(ArcDimens.ButtonHeight)
                        .clip(RoundedCornerShape(ArcDimens.RadiusButton))
                        .border(
                            width = 1.dp,
                            color = ArcTheme.colors.borderSubtle,
                            shape = RoundedCornerShape(ArcDimens.RadiusButton),
                        )
                        .background(ArcTheme.colors.card)
                        .clickable(enabled = !uiState.isLoading, onClick = viewModel::signInWithGoogle),
                    contentAlignment = Alignment.Center,
                ) {
                    if (uiState.isLoading) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = ArcTheme.colors.accent,
                            strokeWidth = 2.dp,
                        )
                    } else {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "Sign in with Google",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = ArcTheme.colors.textPrimary,
                            )
                        }
                    }
                }
            }

            // Mode Navigation Links
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(
                    onClick = viewModel::toggleRegistrationMode,
                ) {
                    Text(
                        text = if (uiState.isRegistrationMode) "Already have an account? Sign In" else "Create an account",
                        color = ArcTheme.colors.accent,
                        fontSize = 13.sp,
                    )
                }

                if (!uiState.isRegistrationMode) {
                    TextButton(
                        onClick = viewModel::toggleResetPasswordMode,
                    ) {
                        Text(
                            text = if (uiState.isResetPasswordMode) "Back to Sign In" else "Forgot Password?",
                            color = ArcTheme.colors.textSecondary,
                            fontSize = 13.sp,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}
