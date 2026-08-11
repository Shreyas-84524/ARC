import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utilities/responsive_layout.dart';
import 'package:arc/core/widgets/top_bar.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/widgets/habit_editor_sheet.dart';
import 'package:arc/core/widgets/empty_state.dart';
import 'package:arc/core/widgets/premium_segmented_control.dart';
import 'package:arc/providers/global_providers.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedAnalyticsGoalType = 'Daily';
  String _selectedIndividualFilter = 'Weekly';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showHabitEditor(BuildContext context, [Habit? habit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
      builder: (context) => HabitEditorSheet(habitToEdit: habit),
    );
  }

  List<DateTime> _getLast7Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final habits = ref.watch(habitsProvider);
    final entries = ref.watch(habitEntriesProvider);

    // Summary Metrics (All Habits)
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

    // Analytics Calculations (Based on Daily Completion History for All Habits)
    int completedCount = 0;
    int remainingCount = 0;
    double completionPercent = 0.0;

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    if (_selectedAnalyticsGoalType == 'Daily') {
      completedCount = entries.where((e) => e.dateStr == todayStr && e.completed).length;
      remainingCount = (habits.length - completedCount).clamp(0, habits.length);
      completionPercent = habits.isNotEmpty ? completedCount / habits.length : 0.0;
    } else if (_selectedAnalyticsGoalType == 'Weekly') {
      final last7Days = _getLast7Days().map((d) => DateFormat('yyyy-MM-dd').format(d)).toSet();
      completedCount = entries.where((e) => last7Days.contains(e.dateStr) && e.completed).length;
      final totalPossible = habits.length * 7;
      remainingCount = (totalPossible - completedCount).clamp(0, totalPossible);
      completionPercent = totalPossible > 0 ? (completedCount / totalPossible).clamp(0.0, 1.0) : 0.0;
    } else {
      // Monthly
      final currentMonthStr = DateFormat('yyyy-MM').format(now);
      completedCount = entries.where((e) => e.dateStr.startsWith(currentMonthStr) && e.completed).length;
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final totalPossible = habits.length * daysInMonth;
      remainingCount = (totalPossible - completedCount).clamp(0, totalPossible);
      completionPercent = totalPossible > 0 ? (completedCount / totalPossible).clamp(0.0, 1.0) : 0.0;
    }

    int analyticsCurrentStreak = maxCurrentStreak;
    int analyticsLongestStreak = maxLongestStreak;
    double avgAnalyticsRate = avgCompletionRate;

    return Scaffold(
      appBar: const CustomTopBar(title: 'Habit Tracker'),
      body: Column(
        children: [
          // Premium Segmented Control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PremiumSegmentedControl(
              controller: _tabController,
              tabs: const ['Check-in', 'Analytics'],
              icons: const [LucideIcons.checkSquare, LucideIcons.barChart2],
            ),
          ),
          const SizedBox(height: 12),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ------------------ CHECK-IN VIEW ------------------
                RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(habitsProvider.notifier).syncHabits();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveLayout.horizontalPadding(context),
                      vertical: 12,
                    ),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview metrics
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
                      ).animate().fade(duration: 200.ms),

                      const SizedBox(height: 24),
                      Text(
                        "Weekly Check-in",
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Habits weekly matrix grid
                      if (habits.isEmpty)
                        _buildEmptyState(context)
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            child: Column(
                              children: [
                                // Header: Dates
                                Row(
                                  children: [
                                    const Expanded(flex: 3, child: SizedBox()),
                                    ..._getLast7Days().map((date) {
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

                                // Habits List Rows
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: habits.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final habit = habits[index];
                                    return Row(
                                      children: [
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
                                                   habit.category,
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
                                        ..._getLast7Days().map((date) {
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
                        ),
                    ],
                  ),
                ),
              ),

                // ------------------ ANALYTICS VIEW ------------------
                RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(habitsProvider.notifier).syncHabits();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Goal Filter Dropdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter Goal Type',
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
                              ),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedAnalyticsGoalType,
                              underline: const SizedBox(),
                              dropdownColor: isDark ? AppColors.darkModal : Colors.white,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              items: ['Daily', 'Weekly', 'Monthly'].map((g) {
                                return DropdownMenuItem<String>(
                                  value: g,
                                  child: Text(g),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedAnalyticsGoalType = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Chart Card (Pie Chart)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Text(
                                "$_selectedAnalyticsGoalType Goal Compliance",
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 24),
                              
                              // Animated Pie Chart
                              SizedBox(
                                height: 160,
                                child: habits.isEmpty
                                    ? Center(
                                        child: Text(
                                          "No Habits Created Yet",
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                          ),
                                        ),
                                      )
                                    : PieChart(
                                        PieChartData(
                                          sectionsSpace: 4,
                                          centerSpaceRadius: 40,
                                          sections: [
                                            if (completedCount > 0)
                                              PieChartSectionData(
                                                color: AppColors.success,
                                                value: completedCount.toDouble(),
                                                title: '$completedCount',
                                                radius: 46,
                                                titleStyle: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            if (remainingCount > 0)
                                              PieChartSectionData(
                                                color: isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary,
                                                value: remainingCount.toDouble(),
                                                title: '$remainingCount',
                                                radius: 36,
                                                titleStyle: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      ),
                              ),
                              const SizedBox(height: 20),

                              // Legends & Fractions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildLegendRow('Completed', completedCount, AppColors.success),
                                  _buildLegendRow('Remaining', remainingCount, isDark ? AppColors.borderStrong : AppColors.borderStrongLight),
                                  Column(
                                    children: [
                                      Text(
                                        '${(completionPercent * 100).toInt()}%',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                      const Text('Completion %', style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ).animate().fade(duration: 200.ms),

                      const SizedBox(height: 20),

                      // Streaks & metrics for selected type
                      Text(
                        "Goal Group Performance",
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          _buildSmallMetricCard(context, 'Current Streak', '$analyticsCurrentStreak Days', AppColors.accent),
                          _buildSmallMetricCard(context, 'Longest Streak', '$analyticsLongestStreak Days', AppColors.warning),
                          _buildSmallMetricCard(context, 'Completion Rate', '${(avgAnalyticsRate * 100).toInt()}%', AppColors.success),
                          _buildSmallMetricCard(context, 'Total Habits', '${habits.length}', AppColors.info),
                        ],
                      ).animate().fade(delay: 100.ms, duration: 250.ms),

                      const SizedBox(height: 24),

                      // Individual Goal Performance Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Individual Goal Performance",
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
                              ),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedIndividualFilter,
                              underline: const SizedBox(),
                              dropdownColor: isDark ? AppColors.darkModal : Colors.white,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem<String>(value: 'Weekly', child: Text('Weekly')),
                                DropdownMenuItem<String>(value: 'Monthly', child: Text('Monthly')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedIndividualFilter = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (habits.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    LucideIcons.checkSquare,
                                    size: 36,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "No habits created yet",
                                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Create habits to track individual performance.",
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fade(duration: 200.ms)
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: habits.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final habit = habits[index];
                            return _buildIndividualHabitCard(
                              context,
                              habit,
                              entries,
                              _selectedIndividualFilter,
                            );
                          },
                        ).animate().fade(delay: 100.ms, duration: 250.ms),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
              ],
            ),
          ),
        ],
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

  Widget _buildLegendRow(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          height: 12,
          width: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallMetricCard(BuildContext context, String title, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyStateWidget(
      icon: LucideIcons.zap,
      title: 'No habits tracking yet',
      description: 'Create habits to build consistent routines and track progress over time.',
      actionLabel: 'Create Habit',
      onAction: () => _showHabitEditor(context),
    );
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

    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualHabitCard(
    BuildContext context,
    Habit habit,
    List<HabitEntry> entries,
    String filterPeriod,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final metrics = getHabitMetrics(habit.id, entries, habit.createdAt);
    final currentStreak = metrics['currentStreak'] as int;
    final longestStreak = metrics['longestStreak'] as int;

    final now = DateTime.now();
    int completedCount = 0;
    int expectedCount = 0;

    if (filterPeriod == 'Weekly') {
      expectedCount = 7;
      final last7Days = _getLast7Days().map((d) => DateFormat('yyyy-MM-dd').format(d)).toSet();
      completedCount = entries
          .where((e) => e.habitId == habit.id && last7Days.contains(e.dateStr) && e.completed)
          .length;
    } else {
      // Monthly
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      expectedCount = daysInMonth;
      final currentMonthStr = DateFormat('yyyy-MM').format(now);
      completedCount = entries
          .where((e) => e.habitId == habit.id && e.dateStr.startsWith(currentMonthStr) && e.completed)
          .length;
    }

    final double completionRateVal = expectedCount > 0 ? (completedCount / expectedCount) : 0.0;
    final int completionPercentage = (completionRateVal * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Color Indicator + Name + Category Tag
            Row(
              children: [
                Container(
                  height: 10,
                  width: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(habit.colorValue),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    habit.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    habit.category,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    title: 'Current Streak',
                    value: '$currentStreak Days',
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    title: 'Longest Streak',
                    value: '$longestStreak Days',
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    title: 'Completion Rate',
                    value: '$completionPercentage%',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    title: 'Completed',
                    value: '$completedCount / $expectedCount',
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
