package com.arc.arc.features.tasks

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
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
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.arc.arc.core.designsystem.components.ArcPrimaryButton
import com.arc.arc.core.designsystem.components.ArcPriorityBadge
import com.arc.arc.core.designsystem.components.ArcTextField
import com.arc.arc.core.designsystem.theme.ArcDimens
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.model.DateTimeUtils
import com.arc.arc.core.model.TaskConstants
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TaskPriority
import java.util.Calendar
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaskEditorSheet(
    taskToEdit: TaskModel?,
    onSave: (
        title: String,
        description: String,
        category: String,
        priority: String,
        labels: List<String>,
        dueDate: Date?,
        dueTime: String?,
        reminder: Date?,
    ) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var title by remember { mutableStateOf(taskToEdit?.title ?: "") }
    var description by remember { mutableStateOf(taskToEdit?.description ?: "") }
    var selectedCategory by remember { mutableStateOf(taskToEdit?.category ?: TaskConstants.DEFAULT_CATEGORY) }
    var selectedPriority by remember { mutableStateOf(taskToEdit?.displayPriority ?: "Low") }
    var labelsText by remember { mutableStateOf(taskToEdit?.labels?.joinToString(", ") ?: "") }
    var selectedDueDate by remember { mutableStateOf(taskToEdit?.dueDate) }
    var selectedDueTime by remember { mutableStateOf(taskToEdit?.dueTime) }
    var titleError by remember { mutableStateOf<String?>(null) }

    var isCategoryExpanded by remember { mutableStateOf(false) }
    var isPriorityExpanded by remember { mutableStateOf(false) }
    var showDatePicker by remember { mutableStateOf(false) }
    var showTimePicker by remember { mutableStateOf(false) }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = ArcTheme.colors.modal,
        shape = RoundedCornerShape(topStart = ArcDimens.RadiusCard, topEnd = ArcDimens.RadiusCard),
        modifier = modifier,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp)
                .navigationBarsPadding()
                .verticalScroll(rememberScrollState()),
        ) {
            // Header Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = if (taskToEdit == null) "Create Task" else "Edit Task",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
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

            // Title Field
            ArcTextField(
                value = title,
                onValueChange = {
                    title = it
                    if (it.isNotBlank()) titleError = null
                },
                placeholder = "Task Title",
                label = "Title",
                isError = titleError != null,
                errorMessage = titleError,
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Description Field
            ArcTextField(
                value = description,
                onValueChange = { description = it },
                placeholder = "Description (optional)",
                label = "Description",
                singleLine = false,
                maxLines = 3,
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Category and Priority Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Category Dropdown
                ExposedDropdownMenuBox(
                    expanded = isCategoryExpanded,
                    onExpandedChange = { isCategoryExpanded = !isCategoryExpanded },
                    modifier = Modifier.weight(1f),
                ) {
                    OutlinedTextField(
                        value = selectedCategory,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Category", fontSize = 12.sp) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = isCategoryExpanded) },
                        shape = RoundedCornerShape(ArcDimens.RadiusInput),
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
                        TaskConstants.CATEGORIES.forEach { category ->
                            DropdownMenuItem(
                                text = { Text(category, color = ArcTheme.colors.textPrimary) },
                                onClick = {
                                    selectedCategory = category
                                    isCategoryExpanded = false
                                },
                            )
                        }
                    }
                }

                // Priority Dropdown
                ExposedDropdownMenuBox(
                    expanded = isPriorityExpanded,
                    onExpandedChange = { isPriorityExpanded = !isPriorityExpanded },
                    modifier = Modifier.weight(1f),
                ) {
                    OutlinedTextField(
                        value = selectedPriority,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Priority", fontSize = 12.sp) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = isPriorityExpanded) },
                        shape = RoundedCornerShape(ArcDimens.RadiusInput),
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
                        expanded = isPriorityExpanded,
                        onDismissRequest = { isPriorityExpanded = false },
                        modifier = Modifier.background(ArcTheme.colors.surface),
                    ) {
                        TaskPriority.entries.forEach { p ->
                            DropdownMenuItem(
                                text = {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(p.emoji)
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(p.displayName, color = ArcTheme.colors.textPrimary)
                                    }
                                },
                                onClick = {
                                    selectedPriority = p.displayName
                                    isPriorityExpanded = false
                                },
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Labels Input
            ArcTextField(
                value = labelsText,
                onValueChange = { labelsText = it },
                label = "Labels",
                placeholder = "Labels (comma separated, e.g. work, urgent)",
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Due Date & Time Triggers
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Due Date Trigger
                Surface(
                    shape = RoundedCornerShape(ArcDimens.RadiusInput),
                    color = ArcTheme.colors.surface,
                    border = androidx.compose.foundation.BorderStroke(1.dp, ArcTheme.colors.borderSubtle),
                    modifier = Modifier
                        .weight(1f)
                        .clickable { showDatePicker = true },
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = Icons.Default.CalendarToday,
                            contentDescription = null,
                            tint = ArcTheme.colors.accent,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = selectedDueDate?.let { DateTimeUtils.formatDisplayDate(it) } ?: "Set Date",
                            fontSize = 13.sp,
                            fontWeight = if (selectedDueDate != null) FontWeight.Bold else FontWeight.Normal,
                            color = if (selectedDueDate != null) ArcTheme.colors.textPrimary else ArcTheme.colors.textPlaceholder,
                        )
                    }
                }

                // Due Time Trigger
                Surface(
                    shape = RoundedCornerShape(ArcDimens.RadiusInput),
                    color = ArcTheme.colors.surface,
                    border = androidx.compose.foundation.BorderStroke(1.dp, ArcTheme.colors.borderSubtle),
                    modifier = Modifier
                        .weight(1f)
                        .clickable { showTimePicker = true },
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = Icons.Default.Schedule,
                            contentDescription = null,
                            tint = ArcTheme.colors.accent,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = selectedDueTime ?: "Set Time",
                            fontSize = 13.sp,
                            fontWeight = if (selectedDueTime != null) FontWeight.Bold else FontWeight.Normal,
                            color = if (selectedDueTime != null) ArcTheme.colors.textPrimary else ArcTheme.colors.textPlaceholder,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(28.dp))

            // Save Button
            ArcPrimaryButton(
                text = if (taskToEdit == null) "Create Task" else "Save Changes",
                onClick = {
                    if (title.isBlank()) {
                        titleError = "Title cannot be empty"
                        return@ArcPrimaryButton
                    }

                    val labels = labelsText
                        .split(",")
                        .map { it.trim() }
                        .filter { it.isNotBlank() && it.length <= 30 }
                        .take(10)

                    onSave(
                        title,
                        description,
                        selectedCategory,
                        selectedPriority,
                        labels,
                        selectedDueDate,
                        selectedDueTime,
                        selectedDueDate, // default reminder
                    )
                },
            )
            Spacer(modifier = Modifier.height(16.dp))
        }
    }

    // Material 3 Date Picker Dialog
    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = selectedDueDate?.time ?: System.currentTimeMillis()
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let {
                            selectedDueDate = Date(it)
                        }
                        showDatePicker = false
                    }
                ) {
                    Text("OK", color = ArcTheme.colors.accent, fontWeight = FontWeight.Bold)
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

    // Material 3 Time Picker Dialog
    if (showTimePicker) {
        val initialCal = Calendar.getInstance()
        val timePickerState = rememberTimePickerState(
            initialHour = initialCal.get(Calendar.HOUR_OF_DAY),
            initialMinute = initialCal.get(Calendar.MINUTE),
            is24Hour = true,
        )
        Dialog(onDismissRequest = { showTimePicker = false }) {
            Surface(
                shape = RoundedCornerShape(ArcDimens.RadiusCard),
                color = ArcTheme.colors.modal,
                modifier = Modifier.padding(16.dp),
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "Select Due Time",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = ArcTheme.colors.textPrimary,
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    TimePicker(state = timePickerState)
                    Spacer(modifier = Modifier.height(16.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End,
                    ) {
                        TextButton(onClick = { showTimePicker = false }) {
                            Text("Cancel", color = ArcTheme.colors.textSecondary)
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        TextButton(
                            onClick = {
                                val hh = timePickerState.hour.toString().padStart(2, '0')
                                val mm = timePickerState.minute.toString().padStart(2, '0')
                                selectedDueTime = "$hh:$mm"
                                showTimePicker = false
                            }
                        ) {
                            Text("OK", color = ArcTheme.colors.accent, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}
