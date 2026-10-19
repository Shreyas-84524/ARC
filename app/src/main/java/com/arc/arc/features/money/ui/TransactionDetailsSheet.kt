package com.arc.arc.features.money.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.ShoppingBag
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.components.ArcDangerButton
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.core.utilities.CurrencyFormatter
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransactionDetailsSheet(
    transaction: TransactionModel,
    sheetState: SheetState,
    onDismiss: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val dateFormat = SimpleDateFormat("EEEE, dd MMMM yyyy", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }
    val dateDisplay = dateFormat.format(transaction.date)

    val amountColor = if (transaction.isIncome) {
        ArcTheme.colors.success
    } else {
        ArcTheme.colors.danger
    }

    val amountPrefix = if (transaction.isIncome) "+" else "-"

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = ArcTheme.colors.surface,
        modifier = modifier,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp),
        ) {
            // Header with close
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Transaction Details",
                    style = ArcTheme.typography.titleMedium.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp,
                    ),
                    color = ArcTheme.colors.textPrimary,
                )
                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = ArcTheme.colors.textSecondary,
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Big Amount Header
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(amountColor.copy(alpha = 0.08f))
                    .padding(20.dp),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "$amountPrefix${CurrencyFormatter.formatPaise(transaction.amountPaise)}",
                        style = ArcTheme.typography.headlineLarge.copy(
                            fontWeight = FontWeight.Bold,
                            color = amountColor,
                            fontSize = 32.sp,
                        ),
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "${transaction.type} • ${transaction.category}",
                        style = ArcTheme.typography.bodyMedium.copy(
                            color = ArcTheme.colors.textSecondary,
                            fontWeight = FontWeight.Medium,
                        ),
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Metadata rows
            DetailRow(label = "Category", value = transaction.category)
            HorizontalDivider(color = ArcTheme.colors.borderSubtle.copy(alpha = 0.5f), thickness = 0.5.dp)

            DetailRow(label = "Date", value = dateDisplay)
            HorizontalDivider(color = ArcTheme.colors.borderSubtle.copy(alpha = 0.5f), thickness = 0.5.dp)

            if (transaction.time.isNotBlank()) {
                DetailRow(label = "Time", value = transaction.time)
                HorizontalDivider(color = ArcTheme.colors.borderSubtle.copy(alpha = 0.5f), thickness = 0.5.dp)
            }

            val sourceLabel = if (transaction.source == "sms_auto") "Automatic (SMS Detected)" else "Manual Entry"
            DetailRow(label = "Source", value = sourceLabel)
            HorizontalDivider(color = ArcTheme.colors.borderSubtle.copy(alpha = 0.5f), thickness = 0.5.dp)

            if (transaction.notes.isNotBlank()) {
                DetailRow(label = "Notes", value = transaction.notes)
                HorizontalDivider(color = ArcTheme.colors.borderSubtle.copy(alpha = 0.5f), thickness = 0.5.dp)
            }

            if (!transaction.automationFingerprint.isNullOrBlank()) {
                val shortFp = transaction.automationFingerprint.take(12) + "..."
                DetailRow(label = "Fingerprint", value = shortFp)
                HorizontalDivider(color = ArcTheme.colors.borderSubtle.copy(alpha = 0.5f), thickness = 0.5.dp)
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Delete Action
            ArcDangerButton(
                text = "Delete Transaction",
                onClick = {
                    onDelete()
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun DetailRow(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = ArcTheme.typography.bodyMedium.copy(color = ArcTheme.colors.textSecondary),
        )
        Text(
            text = value,
            style = ArcTheme.typography.bodyMedium.copy(
                color = ArcTheme.colors.textPrimary,
                fontWeight = FontWeight.SemiBold,
            ),
        )
    }
}
