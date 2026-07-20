import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/widgets/top_bar.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/widgets/habit_editor_sheet.dart';
import 'package:arc/providers/global_providers.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  void _showHabitEditor(BuildContext context, [Habit? habit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      builder: (context) => HabitEditorSheet(habitToEdit: habit),
    );
  }

  List<DateTime> _getLast7Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final habits = ref.watch(habitsProvider);
    final entries = ref.watch(habitEntriesProvider);

    // 1. Calculate Overall Summary Metrics
    int maxCurrentStreak = 0;
    int maxLongestStreak = 0;
    double totalRateSum = 0.0;

    for (final h in habits) {
      final metrics = getHabitMetrics(h.id, entries, h.createdAt);
      final current = metrics['currentStreak'] as int;
      final longest = metrics['longestStreak'] as int;
      final rate = metrics['completionRate'] as double;

      if (current > maxCurrentStreak) maxCurrentStreak = current;
      if (longest > maxLongestStreak) maxLongestStreak = longest;
      totalRateSum += rate;
    }

    final double avgCompletionRate = habits.isNotEmpty ? totalRateSum / habits.length : 0.0;
    final String completionRateStr = '${(avgCompletionRate * 100).toInt()}%';

    final dates = _getLast7Days();

    return Scaffold(
      appBar: const CustomTopBar(title: 'Habit Tracker'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak Summary Cards
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      context,
                      title: 'Current Streak',
                      value: '$maxCurrentStreak Days',
                      icon: LucideIcons.zap,
                      color: AppColors.accent,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: isDark ? AppColors.borderStrong : AppColors.borderStrongLight,
                    ),
                    _buildStatColumn(
                      context,
                      title: 'Longest Streak',
                      value: '$maxLongestStreak Days',
                      icon: LucideIcons.trophy,
                      color: AppColors.warning,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: isDark ? AppColors.borderStrong : AppColors.borderStrongLight,
                    ),
                    _buildStatColumn(
                      context,
                      title: 'Completion Rate',
                      value: completionRateStr,
                      icon: LucideIcons.award,
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
            ).animate().fade(duration: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Weekly Grid Matrix Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Weekly Check-in",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Habit Matrix Table Card
            if (habits.isEmpty)
              _buildEmptyState(context)
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  child: Column(
                    children: [
                      // Header Row: Days & Date numbers
                      Row(
                        children: [
                          const Expanded(
                            flex: 3,
                            child: SizedBox(), // Space for Habit Names
                          ),
                          ...dates.map((date) {
                            final dayLabel = DateFormat('E').format(date).substring(0, 1);
                            final isToday = DateFormat('yyyy-MM-dd').format(date) ==
                                DateFormat('yyyy-MM-dd').format(DateTime.now());

                            return Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  Text(
                                    dayLabel,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isToday
                                          ? AppColors.accent
                                          : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    date.day.toString(),
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                      color: isToday
                                          ? AppColors.accent
                                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Habits Rows
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: habits.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final habit = habits[index];
                          
                          return Row(
                            children: [
                              // Column 1: Habit info (clickable to edit)
                              Expanded(
                                flex: 3,
                                child: InkWell(
                                  onTap: () => _showHabitEditor(context, habit),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            height: 8,
                                            width: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(habit.colorValue),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              habit.name,
                                              style: theme.textTheme.bodyLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${habit.category} • ${habit.goalType}',
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Columns 2-8: Date completeness Checkboxes
                              ...dates.map((date) {
                                final dateStr = DateFormat('yyyy-MM-dd').format(date);
                                final isCompleted = entries.any(
                                  (e) => e.habitId == habit.id && e.dateStr == dateStr && e.completed,
                                );

                                return Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        ref.read(habitEntriesProvider.notifier).toggleEntry(
                                              habit.id,
                                              dateStr,
                                              !isCompleted,
                                            );
                                      },
                                      borderRadius: BorderRadius.circular(100),
                                      child: Container(
                                        height: 28,
                                        width: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isCompleted
                                              ? Color(habit.colorValue)
                                              : Colors.transparent,
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
                                                color: habit.colorValue == 0xffccff00
                                                    ? Colors.black
                                                    : Colors.white,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
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
        onPressed: () => _showHabitEditor(context),
        child: const Icon(LucideIcons.plus, size: 24),
      ).animate().scale(delay: 200.ms, duration: 250.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
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
              LucideIcons.zap,
              size: 48,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No habits tracking yet. Add your first habit.",
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 46),
            ),
            onPressed: () => _showHabitEditor(context),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Add Habit'),
          ),
        ],
      ),
    ).animate().fade(duration: 200.ms);
  }

  Widget _buildStatColumn(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          ),
        ),
      ],
    );
  }
}
