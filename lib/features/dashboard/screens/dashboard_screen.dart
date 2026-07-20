import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/widgets/top_bar.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/widgets/task_editor_sheet.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/widgets/habit_editor_sheet.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/widgets/transaction_editor_sheet.dart';
import 'package:arc/providers/global_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _showTaskEditor(BuildContext context, [Task? task]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      builder: (context) => TaskEditorSheet(taskToEdit: task),
    );
  }

  void _showHabitEditor(BuildContext context, [Habit? habit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      builder: (context) => HabitEditorSheet(habitToEdit: habit),
    );
  }

  void _showTransactionEditor(BuildContext context, [Transaction? tx]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      builder: (context) => TransactionEditorSheet(transactionToEdit: tx),
    );
  }

  void _showQuickAddDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Add'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.checkSquare, color: AppColors.info),
              title: const Text('Add Task'),
              onTap: () {
                Navigator.of(context).pop();
                _showTaskEditor(context);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.zap, color: AppColors.accent),
              title: const Text('Add Habit'),
              onTap: () {
                Navigator.of(context).pop();
                _showHabitEditor(context);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.wallet, color: AppColors.success),
              title: const Text('Add Transaction'),
              onTap: () {
                Navigator.of(context).pop();
                _showTransactionEditor(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Subscriptions
    final dashboardData = ref.watch(dashboardProvider);
    final completedTasks = dashboardData['completedTasks'] as int;
    final totalTasks = dashboardData['totalTasks'] as int;
    final completedHabits = dashboardData['completedHabits'] as int;
    final totalHabits = dashboardData['totalHabits'] as int;
    final remainingBudget = dashboardData['remainingBudget'] as double;
    final totalBudget = dashboardData['totalBudget'] as double;
    final streakDays = dashboardData['streakDays'] as int;

    final tasksList = ref.watch(tasksProvider);
    final habitsList = ref.watch(habitsProvider);
    final entriesList = ref.watch(habitEntriesProvider);
    final transactionsList = ref.watch(moneyProvider);
    final currentMonthStr = ref.watch(currentMonthProvider);

    // Calculate dates
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // Filter Tasks
    final todayTasks = tasksList.where((t) {
      if (t.completed) return false;
      if (t.dueDate == null) return true;
      return t.dueDate!.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
          t.dueDate!.isBefore(todayEnd.add(const Duration(seconds: 1)));
    }).toList();

    final upcomingDeadlines = tasksList.where((t) {
      if (t.completed || t.dueDate == null) return false;
      return t.dueDate!.isAfter(todayEnd);
    }).toList();

    // Filter Habits (Daily habits only for today)
    final dailyHabits = habitsList.where((h) => h.goalType == 'Daily').toList();

    // Filter & Sort Transactions
    final currentMonthTxs = transactionsList.where((tx) {
      return DateFormat('yyyy-MM').format(tx.date) == currentMonthStr;
    }).toList();
    currentMonthTxs.sort((a, b) => b.date.compareTo(a.date));
    final recentTransactions = currentMonthTxs.take(3).toList();

    // Calculate Dynamic overall progress
    final int overallTotal = totalTasks + totalHabits;
    final int overallCompleted = completedTasks + completedHabits;
    final double progressPercentage = overallTotal > 0 ? (overallCompleted / overallTotal) : 0.0;

    return Scaffold(
      appBar: const CustomTopBar(title: 'Dashboard'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Today's Progress Card
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

            // 2. Quick Statistics Grid Row
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.25,
              children: [
                _buildMetricCard(
                  context,
                  title: 'Remaining Budget',
                  value: '\$${remainingBudget.toStringAsFixed(2)}',
                  subtitle: 'Limit: \$${totalBudget.toStringAsFixed(0)}',
                  icon: LucideIcons.wallet,
                  color: remainingBudget >= 0 ? AppColors.success : AppColors.danger,
                ),
                _buildMetricCard(
                  context,
                  title: 'Daily Streak',
                  value: '$streakDays Days',
                  subtitle: 'Keep it going!',
                  icon: LucideIcons.zap,
                  color: AppColors.accent,
                ),
              ],
            ).animate().fade(delay: 100.ms, duration: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // 3. Today's Habits (Check-in Bubbles)
            if (dailyHabits.isNotEmpty) ...[
              Text(
                "Today's Habits",
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: dailyHabits.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final habit = dailyHabits[index];
                    final isCompleted = entriesList.any(
                      (e) => e.habitId == habit.id && e.dateStr == todayStr && e.completed,
                    );

                    return Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(habitEntriesProvider.notifier).toggleEntry(
                                habit.id,
                                todayStr,
                                !isCompleted,
                              );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Container(
                                height: 26,
                                width: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCompleted ? Color(habit.colorValue) : Colors.transparent,
                                  border: Border.all(
                                    color: isCompleted
                                        ? Colors.transparent
                                        : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: isCompleted
                                    ? Icon(
                                        LucideIcons.check,
                                        size: 14,
                                        color: habit.colorValue == 0xffccff00 ? Colors.black : Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    habit.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    habit.category,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ).animate().fade(delay: 150.ms, duration: 300.ms),
              const SizedBox(height: 24),
            ],

            // 4. Today's Tasks Checklist
            Text(
              "Today's Tasks",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (todayTasks.isEmpty)
              _buildCleanCard(context, 'All tasks completed for today!')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: todayTasks.length > 3 ? 3 : todayTasks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final task = todayTasks[index];
                  Color pColor = AppColors.priorityLow;
                  if (task.priority == 'High') pColor = AppColors.priorityHigh;
                  if (task.priority == 'Much') pColor = AppColors.priorityMuch;

                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      onTap: () => _showTaskEditor(context, task),
                      leading: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(tasksProvider.notifier).toggleTask(task.id);
                        },
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          height: 20,
                          width: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: pColor, width: 2),
                          ),
                        ),
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
                    ),
                  );
                },
              ).animate().fade(delay: 200.ms, duration: 300.ms),

            const SizedBox(height: 24),

            // 5. Upcoming Deadlines
            if (upcomingDeadlines.isNotEmpty) ...[
              Text(
                "Upcoming Deadlines",
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: upcomingDeadlines.length > 2 ? 2 : upcomingDeadlines.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final task = upcomingDeadlines[index];
                  final daysLeft = task.dueDate!.difference(todayStart).inDays;

                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      onTap: () => _showTaskEditor(context, task),
                      leading: const Icon(LucideIcons.calendar, color: AppColors.accent, size: 20),
                      title: Text(
                        task.title,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Due in $daysLeft day${daysLeft > 1 ? 's' : ''} (${DateFormat('MMM d').format(task.dueDate!)})',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                      ),
                    ),
                  );
                },
              ).animate().fade(delay: 250.ms, duration: 300.ms),
              const SizedBox(height: 24),
            ],

            // 6. Recent Transactions
            Text(
              "Recent Transactions",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (recentTransactions.isEmpty)
              _buildCleanCard(context, 'No transactions logged this month.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentTransactions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final tx = recentTransactions[index];
                  final isIncome = tx.type == 'Income';

                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      onTap: () => _showTransactionEditor(context, tx),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isIncome ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isIncome ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                          color: isIncome ? AppColors.success : AppColors.danger,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        tx.category,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        tx.notes.isNotEmpty ? tx.notes : DateFormat('MMM d').format(tx.date),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                      ),
                      trailing: Text(
                        '${isIncome ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isIncome ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ),
                  );
                },
              ).animate().fade(delay: 300.ms, duration: 300.ms),
            
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimaryLight,
        shape: const CircleBorder(),
        elevation: 6,
        onPressed: () => _showQuickAddDialog(context),
        child: const Icon(LucideIcons.plus, size: 24),
      ).animate().scale(delay: 200.ms, duration: 250.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildCleanCard(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        alignment: Alignment.center,
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
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
      margin: EdgeInsets.zero,
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
