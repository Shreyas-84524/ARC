import 'package:flutter/material.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/providers/global_providers.dart';

class HabitEditorSheet extends ConsumerStatefulWidget {
  final Habit? habitToEdit;

  const HabitEditorSheet({
    super.key,
    this.habitToEdit,
  });

  @override
  ConsumerState<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends ConsumerState<HabitEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _categoryController;

  int _selectedColorValue = 0xffccff00; // Default to accent color
  TimeOfDay? _selectedReminderTime;

  final List<int> _presetColors = [
    0xffef4444, // Red
    0xfff97316, // Orange
    0xffeab308, // Yellow
    0xffD7FF2F, // Default Green (Neon Lime)
    0xff3b82f6, // Blue
    0xffa855f7, // Purple
    0xffccff00, // Lime (Accent)
  ];

  @override
  void initState() {
    super.initState();
    final editHabit = widget.habitToEdit;

    _nameController = TextEditingController(text: editHabit?.name ?? '');
    _categoryController = TextEditingController(text: editHabit?.category ?? 'Health');
    _selectedColorValue = editHabit?.colorValue ?? 0xffccff00;

    if (editHabit?.reminderTime != null) {
      final parts = editHabit!.reminderTime!.split(':');
      if (parts.length == 2) {
        _selectedReminderTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _selectReminderTime(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedReminderTime ?? TimeOfDay.now(),
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
    if (picked != null && picked != _selectedReminderTime) {
      setState(() {
        _selectedReminderTime = picked;
      });
    }
  }

  void _saveForm() {
    if (!_formKey.currentState!.validate()) return;

    String? timeString;
    if (_selectedReminderTime != null) {
      final hour = _selectedReminderTime!.hour.toString().padLeft(2, '0');
      final minute = _selectedReminderTime!.minute.toString().padLeft(2, '0');
      timeString = '$hour:$minute';
    }

    final id = widget.habitToEdit?.id ?? const Uuid().v4();
    final now = DateTime.now();

    final habit = Habit(
      id: id,
      name: _nameController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? 'Other' : _categoryController.text.trim(),
      colorValue: _selectedColorValue,
      reminderTime: timeString,
      createdAt: widget.habitToEdit?.createdAt ?? now,
      updatedAt: now,
    );

    if (widget.habitToEdit == null) {
      ref.read(habitsProvider.notifier).addHabit(habit);
    } else {
      ref.read(habitsProvider.notifier).updateHabit(habit);
    }

    Navigator.of(context).pop();
  }

  Future<void> _deleteHabit() async {
    if (widget.habitToEdit != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Habit'),
          content: Text('Are you sure you want to delete "${widget.habitToEdit!.name}"? This will also remove all check-in history for this habit.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 40),
              ),
              onPressed: () {
                AppHaptics.mediumImpact();
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        ref.read(habitsProvider.notifier).deleteHabit(widget.habitToEdit!.id);
        Navigator.of(context).pop();
      }
    }
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
                    widget.habitToEdit == null ? 'Create Habit' : 'Edit Habit',
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

              // Name Field
              TextFormField(
                controller: _nameController,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'Habit Name',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Name cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Field
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g., Mind, Fitness',
                ),
              ),
              const SizedBox(height: 16),

              // Color Preset Picker
              Text(
                'Color Tag',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presetColors.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final colorVal = _presetColors[index];
                    final isSelected = colorVal == _selectedColorValue;
                    return InkWell(
                      onTap: () => setState(() => _selectedColorValue = colorVal),
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(colorVal),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Color(colorVal).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: isSelected
                            ? Icon(
                                LucideIcons.check,
                                size: 16,
                                color: colorVal == 0xffccff00 ? Colors.black : Colors.white,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Reminder Time picker
              InkWell(
                onTap: () => _selectReminderTime(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.bell, size: 18, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedReminderTime == null
                              ? 'Set Daily Reminder Time (Optional)'
                              : 'Reminder scheduled for ${_selectedReminderTime!.format(context)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _selectedReminderTime == null
                                ? (isDark ? AppColors.textPlaceholderDark : AppColors.textDisabledLight)
                                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                          ),
                        ),
                      ),
                      if (_selectedReminderTime != null)
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _selectedReminderTime = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons (Save & optional Delete)
              Row(
                children: [
                  if (widget.habitToEdit != null) ...[
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _deleteHabit,
                        icon: const Icon(LucideIcons.trash2, size: 18),
                        label: const Text('Delete'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saveForm,
                      child: Text(
                        widget.habitToEdit == null ? 'Create Habit' : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
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
