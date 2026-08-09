import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utilities/currency_formatter.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/providers/global_providers.dart';

class TransactionEditorSheet extends ConsumerStatefulWidget {
  final Transaction? transactionToEdit;

  const TransactionEditorSheet({
    super.key,
    this.transactionToEdit,
  });

  @override
  ConsumerState<TransactionEditorSheet> createState() => _TransactionEditorSheetState();
}

class _TransactionEditorSheetState extends ConsumerState<TransactionEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountController;
  late TextEditingController _notesController;

  String _selectedType = 'Expense';
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final List<String> _incomeCategories = ['Salary', 'Freelancing', 'Investment', 'Gift', 'Other'];
  final List<String> _expenseCategories = ['Food', 'Travel', 'Shopping', 'Fuel', 'Bills', 'Entertainment', 'Health', 'Education', 'Other'];

  @override
  void initState() {
    super.initState();
    final editTx = widget.transactionToEdit;

    _amountController = TextEditingController(text: editTx != null ? editTx.amount.toString() : '');
    _notesController = TextEditingController(text: editTx?.notes ?? '');
    _selectedType = editTx?.type ?? 'Expense';
    _selectedCategory = editTx?.category ?? (_selectedType == 'Income' ? 'Salary' : 'Food');
    _selectedDate = editTx?.date ?? DateTime.now();

    if (editTx?.time != null) {
      final parts = editTx!.time.split(':');
      if (parts.length == 2) {
        _selectedTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveForm() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());

    final hour = _selectedTime.hour.toString().padLeft(2, '0');
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';

    final id = widget.transactionToEdit?.id ?? const Uuid().v4();
    final now = DateTime.now();

    final tx = Transaction(
      id: id,
      amount: amount,
      type: _selectedType,
      category: _selectedCategory,
      date: _selectedDate,
      time: timeStr,
      notes: _notesController.text.trim(),
      createdAt: widget.transactionToEdit?.createdAt ?? now,
    );

    HapticFeedback.mediumImpact();
    if (widget.transactionToEdit == null) {
      ref.read(moneyProvider.notifier).addTransaction(tx);
    } else {
      ref.read(moneyProvider.notifier).updateTransaction(tx);
    }

    Navigator.of(context).pop();
  }

  Future<void> _deleteTransaction() async {
    if (widget.transactionToEdit != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Transaction'),
          content: Text('Are you sure you want to delete this ${widget.transactionToEdit!.type.toLowerCase()} of ${CurrencyFormatter.format(widget.transactionToEdit!.amount)}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 40),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        ref.read(moneyProvider.notifier).deleteTransaction(widget.transactionToEdit!.id);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categories = _selectedType == 'Income' ? _incomeCategories : _expenseCategories;

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
                    widget.transactionToEdit == null ? 'Add Transaction' : 'Edit Transaction',
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

              // Transaction Type Toggle (Income / Expense)
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Expense')),
                      selected: _selectedType == 'Expense',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedType = 'Expense';
                            _selectedCategory = 'Food';
                          });
                        }
                      },
                      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      selectedColor: AppColors.danger,
                      labelStyle: TextStyle(
                        color: _selectedType == 'Expense' ? Colors.white : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Income')),
                      selected: _selectedType == 'Income',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedType = 'Income';
                            _selectedCategory = 'Salary';
                          });
                        }
                      },
                      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      selectedColor: AppColors.success,
                      labelStyle: TextStyle(
                        color: _selectedType == 'Income' ? Colors.white : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixText: '${CurrencyFormatter.symbol} ',
                  labelText: 'Amount',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(val.trim()) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(val.trim()) <= 0) {
                    return 'Amount must be greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category selector dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                items: categories.map((c) {
                  return DropdownMenuItem<String>(
                    value: c,
                    child: Text(c, style: theme.textTheme.bodyMedium),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),

              // Date & Time pickers
              Row(
                children: [
                  // Date Picker
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
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
                                DateFormat('MMM d, yyyy').format(_selectedDate),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
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
                      onTap: () => _selectTime(context),
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
                                _selectedTime.format(context),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
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
              const SizedBox(height: 16),

              // Notes field
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Enter tags or notes...',
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons (Save & optional Delete)
              Row(
                children: [
                  if (widget.transactionToEdit != null) ...[
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _deleteTransaction,
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
                        widget.transactionToEdit == null ? 'Add Transaction' : 'Save Changes',
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
