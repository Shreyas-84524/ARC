import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utilities/currency_formatter.dart';
import 'package:arc/core/utilities/responsive_layout.dart';
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
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
      builder: (context) => TaskEditorSheet(taskToEdit: task),
    );
  }

  void _showHabitEditor(BuildContext context, [Habit? habit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
      builder: (context) => HabitEditorSheet(habitToEdit: habit),
    );
  }

  void _showTransactionEditor(BuildContext context, [Transaction? tx]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
      builder: (context) => TransactionEditorSheet(transactionToEdit: tx),
    );
  }

  Future<void> _showSetBudgetDialog(BuildContext context, WidgetRef ref, double currentBudget) async {
    final controller = TextEditingController(
        text: currentBudget > 0 ? currentBudget.toString() : '');
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Enter monthly budget amount...',
            prefixText: '${CurrencyFormatter.symbol} ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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
            onPressed: () {
              final double? amount = double.tryParse(controller.text.trim());
              if (amount != null && amount >= 0) {
                HapticFeedback.mediumImpact();
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

  void _showQuickAddDialog(BuildContext context, WidgetRef ref, double currentBudget) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.checkSquare, color: AppColors.info),
              title: const Text('Create Task'),
              onTap: () {
                Navigator.of(context).pop();
                _showTaskEditor(context);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.zap, color: AppColors.accent),
              title: const Text('Create Habit'),
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
            ListTile(
              leading: const Icon(LucideIcons.dollarSign, color: AppColors.warning),
              title: const Text('Update Monthly Budget'),
              onTap: () {
                Navigator.of(context).pop();
                _showSetBudgetDialog(context, ref, currentBudget);
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
    final remainingBudget = (dashboardData['remainingBudget'] as double?) ?? 0.0;
    final totalBudget = (dashboardData['totalBudget'] as double?) ?? 0.0;
    final streakDays = (dashboardData['streakDays'] as int?) ?? 0;

    final todayIncome = (dashboardData['todayIncome'] as double?) ?? 0.0;
    final todayExpenses = (dashboardData['todayExpenses'] as double?) ?? 0.0;
    final monthlySavings = (dashboardData['monthlySavings'] as double?) ?? 0.0;
    final todayScore = (dashboardData['todayProductivityScore'] as int?) ?? 0;

    final List recentActivities =
        (dashboardData['recentActivities'] as List?) ?? [];

    final tasksList = ref.watch(tasksProvider);
    final habitsList = ref.watch(habitsProvider);
    final entriesList = ref.watch(habitEntriesProvider);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final todayTasks = tasksList.where((t) {
      if (t.dueDate == null) return true;
      return t.dueDate!.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
          t.dueDate!.isBefore(todayEnd.add(const Duration(seconds: 1)));
    }).toList();

    final upcomingDeadlines = tasksList.where((t) {
      if (t.completed || t.dueDate == null) return false;
      return t.dueDate!.isAfter(todayEnd);
    }).toList();

    final totalTodayTasksCount = todayTasks.length;
    final completedTodayTasksCount =
        todayTasks.where((t) => t.completed).length.clamp(0, totalTodayTasksCount);

    final totalHabitsCount = habitsList.length;
    final completedTodayHabitsCount = entriesList
        .where((e) => e.dateStr == todayStr && e.completed)
        .length
        .clamp(0, totalHabitsCount);

    final double taskScore = totalTodayTasksCount > 0
        ? (completedTodayTasksCount / totalTodayTasksCount) * 50.0
        : 0.0;

    final double habitScore = totalHabitsCount > 0
        ? (completedTodayHabitsCount / totalHabitsCount) * 50.0
        : 0.0;

    final double finalProgressScore = (taskScore + habitScore).clamp(0.0, 100.0);
    final double progressPercentage = (finalProgressScore / 100.0).clamp(0.0, 1.0);

    return Scaffold(
      appBar: const CustomTopBar(title: 'Dashboard'),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncServiceProvider).syncAllPending();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveLayout.horizontalPadding(context),
            vertical: 16,
          ),
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
                              "Completed: $completedTodayTasksCount / $totalTodayTasksCount Tasks • $completedTodayHabitsCount / $totalHabitsCount Habits",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 64,
                            width: 64,
                            child: CircularProgressIndicator(
                              value: progressPercentage,
                              strokeWidth: 6,
                              backgroundColor: isDark
                                  ? AppColors.darkBgSecondary
                                  : AppColors.lightBgSecondary,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.accent),
                            ),
                          ),
                          Text(
                            "${finalProgressScore.round()}%",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fade(duration: 300.ms).slideY(begin: 0.1),

              const SizedBox(height: 20),

              // 2. Productivity Score Banner
              Card(
                color: AppColors.accent.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(LucideIcons.sparkles,
                                color: AppColors.accent, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Productivity Score",
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    "Based on tasks & habit completion",
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: isDark
                                          ? AppColors.textMutedDark
                                          : AppColors.textMutedLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "$todayScore / 100",
                          style: const TextStyle(
                            color: AppColors.textPrimaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade(delay: 50.ms, duration: 300.ms),

              const SizedBox(height: 20),

              // 3. Quick Statistics Grid Row
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: ResponsiveLayout.gridAspectRatio(context),
                children: [
                  _buildMetricCard(
                    context,
                    title: 'Remaining Budget',
                    value: CurrencyFormatter.format(remainingBudget),
                    subtitle: 'Limit: ${CurrencyFormatter.format(totalBudget, decimalDigits: 0)}',
                    icon: LucideIcons.wallet,
                    color: remainingBudget >= 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Daily Streak',
                    value: '$streakDays Days',
                    subtitle: 'Keep it going!',
                    icon: LucideIcons.zap,
                    color: AppColors.accent,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Today Expenses',
                    value: CurrencyFormatter.format(todayExpenses),
                    subtitle: 'Income: ${CurrencyFormatter.format(todayIncome)}',
                    icon: LucideIcons.trendingDown,
                    color: AppColors.danger,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Monthly Savings',
                    value: CurrencyFormatter.format(monthlySavings),
                    subtitle: 'Savings Net',
                    icon: LucideIcons.piggyBank,
                    color: monthlySavings >= 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ],
              ).animate().fade(delay: 100.ms, duration: 300.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // 4. Today's Habits
              if (habitsList.isNotEmpty) ...[
                Text(
                  "Today's Habits",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: habitsList.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final habit = habitsList[index];
                      final isCompleted = entriesList.any(
                        (e) =>
                            e.habitId == habit.id &&
                            e.dateStr == todayStr &&
                            e.completed,
                      );

                      return Card(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(habitEntriesProvider.notifier)
                                .toggleEntry(
                                  habit.id,
                                  todayStr,
                                  !isCompleted,
                                );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              children: [
                                Container(
                                  height: 26,
                                  width: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCompleted
                                        ? Color(habit.colorValue)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isCompleted
                                          ? Colors.transparent
                                          : (isDark
                                              ? AppColors.borderSubtle
                                              : AppColors.borderSubtleLight),
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: isCompleted
                                      ? Icon(
                                          LucideIcons.check,
                                          size: 14,
                                          color: habit.colorValue == 0xffccff00
                                              ? Colors.black
                                              : Colors.white,
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
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      habit.category,
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        color: isDark
                                            ? AppColors.textMutedDark
                                            : AppColors.textMutedLight,
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

              // 5. Today's Tasks Checklist
              Text(
                "Today's Tasks",
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (todayTasks.isEmpty)
                _buildCleanCard(context, 'All tasks completed for today!')
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: todayTasks.length > 3 ? 3 : todayTasks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = todayTasks[index];
                    Color pColor = AppColors.priorityLow;
                    if (task.priority == 'High') pColor = AppColors.priorityHigh;
                    if (task.priority == 'Much' || task.priority == 'Must') pColor = AppColors.priorityMust;

                    return AnimatedOpacity(
                      opacity: task.completed ? 0.6 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          onTap: () => _showTaskEditor(context, task),
                          leading: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(tasksProvider.notifier).toggleTask(task.id);
                            },
                            borderRadius: BorderRadius.circular(100),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 20,
                              width: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: task.completed ? pColor : Colors.transparent,
                                border: Border.all(color: pColor, width: 2),
                              ),
                              alignment: Alignment.center,
                              child: task.completed
                                  ? const Icon(
                                      LucideIcons.check,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          title: Text(
                            task.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: task.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.completed
                                  ? (isDark
                                      ? AppColors.textDisabledDark
                                      : AppColors.textDisabledLight)
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            '${task.category} • Priority: ${task.displayPriority}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMutedLight,
                              decoration: task.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ).animate().fade(delay: 200.ms, duration: 300.ms),

              const SizedBox(height: 24),

              // 6. Upcoming Deadlines
              if (upcomingDeadlines.isNotEmpty) ...[
                Text(
                  "Upcoming Deadlines",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upcomingDeadlines.length > 2
                      ? 2
                      : upcomingDeadlines.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = upcomingDeadlines[index];
                    final daysLeft =
                        task.dueDate!.difference(todayStart).inDays;

                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        onTap: () => _showTaskEditor(context, task),
                        leading: const Icon(LucideIcons.calendar,
                            color: AppColors.accent, size: 20),
                        title: Text(
                          task.title,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Due in $daysLeft day${daysLeft > 1 ? 's' : ''} (${DateFormat('MMM d').format(task.dueDate!)})',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.textMutedDark
                                : AppColors.textMutedLight,
                          ),
                        ),
                      ),
                    );
                  },
                ).animate().fade(delay: 250.ms, duration: 300.ms),
                const SizedBox(height: 24),
              ],

              // 7. Recent Activity (Top 10 Feed)
              Text(
                "Recent Activity",
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (recentActivities.isEmpty)
                _buildCleanCard(context, 'No recent activity recorded yet.')
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentActivities.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final act = recentActivities[index];
                    final type = act['type'] as String;
                    final title = act['title'] as String;
                    final subtitle = act['subtitle'] as String;
                    final timestamp = act['timestamp'] as DateTime;

                    IconData icon = LucideIcons.activity;
                    Color color = AppColors.accent;

                    if (type == 'task') {
                      icon = LucideIcons.checkSquare;
                      color = AppColors.info;
                    } else if (type == 'habit') {
                      icon = LucideIcons.zap;
                      color = AppColors.accent;
                    } else if (type == 'money') {
                      icon = LucideIcons.wallet;
                      color = (act['isIncome'] ?? false)
                          ? AppColors.success
                          : AppColors.danger;
                    }

                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        title: Text(
                          title,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '$subtitle • ${DateFormat('MMM d, h:mm a').format(timestamp)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.textMutedDark
                                : AppColors.textMutedLight,
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
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimaryLight,
        shape: const CircleBorder(),
        elevation: 6,
        onPressed: () => _showQuickAddDialog(context, ref, totalBudget),
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
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
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
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
