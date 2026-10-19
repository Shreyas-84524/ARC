package com.arc.arc.features.habits

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
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
import androidx.compose.ui.window.Dialog
import com.arc.arc.core.designsystem.components.ArcOutlinedButton
import com.arc.arc.core.designsystem.components.ArcPrimaryButton
import com.arc.arc.core.designsystem.components.ArcTextField
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.model.HabitModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HabitEditorSheet(
    habitToEdit: HabitModel?,
    onDismiss: () -> Unit,
    onSave: (name: String, category: String, colorValue: Long, reminderTime: String?) -> Unit,
    modifier: Modifier = Modifier,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var name by remember(habitToEdit) { mutableStateOf(habitToEdit?.name ?: "") }
    var category by remember(habitToEdit) { mutableStateOf(habitToEdit?.category ?: "Health") }
    var selectedColor by remember(habitToEdit) { mutableLongStateOf(habitToEdit?.colorValue ?: HabitConstants.PRESET_COLORS.first()) }
    var reminderTime by remember(habitToEdit) { mutableStateOf(habitToEdit?.reminderTime) }

    var isCategoryExpanded by remember { mutableStateOf(false) }
    var showTimePickerDialog by remember { mutableStateOf(false) }
    var nameError by remember { mutableStateOf<String?>(null) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = ArcTheme.colors.surface,
        modifier = modifier,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = ArcDimens.SpacingLg)
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding(),
        ) {
            // Header
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = if (habitToEdit == null) "New Habit" else "Edit Habit",
                    style = ArcTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
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

            Spacer(modifier = Modifier.height(ArcDimens.SpacingMd))

            // Habit Name Input
            ArcTextField(
                value = name,
                onValueChange = {
                    name = it
                    if (nameError != null && it.isNotBlank()) nameError = null
                },
                label = "Habit Name",
                placeholder = "e.g., Drink 2L water, Morning jog...",
                isError = nameError != null,
                errorMessage = nameError,
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(modifier = Modifier.height(ArcDimens.SpacingMd))

            // Category Dropdown
            Text(
                text = "Category",
                style = ArcTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                color = ArcTheme.colors.textSecondary,
            )
            Spacer(modifier = Modifier.height(4.dp))
            ExposedDropdownMenuBox(
                expanded = isCategoryExpanded,
                onExpandedChange = { isCategoryExpanded = !isCategoryExpanded },
                modifier = Modifier.fillMaxWidth(),
            ) {
                OutlinedTextField(
                    value = category,
                    onValueChange = {},
                    readOnly = true,
                    shape = RoundedCornerShape(ArcDimens.RadiusInput),
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = isCategoryExpanded) },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = ArcTheme.colors.surface,
                        unfocusedContainerColor = ArcTheme.colors.surface,
                        focusedBorderColor = ArcTheme.colors.accent,
                        unfocusedBorderColor = ArcTheme.colors.borderSubtle,
                        focusedTextColor = ArcTheme.colors.textPrimary,
                        unfocusedTextColor = ArcTheme.colors.textPrimary,
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable),
                )
                ExposedDropdownMenu(
                    expanded = isCategoryExpanded,
                    onDismissRequest = { isCategoryExpanded = false },
                    modifier = Modifier.background(ArcTheme.colors.surface),
                ) {
                    HabitConstants.CATEGORIES.forEach { cat ->
                        DropdownMenuItem(
                            text = { Text(cat, color = ArcTheme.colors.textPrimary) },
                            onClick = {
                                category = cat
                                isCategoryExpanded = false
                            },
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(ArcDimens.SpacingLg))

            // Color Palette Selector
            Text(
                text = "Habit Color",
                style = ArcTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                color = ArcTheme.colors.textSecondary,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                HabitConstants.PRESET_COLORS.forEach { colorValue ->
                    val isSelected = selectedColor == colorValue
                    val color = Color(colorValue.toInt())
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .size(38.dp)
                            .clip(CircleShape)
                            .background(color)
                            .border(
                                width = if (isSelected) 3.dp else 1.dp,
                                color = if (isSelected) Color.White else ArcTheme.colors.borderSubtle,
                                shape = CircleShape,
                            )
                            .clickable { selectedColor = colorValue },
                    ) {
                        if (isSelected) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = "Selected color",
                                tint = Color.Black,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(ArcDimens.SpacingLg))

            // Reminder Time Picker Section
            Text(
                text = "Daily Reminder",
                style = ArcTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                color = ArcTheme.colors.textSecondary,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(ArcTheme.colors.surfaceVariant, RoundedCornerShape(ArcDimens.RadiusInput))
                    .padding(horizontal = 16.dp, vertical = 12.dp)
                    .clickable { showTimePickerDialog = true },
            ) {
                Icon(
                    imageVector = Icons.Default.Alarm,
                    contentDescription = null,
                    tint = ArcTheme.colors.accent,
                    modifier = Modifier.size(20.dp),
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = reminderTime ?: "No reminder set",
                    style = ArcTheme.typography.bodyMedium,
                    color = if (reminderTime != null) ArcTheme.colors.textPrimary else ArcTheme.colors.textSecondary,
                    modifier = Modifier.weight(1f),
                )
                if (reminderTime != null) {
                    IconButton(
                        onClick = { reminderTime = null },
                        modifier = Modifier.size(24.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Clear reminder",
                            tint = ArcTheme.colors.textSecondary,
                            modifier = Modifier.size(16.dp),
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(ArcDimens.SpacingXl))

            // Action Buttons
            Row(
                horizontalArrangement = Arrangement.spacedBy(ArcDimens.SpacingMd),
                modifier = Modifier.fillMaxWidth(),
            ) {
                ArcOutlinedButton(
                    text = "Cancel",
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f),
                )
                ArcPrimaryButton(
                    text = if (habitToEdit == null) "Create Habit" else "Save Changes",
                    onClick = {
                        if (name.isBlank()) {
                            nameError = "Please enter a habit name"
                        } else {
                            onSave(name, category, selectedColor, reminderTime)
                        }
                    },
                    modifier = Modifier.weight(1f),
                )
            }

            Spacer(modifier = Modifier.height(ArcDimens.SpacingLg))
        }
    }

    // Time Picker Dialog
    if (showTimePickerDialog) {
        val initialHour = reminderTime?.split(":")?.getOrNull(0)?.toIntOrNull() ?: 8
        val initialMinute = reminderTime?.split(":")?.getOrNull(1)?.toIntOrNull() ?: 0
        val timePickerState = rememberTimePickerState(
            initialHour = initialHour,
            initialMinute = initialMinute,
            is24Hour = false,
        )

        Dialog(onDismissRequest = { showTimePickerDialog = false }) {
            Surface(
                shape = RoundedCornerShape(ArcDimens.RadiusCard),
                color = ArcTheme.colors.surface,
                modifier = Modifier.padding(16.dp),
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(20.dp),
                ) {
                    Text(
                        text = "Select Reminder Time",
                        style = ArcTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = ArcTheme.colors.textPrimary,
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    TimePicker(state = timePickerState)
                    Spacer(modifier = Modifier.height(16.dp))
                    Row(
                        horizontalArrangement = Arrangement.End,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        TextButton(onClick = { showTimePickerDialog = false }) {
                            Text("Cancel", color = ArcTheme.colors.textSecondary)
                        }
                        TextButton(
                            onClick = {
                                val h = timePickerState.hour.toString().padStart(2, '0')
                                val m = timePickerState.minute.toString().padStart(2, '0')
                                reminderTime = "$h:$m"
                                showTimePickerDialog = false
                            },
                        ) {
                            Text("Set Time", color = ArcTheme.colors.accent, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}
