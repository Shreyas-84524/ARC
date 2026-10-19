package com.arc.arc.core.designsystem.components

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme

@Composable
fun ArcConfirmationDialog(
    title: String,
    message: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    confirmLabel: String = "Confirm",
    cancelLabel: String = "Cancel",
    isDanger: Boolean = false,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = modifier,
        shape = RoundedCornerShape(ArcDimens.RadiusCard),
        containerColor = ArcTheme.colors.modal,
        title = {
            Text(
                text = title,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = ArcTheme.colors.textPrimary,
            )
        },
        text = {
            Text(
                text = message,
                fontSize = 14.sp,
                color = ArcTheme.colors.textSecondary,
                lineHeight = 20.sp,
            )
        },
        confirmButton = {
            if (isDanger) {
                ArcDangerButton(
                    text = confirmLabel,
                    onClick = onConfirm,
                )
            } else {
                ArcPrimaryButton(
                    text = confirmLabel,
                    onClick = onConfirm,
                )
            }
        },
        dismissButton = {
            ArcTextButton(
                text = cancelLabel,
                onClick = onDismiss,
            )
        },
    )
}
