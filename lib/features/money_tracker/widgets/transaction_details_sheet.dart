import 'package:flutter/material.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utilities/currency_formatter.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/providers/global_providers.dart';

class TransactionDetailsSheet extends ConsumerWidget {
  final Transaction transaction;

  const TransactionDetailsSheet({
    super.key,
    required this.transaction,
  });

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return LucideIcons.utensils;
      case 'Transport':
      case 'Fuel':
      case 'Travel':
        return LucideIcons.car;
      case 'Rent':
        return LucideIcons.home;
      case 'Bills':
        return LucideIcons.fileText;
      case 'Entertainment':
        return LucideIcons.film;
      case 'Shopping':
        return LucideIcons.shoppingBag;
      case 'Salary':
        return LucideIcons.banknote;
      case 'Freelance':
      case 'Freelancing':
        return LucideIcons.laptop;
      case 'Investment':
        return LucideIcons.trendingUp;
      case 'Gift':
        return LucideIcons.gift;
      case 'Health':
        return LucideIcons.activity;
      case 'Education':
        return LucideIcons.bookOpen;
      default:
        return LucideIcons.wallet;
    }
  }

  Future<void> _deleteTransaction(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete this ${transaction.type.toLowerCase()} of ${CurrencyFormatter.format(transaction.amount)}?',
        ),
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

    if (confirm == true && context.mounted) {
      ref.read(moneyProvider.notifier).deleteTransaction(transaction.id);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIncome = transaction.type == 'Income';
    final Color typeColor = isIncome ? AppColors.income : AppColors.danger;
    final IconData icon = _getCategoryIcon(transaction.category);

    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightBgSecondary;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: typeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.category,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          transaction.type,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Amount Display
          Center(
            child: Column(
              children: [
                Text(
                  '${isIncome ? '+' : '-'}${CurrencyFormatter.format(transaction.amount)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isIncome ? 'Income Added' : 'Expense Recorded',
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Details Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            ),
            child: Column(
              children: [
                // Date & Time Row
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 18, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Text(
                      'Date & Time',
                      style: TextStyle(fontSize: 14, color: secondaryTextColor),
                    ),
                    const Spacer(),
                    Text(
                      '${DateFormat('MMM d, yyyy').format(transaction.date)} at ${transaction.time}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                if (transaction.notes.isNotEmpty) ...[
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.fileText, size: 18, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Text(
                        'Notes',
                        style: TextStyle(fontSize: 14, color: secondaryTextColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          transaction.notes,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 14,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Delete Button Action
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                ),
                elevation: 0,
              ),
              onPressed: () => _deleteTransaction(context, ref),
              icon: const Icon(LucideIcons.trash2, size: 18),
              label: const Text(
                'Delete Transaction',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
