package com.arc.arc.features.money.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Security
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.components.ArcPrimaryButton
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.core.utilities.CurrencyFormatter
import com.arc.arc.features.money.automation.MoneyAutomationRawEvent
import com.arc.arc.features.money.automation.MoneyTransactionClassification
import com.arc.arc.features.money.automation.MoneyTransactionParser
import com.arc.arc.features.money.automation.ParsedMoneyTransaction
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MoneySettingsSheet(
    sheetState: SheetState,
    isDetectionEnabled: Boolean,
    isAutoSaveEnabled: Boolean,
    onToggleDetection: (Boolean) -> Unit,
    onToggleAutoSave: (Boolean) -> Unit,
    onSimulateTransaction: (TransactionModel) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val parser = remember { MoneyTransactionParser() }
    var selectedSimulationTemplate by remember { mutableStateOf(0) }
    var simulationResult by remember { mutableStateOf<ParsedMoneyTransaction?>(null) }
    var simulationMessage by remember { mutableStateOf<String?>(null) }

    val templates = listOf(
        Pair("HDFC Swiggy (₹1,450.50)", MoneyAutomationRawEvent(
            sender = "HDFCBK",
            body = "Dear Customer, INR 1,450.50 debited from A/c **1234 on 12-OCT-26 towards SWIGGY. UPI Ref 6284910284. Avl Bal INR 45,230.50",
            timestamp = Date(),
        )),
        Pair("SBI Uber (₹2,500.00)", MoneyAutomationRawEvent(
            sender = "SBIINB",
            body = "Your A/c ending 9876 debited by Rs.2,500.00 on 10/10/2026 for Uber Rides. Ref no 99881122. Bal: Rs.12,000.00",
            timestamp = Date(),
        )),
        Pair("ICICI Fuel (₹350.00)", MoneyAutomationRawEvent(
            sender = "ICICIB",
            body = "Acct XX4321 debited with INR 350.00 at Shell Fuel Station on 05-10-26. Txn id 883719. Avl bal INR 10,000.00",
            timestamp = Date(),
        )),
        Pair("Bank OTP (Rejection)", MoneyAutomationRawEvent(
            sender = "VM-HDFCBK",
            body = "Your OTP for transaction of INR 500.00 at Amazon is 492019. Valid for 10 mins. Do not share with anyone.",
            timestamp = Date(),
        )),
        Pair("Salary Credit (Rejection)", MoneyAutomationRawEvent(
            sender = "AXISBK",
            body = "Salary of Rs. 85,000.00 credited to A/c **1234 on 01-10-2026. Avl bal INR 1,20,000.00",
            timestamp = Date(),
        )),
    )

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
                .padding(bottom = 32.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Money Settings & Automation",
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

            // Privacy Disclosure Banner
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(ArcDimens.RadiusCard))
                    .border(1.dp, ArcTheme.colors.accent.copy(alpha = 0.3f), RoundedCornerShape(ArcDimens.RadiusCard)),
                color = ArcTheme.colors.accent.copy(alpha = 0.08f),
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Icon(
                        imageVector = Icons.Default.Security,
                        contentDescription = "Security",
                        tint = ArcTheme.colors.accent,
                        modifier = Modifier.size(24.dp),
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = "100% On-Device Privacy Guaranteed",
                            style = ArcTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                            color = ArcTheme.colors.textPrimary,
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "ARC strictly analyzes financial texts locally. No SMS bodies are saved or uploaded to any server. OTPs, credits, and personal texts are rejected unconditionally. No dangerous SMS permissions are requested.",
                            style = ArcTheme.typography.bodyMedium.copy(fontSize = 12.sp, lineHeight = 17.sp),
                            color = ArcTheme.colors.textSecondary,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Automation Switches
            SettingToggleRow(
                title = "Expense Detection",
                subtitle = "Enable local deterministic parsing of payment events",
                checked = isDetectionEnabled,
                onCheckedChange = onToggleDetection,
            )

            HorizontalDivider(color = ArcTheme.colors.borderSubtle.copy(alpha = 0.5f), thickness = 0.5.dp, modifier = Modifier.padding(vertical = 12.dp))

            SettingToggleRow(
                title = "Auto-Save Confirmed Debits",
                subtitle = "Automatically add high-confidence debits without manual prompt",
                checked = isAutoSaveEnabled,
                enabled = isDetectionEnabled,
                onCheckedChange = onToggleAutoSave,
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Safe Simulation / Verification Section
            Text(
                text = "Safe Bank SMS Simulator",
                style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold, fontSize = 16.sp),
                color = ArcTheme.colors.textPrimary,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Select a synthetic template to test local parsing safely without SMS permissions:",
                style = ArcTheme.typography.bodyMedium.copy(fontSize = 12.sp, color = ArcTheme.colors.textSecondary),
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Template Chips
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                templates.forEachIndexed { index, (label, _) ->
                    val isSelected = selectedSimulationTemplate == index
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(if (isSelected) ArcTheme.colors.accent else ArcTheme.colors.background)
                            .border(1.dp, if (isSelected) ArcTheme.colors.accent else ArcTheme.colors.borderSubtle, RoundedCornerShape(8.dp))
                            .clickable {
                                selectedSimulationTemplate = index
                                simulationResult = null
                                simulationMessage = null
                            }
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                    ) {
                        Text(
                            text = label,
                            style = ArcTheme.typography.bodyMedium.copy(
                                fontSize = 12.sp,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSelected) Color(0xFF111827) else ArcTheme.colors.textPrimary,
                            ),
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Run Simulation Button
            ArcPrimaryButton(
                text = "Parse Synthetic Event",
                icon = Icons.Default.PlayArrow,
                onClick = {
                    val template = templates[selectedSimulationTemplate].second
                    val parsed = parser.parse(template)
                    simulationResult = parsed
                    simulationMessage = if (parsed.isConfirmedDebit) {
                        "Accepted: Valid debit parsed successfully!"
                    } else {
                        "Rejected: ${parsed.classification.name} is not an eligible expense."
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            )

            // Simulation Result Output
            simulationResult?.let { res ->
                Spacer(modifier = Modifier.height(16.dp))
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .border(
                            1.dp,
                            if (res.isConfirmedDebit) ArcTheme.colors.success else ArcTheme.colors.danger,
                            RoundedCornerShape(8.dp)
                        ),
                    color = ArcTheme.colors.background,
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = if (res.isConfirmedDebit) Icons.Default.CheckCircle else Icons.Default.ErrorOutline,
                                contentDescription = null,
                                tint = if (res.isConfirmedDebit) ArcTheme.colors.success else ArcTheme.colors.danger,
                                modifier = Modifier.size(18.dp),
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = simulationMessage ?: "",
                                style = ArcTheme.typography.bodyMedium.copy(
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 13.sp,
                                    color = if (res.isConfirmedDebit) ArcTheme.colors.success else ArcTheme.colors.danger,
                                ),
                            )
                        }

                        if (res.isConfirmedDebit) {
                            Spacer(modifier = Modifier.height(10.dp))
                            Text(
                                text = "Amount: ${CurrencyFormatter.formatPaise(res.amountPaise)} • Category: ${parser.inferCategory(res.merchantOrDescription)}",
                                style = ArcTheme.typography.bodyMedium.copy(fontSize = 12.sp, color = ArcTheme.colors.textSecondary),
                            )
                            Text(
                                text = "Merchant: ${res.merchantOrDescription ?: "Unknown"} • Ref: ${res.referenceId ?: "N/A"}",
                                style = ArcTheme.typography.bodyMedium.copy(fontSize = 12.sp, color = ArcTheme.colors.textSecondary),
                            )

                            Spacer(modifier = Modifier.height(12.dp))
                            ArcPrimaryButton(
                                text = "Add To Current Transactions",
                                onClick = {
                                    val tx = res.toTransactionModel(
                                        ownerUid = "",
                                        category = parser.inferCategory(res.merchantOrDescription),
                                    )
                                    onSimulateTransaction(tx)
                                    simulationMessage = "Added transaction to your ledger!"
                                },
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingToggleRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    enabled: Boolean = true,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = ArcTheme.typography.bodyMedium.copy(
                    fontWeight = FontWeight.SemiBold,
                    color = if (enabled) ArcTheme.colors.textPrimary else ArcTheme.colors.textDisabled,
                ),
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = ArcTheme.typography.bodySmall.copy(
                    fontSize = 12.sp,
                    color = ArcTheme.colors.textSecondary,
                ),
            )
        }
        Spacer(modifier = Modifier.width(16.dp))
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            enabled = enabled,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color(0xFF111827),
                checkedTrackColor = ArcTheme.colors.accent,
                uncheckedTrackColor = ArcTheme.colors.background,
                uncheckedThumbColor = ArcTheme.colors.textSecondary,
            ),
        )
    }
}
