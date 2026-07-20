import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/widgets/top_bar.dart';
import 'package:arc/providers/global_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Read live data from Providers
    final dashboardData = ref.watch(dashboardProvider);
    final completedTasks = dashboardData['completedTasks'] as int;
    final totalTasks = dashboardData['totalTasks'] as int;
    final completedHabits = dashboardData['completedHabits'] as int;
    final totalHabits = dashboardData['totalHabits'] as int;
    final streakDays = dashboardData['streakDays'] as int;
    
    final tasksList = ref.watch(tasksProvider);
    final pendingTasks = tasksList.where((t) => !t.completed).toList();

    // Calculate dynamic progress
    final totalItems = totalTasks + totalHabits;
    final completedItems = completedTasks + completedHabits;
    final double progressPercentage = totalItems > 0 ? completedItems / totalItems : 0.0;

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
                            "You've completed $completedTasks of $totalTasks tasks and $completedHabits of $totalHabits habits today. Keep going!",
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
                            value: progressPercentage,
                            strokeWidth: 6,
                            backgroundColor: isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                          ),
                        ),
                        Text(
                          "${(progressPercentage * 100).toInt()}%",
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
                  value: '${totalTasks - completedTasks}',
                  subtitle: 'In task manager',
                  icon: LucideIcons.checkSquare,
                  color: AppColors.info,
                ),
                // Habits Mini Card
                _buildOverviewCard(
                  context,
                  title: 'Daily Streak',
                  value: '$streakDays days',
                  subtitle: '${totalHabits - completedHabits} habits left',
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

            // Render live pending tasks in focus list, falling back to placeholders if list is empty
            if (pendingTasks.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingTasks.length > 3 ? 3 : pendingTasks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final task = pendingTasks[index];
                  
                  // Color dot matching priority
                  Color pColor = AppColors.priorityLow;
                  if (task.priority == 'High') {
                    pColor = AppColors.priorityHigh;
                  } else if (task.priority == 'Much') {
                    pColor = AppColors.priorityMuch;
                  }

                  return Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: pColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(LucideIcons.checkSquare, color: pColor, size: 20),
                      ),
                      title: Text(
                        task.title,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${task.category} • Priority: ${task.priority}',
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
              ).animate().fade(delay: 200.ms, duration: 300.ms).slideY(begin: 0.1)
            else
              // Fallback placeholder card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.clipboardCheck, color: AppColors.success, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "All Caught Up!",
                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "No pending tasks for today. Relax or plan ahead!",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                    color: color.withValues(alpha: 0.1),
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
