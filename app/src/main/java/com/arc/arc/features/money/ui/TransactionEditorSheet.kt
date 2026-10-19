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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.components.ArcPrimaryButton
import com.arc.arc.core.designsystem.components.ArcTextField
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.core.utilities.CurrencyFormatter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransactionEditorSheet(
    sheetState: SheetState,
    onDismiss: () -> Unit,
    onSaveTransaction: (TransactionModel) -> Unit,
    modifier: Modifier = Modifier,
) {
    val expenseCategories = listOf("Food", "Travel", "Shopping", "Fuel", "Bills", "Entertainment", "Health", "Education", "Other")
    val incomeCategories = listOf("Salary", "Freelancing", "Investment", "Gift", "Other")

    var selectedType by remember { mutableStateOf("Expense") }
    var amountText by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf("Food") }
    var selectedDate by remember { mutableStateOf(Date()) }
    var selectedTimeStr by remember {
        val sdf = SimpleDateFormat("HH:mm", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        mutableStateOf(sdf.format(Date()))
    }
    var notesText by remember { mutableStateOf("") }
    var amountError by remember { mutableStateOf<String?>(null) }

    var showDatePicker by remember { mutableStateOf(false) }
    var showTimePicker by remember { mutableStateOf(false) }

    val dateDisplayFormat = SimpleDateFormat("dd MMM yyyy", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(initialSelectedDateMillis = selectedDate.time)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let {
                        selectedDate = Date(it)
                    }
                    showDatePicker = false
                }) {
                    Text("OK", color = ArcTheme.colors.accent)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text("Cancel", color = ArcTheme.colors.textSecondary)
                }
            },
        ) {
            DatePicker(state = datePickerState)
        }
    }

    if (showTimePicker) {
        val timePickerState = rememberTimePickerState(is24Hour = true)
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { showTimePicker = false },
            title = { Text("Select Time", color = ArcTheme.colors.textPrimary) },
            text = { TimePicker(state = timePickerState) },
            confirmButton = {
                TextButton(onClick = {
                    val hh = timePickerState.hour.toString().padStart(2, '0')
                    val mm = timePickerState.minute.toString().padStart(2, '0')
                    selectedTimeStr = "$hh:$mm"
                    showTimePicker = false
                }) {
                    Text("OK", color = ArcTheme.colors.accent)
                }
            },
            dismissButton = {
                TextButton(onClick = { showTimePicker = false }) {
                    Text("Cancel", color = ArcTheme.colors.textSecondary)
                }
            },
            containerColor = ArcTheme.colors.surface,
        )
    }

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
                    text = "Add Transaction",
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

            // Type Toggle: Expense / Income
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(ArcTheme.colors.background)
                    .padding(4.dp),
            ) {
                TypeToggleButton(
                    title = "Expense",
                    isSelected = selectedType == "Expense",
                    selectedColor = ArcTheme.colors.danger,
                    modifier = Modifier.weight(1f),
                    onClick = {
                        selectedType = "Expense"
                        selectedCategory = "Food"
                    },
                )
                TypeToggleButton(
                    title = "Income",
                    isSelected = selectedType == "Income",
                    selectedColor = ArcTheme.colors.success,
                    modifier = Modifier.weight(1f),
                    onClick = {
                        selectedType = "Income"
                        selectedCategory = "Salary"
                    },
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Amount Input
            ArcTextField(
                value = amountText,
                onValueChange = {
                    amountText = it
                    amountError = null
                },
                label = "Amount (${CurrencyFormatter.SYMBOL})",
                placeholder = "0.00",
                isError = amountError != null,
                errorMessage = amountError,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(modifier = Modifier.height(20.dp))

            // Category Picker
            Text(
                text = "Category",
                style = ArcTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                color = ArcTheme.colors.textSecondary,
            )
            Spacer(modifier = Modifier.height(8.dp))
            val currentCategories = if (selectedType == "Income") incomeCategories else expenseCategories
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                currentCategories.forEach { category ->
                    val isSelected = selectedCategory == category
                    val chipColor = if (isSelected) ArcTheme.colors.accent else ArcTheme.colors.surface
                    val textColor = if (isSelected) Color.White else ArcTheme.colors.textPrimary

                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(chipColor)
                            .border(1.dp, if (isSelected) ArcTheme.colors.accent else ArcTheme.colors.borderSubtle, RoundedCornerShape(8.dp))
                            .clickable { selectedCategory = category }
                            .padding(horizontal = 14.dp, vertical = 8.dp),
                    ) {
                        Text(
                            text = category,
                            style = ArcTheme.typography.bodyMedium.copy(
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                fontSize = 13.sp,
                            ),
                            color = textColor,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Date & Time Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Date Button
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(ArcDimens.RadiusInput))
                        .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(ArcDimens.RadiusInput))
                        .clickable { showDatePicker = true },
                    color = ArcTheme.colors.surface,
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = Icons.Default.CalendarToday,
                            contentDescription = "Date",
                            tint = ArcTheme.colors.accent,
                            modifier = Modifier.size(16.dp),
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = dateDisplayFormat.format(selectedDate),
                            style = ArcTheme.typography.bodyMedium.copy(fontSize = 13.sp),
                            color = ArcTheme.colors.textPrimary,
                        )
                    }
                }

                // Time Button
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(ArcDimens.RadiusInput))
                        .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(ArcDimens.RadiusInput))
                        .clickable { showTimePicker = true },
                    color = ArcTheme.colors.surface,
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = Icons.Default.AccessTime,
                            contentDescription = "Time",
                            tint = ArcTheme.colors.accent,
                            modifier = Modifier.size(16.dp),
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = selectedTimeStr,
                            style = ArcTheme.typography.bodyMedium.copy(fontSize = 13.sp),
                            color = ArcTheme.colors.textPrimary,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Notes field
            ArcTextField(
                value = notesText,
                onValueChange = { notesText = it },
                label = "Notes / Description (Optional)",
                placeholder = "What was this for?",
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(modifier = Modifier.height(28.dp))

            // Save Button
            ArcPrimaryButton(
                text = "Save Transaction",
                onClick = {
                    val paise = CurrencyFormatter.parseToPaise(amountText)
                    if (paise == null || paise <= 0L) {
                        amountError = "Please enter a valid amount greater than zero"
                    } else {
                        val newTx = TransactionModel.fromPaise(
                            id = UUID.randomUUID().toString(),
                            amountPaise = paise,
                            type = selectedType,
                            category = selectedCategory,
                            date = selectedDate,
                            time = selectedTimeStr,
                            notes = notesText.trim(),
                            createdAt = Date(),
                            source = "manual",
                        )
                        onSaveTransaction(newTx)
                        onDismiss()
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun TypeToggleButton(
    title: String,
    isSelected: Boolean,
    selectedColor: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(6.dp))
            .background(if (isSelected) selectedColor.copy(alpha = 0.2f) else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = title,
            style = ArcTheme.typography.titleMedium.copy(
                fontSize = 14.sp,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
            ),
            color = if (isSelected) selectedColor else ArcTheme.colors.textSecondary,
        )
    }
}
