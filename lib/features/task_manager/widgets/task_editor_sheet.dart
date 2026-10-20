import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/constants/app_constants.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/providers/global_providers.dart';

class TaskEditorSheet extends ConsumerStatefulWidget {
  final Task? taskToEdit;

  const TaskEditorSheet({
    super.key,
    this.taskToEdit,
  });

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _labelsController;

  String _selectedPriority = 'Low';
  String _selectedCategory = 'Work';
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;

  @override
  void initState() {
    super.initState();
    final editTask = widget.taskToEdit;

    _titleController = TextEditingController(text: editTask?.title ?? '');
    _descController = TextEditingController(text: editTask?.description ?? '');

    String labelString = '';
    if (editTask != null && editTask.labels.isNotEmpty) {
      labelString = editTask.labels.join(', ');
    }
    _labelsController = TextEditingController(text: labelString);

    _selectedPriority = editTask?.displayPriority ?? 'Low';
    if (_selectedPriority == 'Much') _selectedPriority = 'Must';
    _selectedCategory = editTask?.category ?? 'Work';
    _selectedDueDate = editTask?.dueDate;

    if (editTask?.dueTime != null) {
      final parts = editTask!.dueTime!.split(':');
      if (parts.length == 2) {
        _selectedDueTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _labelsController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.accent,
                    onPrimary: AppColors.textPrimaryLight,
                    surface: AppColors.darkModal,
                    onSurface: AppColors.textPrimaryDark,
                  )
                : const ColorScheme.light(
                    primary: AppColors.accentPressed,
                    onPrimary: Colors.white,
                    surface: AppColors.lightModal,
                    onSurface: AppColors.textPrimaryLight,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDueDate) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  Future<void> _selectDueTime(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedDueTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.accent,
                    onPrimary: AppColors.textPrimaryLight,
                    surface: AppColors.darkModal,
                    onSurface: AppColors.textPrimaryDark,
                  )
                : const ColorScheme.light(
                    primary: AppColors.accentPressed,
                    onPrimary: Colors.white,
                    surface: AppColors.lightModal,
                    onSurface: AppColors.textPrimaryLight,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDueTime) {
      setState(() {
        _selectedDueTime = picked;
      });
    }
  }

  void _saveForm() {
    if (!_formKey.currentState!.validate()) return;

    final labels = _labelsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.length <= 30)
        .take(10)
        .toList();

    String? timeString;
    DateTime? reminderDateTime;

    if (_selectedDueDate != null) {
      if (_selectedDueTime != null) {
        final hour = _selectedDueTime!.hour.toString().padLeft(2, '0');
        final minute = _selectedDueTime!.minute.toString().padLeft(2, '0');
        timeString = '$hour:$minute';
        reminderDateTime = DateTime(
          _selectedDueDate!.year,
          _selectedDueDate!.month,
          _selectedDueDate!.day,
          _selectedDueTime!.hour,
          _selectedDueTime!.minute,
        );
      } else {
        reminderDateTime = DateTime(
          _selectedDueDate!.year,
          _selectedDueDate!.month,
          _selectedDueDate!.day,
          9,
          0,
        );
      }
    }

    final id = widget.taskToEdit?.id ?? const Uuid().v4();
    final now = DateTime.now();

    final task = Task(
      id: id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      priority: _selectedPriority,
      category: _selectedCategory,
      labels: labels,
      dueDate: _selectedDueDate,
      dueTime: timeString,
      reminder: reminderDateTime,
      completed: widget.taskToEdit?.completed ?? false,
      createdAt: widget.taskToEdit?.createdAt ?? now,
      updatedAt: now,
    );

    if (widget.taskToEdit == null) {
      ref.read(tasksProvider.notifier).addTask(task);
    } else {
      ref.read(tasksProvider.notifier).updateTask(task);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.taskToEdit == null ? 'Create Task' : 'Edit Task',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title Field
              TextFormField(
                controller: _titleController,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'Task Title',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Title cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Description Field
              TextFormField(
                controller: _descController,
                minLines: 2,
                maxLines: 4,
                style: theme.textTheme.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Description',
                ),
              ),
              const SizedBox(height: 16),

              // Category, Priority dropdowns
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      items: AppConstants.taskCategories.map((c) {
                        return DropdownMenuItem<String>(
                          value: c,
                          child: Text(c, style: theme.textTheme.bodyMedium),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPriority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      items: ['High', 'Must', 'Low'].map((p) {
                        return DropdownMenuItem<String>(
                          value: p,
                          child: Row(
                            children: [
                              Text(p == 'High' ? '🔴' : (p == 'Must' ? '🟠' : '🟡')),
                              const SizedBox(width: 6),
                              Text(p, style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPriority = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Labels field
              TextFormField(
                controller: _labelsController,
                decoration: const InputDecoration(
                  hintText: 'Labels (comma separated, e.g., work, urgent)',
                  prefixIcon: Icon(LucideIcons.tag, size: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Due Date & Due Time triggers
              Row(
                children: [
                  // Date Picker
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDueDate(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
                          borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.calendar, size: 18, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedDueDate == null
                                    ? 'Set Date'
                                    : DateFormat('MMM d, yyyy').format(_selectedDueDate!),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _selectedDueDate == null
                                      ? (isDark ? AppColors.textPlaceholderDark : AppColors.textDisabledLight)
                                      : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                  fontWeight: _selectedDueDate == null ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Time Picker
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDueTime(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
                          borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.clock, size: 18, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedDueTime == null
                                    ? 'Set Time'
                                    : _selectedDueTime!.format(context),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _selectedDueTime == null
                                      ? (isDark ? AppColors.textPlaceholderDark : AppColors.textDisabledLight)
                                      : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                  fontWeight: _selectedDueTime == null ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _saveForm,
                child: Text(
                  widget.taskToEdit == null ? 'Create Task' : 'Save Changes',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
}
