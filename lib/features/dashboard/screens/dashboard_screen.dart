import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/widgets/top_bar.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomTopBar(title: 'Dashboard'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Progress Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Progress",
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "You've completed 3 of 5 tasks and 2 of 4 habits today. Keep going!",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Circular Progress Ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 64,
                          width: 64,
                          child: CircularProgressIndicator(
                            value: 0.6,
                            strokeWidth: 6,
                            backgroundColor: isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                          ),
                        ),
                        Text(
                          "60%",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fade(duration: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Modules Quick Overview Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                // Tasks Mini Card
                _buildOverviewCard(
                  context,
                  title: 'Pending Tasks',
                  value: '2',
                  subtitle: 'Due today',
                  icon: LucideIcons.checkSquare,
                  color: AppColors.info,
                ),
                // Habits Mini Card
                _buildOverviewCard(
                  context,
                  title: 'Daily Streak',
                  value: '8 days',
                  subtitle: '2 habits left',
                  icon: LucideIcons.zap,
                  color: AppColors.accent,
                ),
                // Budget remaining Card
                _buildOverviewCard(
                  context,
                  title: 'Remaining Budget',
                  value: '\$420.50',
                  subtitle: '84% of monthly limit',
                  icon: LucideIcons.wallet,
                  color: AppColors.success,
                ),
                // Savings Card
                _buildOverviewCard(
                  context,
                  title: 'This Month Savings',
                  value: '\$180.00',
                  subtitle: 'Saved so far',
                  icon: LucideIcons.piggyBank,
                  color: AppColors.warning,
                ),
              ],
            ).animate().fade(delay: 100.ms, duration: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Today's Focus Section
            Text(
              "Today's Focus",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Placeholder Focus List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final titles = [
                  'Finish Arc Project Architecture Setup',
                  'Drink 3L of Water',
                  'Log Lunch Expenses',
                ];
                final subtitles = [
                  'Task Manager • High Priority',
                  'Habits • Daily Routine',
                  'Money Tracker • Dining Out',
                ];
                final icons = [
                  LucideIcons.checkSquare,
                  LucideIcons.zap,
                  LucideIcons.wallet,
                ];
                final colors = [
                  AppColors.priorityHigh,
                  AppColors.accent,
                  AppColors.danger,
                ];

                return Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors[index].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icons[index], color: colors[index], size: 20),
                    ),
                    title: Text(
                      titles[index],
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      subtitles[index],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                );
              },
            ).animate().fade(delay: 200.ms, duration: 300.ms).slideY(begin: 0.1),
            
            const SizedBox(height: 80), // Navigation spacing
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
