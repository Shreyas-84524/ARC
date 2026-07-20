import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/widgets/top_bar.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/widgets/transaction_editor_sheet.dart';
import 'package:arc/providers/global_providers.dart';

class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  void _showTransactionEditor(BuildContext context, [Transaction? tx]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      builder: (context) => TransactionEditorSheet(transactionToEdit: tx),
    );
  }

  Future<void> _showSetBudgetDialog(BuildContext context, WidgetRef ref, double currentBudget) async {
    final controller = TextEditingController(text: currentBudget > 0 ? currentBudget.toString() : '');
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Enter monthly budget amount...',
            prefixText: '\$ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final double? amount = double.tryParse(controller.text.trim());
              if (amount != null && amount >= 0) {
                ref.read(monthlyBudgetProvider.notifier).setBudget(amount);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, Transaction tx) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to delete this ${tx.type.toLowerCase()} of \$${tx.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final transactions = ref.watch(moneyProvider);
    final monthlyBudget = ref.watch(monthlyBudgetProvider);
    final currentMonthStr = ref.watch(currentMonthProvider);

    // Calculate current month's transactions, income, and expenses
    final currentMonthTransactions = transactions.where((tx) {
      final txMonthStr = DateFormat('yyyy-MM').format(tx.date);
      return txMonthStr == currentMonthStr;
    }).toList();

    currentMonthTransactions.sort((a, b) => b.date.compareTo(a.date));

    double totalIncome = 0.0;
    double totalExpenses = 0.0;

    for (final tx in currentMonthTransactions) {
      if (tx.type == 'Income') {
        totalIncome += tx.amount;
      } else {
        totalExpenses += tx.amount;
      }
    }

    final double remainingBudget = monthlyBudget + totalIncome - totalExpenses;

    return Scaffold(
      appBar: const CustomTopBar(title: 'Money Tracker'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Unset Monthly Budget Alert Banner
            if (monthlyBudget == 0.0)
              Card(
                color: AppColors.accent.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.wallet, color: AppColors.accent, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Set your monthly budget for ${DateFormat('MMMM yyyy').format(DateTime.now())} to start tracking balance!",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _showSetBudgetDialog(context, ref, monthlyBudget),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        child: const Text('Configure Monthly Budget'),
                      ),
                    ],
                  ),
                ),
              ).animate().fade(duration: 200.ms).slideY(begin: -0.1)
            else
              const SizedBox.shrink(),

            if (monthlyBudget == 0.0) const SizedBox(height: 16),

            // 2. Remaining Budget Summary Card
            Card(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                side: BorderSide(
                  color: isDark ? AppColors.borderStrong : AppColors.borderStrongLight,
                  width: 1.5,
                ),
              ),
              child: InkWell(
                onTap: () => _showSetBudgetDialog(context, ref, monthlyBudget),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "REMAINING BALANCE",
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "\$${remainingBudget.toStringAsFixed(2)}",
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: remainingBudget >= 0 ? AppColors.success : AppColors.danger,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBudgetStat(
                            context,
                            label: 'Budget Limit',
                            value: '\$${monthlyBudget.toStringAsFixed(2)}',
                          ),
                          _buildBudgetStat(
                            context,
                            label: 'Total Income',
                            value: '\$${totalIncome.toStringAsFixed(2)}',
                            isIncome: true,
                          ),
                          _buildBudgetStat(
                            context,
                            label: 'Total Expense',
                            value: '\$${totalExpenses.toStringAsFixed(2)}',
                            isNegative: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fade(duration: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // 3. Transactions Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Transactions",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4. Transactions List Card list
            if (currentMonthTransactions.isEmpty)
              _buildEmptyState(context)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentMonthTransactions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final tx = currentMonthTransactions[index];
                  
                  return _buildTransactionSlidable(context, ref, tx);
                },
              ).animate().fade(delay: 150.ms, duration: 300.ms).slideY(begin: 0.08),

            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimaryLight,
        shape: const CircleBorder(),
        elevation: 6,
        onPressed: () => _showTransactionEditor(context),
        child: const Icon(LucideIcons.plus, size: 24),
      ).animate().scale(delay: 200.ms, duration: 250.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildTransactionSlidable(BuildContext context, WidgetRef ref, Transaction tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = tx.type == 'Income';
    
    // Choose icon depending on category
    IconData icon = LucideIcons.wallet;
    Color color = AppColors.info;
    
    switch (tx.category) {
      case 'Food':
        icon = LucideIcons.utensils;
        color = AppColors.warning;
        break;
      case 'Transport':
        icon = LucideIcons.car;
        color = AppColors.info;
        break;
      case 'Rent':
        icon = LucideIcons.home;
        color = AppColors.accentPressed;
        break;
      case 'Bills':
        icon = LucideIcons.fileText;
        color = AppColors.danger;
        break;
      case 'Entertainment':
        icon = LucideIcons.film;
        color = AppColors.accent;
        break;
      case 'Shopping':
        icon = LucideIcons.shoppingBag;
        color = AppColors.priorityMuch;
        break;
      case 'Salary':
        icon = LucideIcons.banknote;
        color = AppColors.success;
        break;
      case 'Freelance':
        icon = LucideIcons.laptop;
        color = AppColors.accent;
        break;
    }

    return Slidable(
      key: ValueKey(tx.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) async {
              final confirm = await _showDeleteConfirmation(context, tx);
              if (confirm == true) {
                ref.read(moneyProvider.notifier).deleteTransaction(tx.id);
              }
            },
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: LucideIcons.trash2,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
        ],
      ),
      child: Card(
        child: InkWell(
          onTap: () => _showTransactionEditor(context, tx),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                // Category circular icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.category,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tx.notes.isNotEmpty ? tx.notes : '${DateFormat('MMM d').format(tx.date)} at ${tx.time}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Amount
                Text(
                  '${isIncome ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isIncome ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
              ),
            ),
            child: Icon(
              LucideIcons.receipt,
              size: 44,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No transactions log this month.",
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 200.ms);
  }

  Widget _buildBudgetStat(
    BuildContext context, {
    required String label,
    required String value,
    bool isNegative = false,
    bool isIncome = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color valColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    if (isNegative) {
      valColor = AppColors.danger;
    } else if (isIncome) {
      valColor = AppColors.success;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: valColor,
          ),
        ),
      ],
    );
  }
}
