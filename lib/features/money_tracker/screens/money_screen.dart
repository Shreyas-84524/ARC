import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/widgets/top_bar.dart';

class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomTopBar(title: 'Money Tracker'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Remaining Budget Primary Card
            Card(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                side: BorderSide(
                  color: isDark ? AppColors.borderStrong : AppColors.borderStrongLight,
                  width: 1.5,
                ),
              ),
              child: Container(
                width: double.infinity,
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
                      "\$420.50",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildBudgetStat(context, label: 'Monthly Budget', value: '\$800.00'),
                        _buildBudgetStat(context, label: 'Expenses', value: '\$450.00', isNegative: true),
                        _buildBudgetStat(context, label: 'Savings', value: '\$70.50'),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fade(duration: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Recent Transactions Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Transactions",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All', style: TextStyle(color: AppColors.accent)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Transactions List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final titles = [
                  'Salary Deposit',
                  'Grocery Shopping',
                  'Gas Station',
                  'Movie Tickets',
                ];
                final subtitles = [
                  'Salary • Jul 20, 10:00 AM',
                  'Food • Jul 19, 4:30 PM',
                  'Fuel • Jul 18, 1:15 PM',
                  'Entertainment • Jul 17, 8:00 PM',
                ];
                final amounts = [
                  '+\$300.00',
                  '-\$42.50',
                  '-\$35.00',
                  '-\$24.00',
                ];
                final isIncome = [
                  true,
                  false,
                  false,
                  false,
                ];
                final icons = [
                  LucideIcons.arrowUpRight,
                  LucideIcons.shoppingBag,
                  LucideIcons.fuel,
                  LucideIcons.film,
                ];

                return Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isIncome[index] ? AppColors.success : AppColors.danger).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icons[index],
                        color: isIncome[index] ? AppColors.success : AppColors.danger,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      titles[index],
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      subtitles[index],
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                    trailing: Text(
                      amounts[index],
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isIncome[index] ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ),
                );
              },
            ).animate().fade(delay: 150.ms, duration: 300.ms).slideY(begin: 0.08),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetStat(
    BuildContext context, {
    required String label,
    required String value,
    bool isNegative = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isNegative
                ? AppColors.danger
                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          ),
        ),
      ],
    );
  }
}
