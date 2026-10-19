package com.arc.arc.features.money.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.components.ArcPrimaryButton
import com.arc.arc.core.designsystem.components.ArcTextField
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.utilities.CurrencyFormatter
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun SetBudgetDialog(
    currentMonth: String,
    currentBudgetPaise: Long,
    onDismiss: () -> Unit,
    onSetBudget: (Long) -> Unit,
    modifier: Modifier = Modifier,
) {
    var textValue by remember {
        mutableStateOf(if (currentBudgetPaise > 0L) (currentBudgetPaise / 100).toString() else "")
    }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val monthDisplayName = try {
        val ym = YearMonth.parse(currentMonth)
        ym.format(DateTimeFormatter.ofPattern("MMMM yyyy", Locale.US))
    } catch (_: Exception) {
        currentMonth
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = "Set Monthly Budget",
                style = ArcTheme.typography.titleMedium.copy(
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp,
                ),
                color = ArcTheme.colors.textPrimary,
            )
        },
        text = {
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = "Configure your spending budget for $monthDisplayName.",
                    style = ArcTheme.typography.bodyMedium.copy(color = ArcTheme.colors.textSecondary),
                )
                Spacer(modifier = Modifier.height(16.dp))
                ArcTextField(
                    value = textValue,
                    onValueChange = {
                        textValue = it
                        errorMessage = null
                    },
                    label = "Monthly Budget (${CurrencyFormatter.SYMBOL})",
                    placeholder = "e.g. 50000",
                    isError = errorMessage != null,
                    errorMessage = errorMessage,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            ArcPrimaryButton(
                text = "Set Budget",
                onClick = {
                    val paise = CurrencyFormatter.parseToPaise(textValue)
                    if (paise == null || paise <= 0L) {
                        errorMessage = "Please enter a valid positive amount"
                    } else {
                        onSetBudget(paise)
                        onDismiss()
                    }
                },
            )
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(
                    text = "Cancel",
                    color = ArcTheme.colors.textSecondary,
                )
            }
        },
        containerColor = ArcTheme.colors.surface,
        modifier = modifier,
    )
}
