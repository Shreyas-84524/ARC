package com.arc.arc.core.designsystem.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme

@Composable
fun ArcTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    placeholder: String? = null,
    leadingIcon: @Composable (() -> Unit)? = null,
    trailingIcon: @Composable (() -> Unit)? = null,
    isError: Boolean = false,
    errorMessage: String? = null,
    singleLine: Boolean = true,
    maxLines: Int = if (singleLine) 1 else 4,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    enabled: Boolean = true,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .fillMaxWidth()
                .semantics(mergeDescendants = true) {},
            label = label?.let {
                {
                    Text(
                        text = it,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                    )
                }
            },
            placeholder = placeholder?.let {
                {
                    Text(
                        text = it,
                        color = ArcTheme.colors.textPlaceholder,
                        fontSize = 14.sp,
                    )
                }
            },
            leadingIcon = leadingIcon,
            trailingIcon = trailingIcon,
            isError = isError,
            singleLine = singleLine,
            maxLines = maxLines,
            enabled = enabled,
            visualTransformation = visualTransformation,
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
            shape = RoundedCornerShape(ArcDimens.RadiusInput),
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = ArcTheme.colors.surface,
                unfocusedContainerColor = ArcTheme.colors.surface,
                disabledContainerColor = ArcTheme.colors.surface.copy(alpha = 0.5f),
                focusedBorderColor = ArcTheme.colors.accent,
                unfocusedBorderColor = ArcTheme.colors.borderSubtle,
                errorBorderColor = ArcTheme.colors.danger,
                focusedTextColor = ArcTheme.colors.textPrimary,
                unfocusedTextColor = ArcTheme.colors.textPrimary,
                focusedLabelColor = ArcTheme.colors.accent,
                unfocusedLabelColor = ArcTheme.colors.textSecondary,
                cursorColor = ArcTheme.colors.accent,
            ),
        )

        if (isError && !errorMessage.isNullOrBlank()) {
            Text(
                text = errorMessage,
                color = ArcTheme.colors.danger,
                fontSize = 12.sp,
                modifier = Modifier.padding(start = 16.dp, top = 4.dp),
            )
        }
    }
}
