import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/widgets/top_bar.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/widgets/habit_editor_sheet.dart';
import 'package:arc/providers/global_providers.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedAnalyticsGoalType = 'Daily';

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
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      builder: (context) => HabitEditorSheet(habitToEdit: habit),
    );
  }

  List<DateTime> _getLast7Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  bool _isHabitCompletedInPeriod(Habit habit, List<HabitEntry> entries, String goalType) {
    if (goalType == 'Daily') {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      return entries.any((e) => e.habitId == habit.id && e.dateStr == todayStr && e.completed);
    } else if (goalType == 'Weekly') {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek = DateTime(monday.year, monday.month, monday.day);
      return entries.any((e) {
        if (e.habitId != habit.id || !e.completed) return false;
        try {
          final date = DateTime.parse(e.dateStr);
          return date.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
        } catch (_) {
          return false;
        }
      });
    } else {
      // Monthly
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      return entries.any((e) {
        if (e.habitId != habit.id || !e.completed) return false;
        try {
          final date = DateTime.parse(e.dateStr);
          return date.isAfter(startOfMonth.subtract(const Duration(seconds: 1)));
        } catch (_) {
          return false;
        }
      });
    }
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

    // Analytics Calculations (Filtered by Selected Dropdown Type)
    final filteredHabits = habits.where((h) => h.goalType == _selectedAnalyticsGoalType).toList();
    int completedCount = 0;
    for (final h in filteredHabits) {
      if (_isHabitCompletedInPeriod(h, entries, _selectedAnalyticsGoalType)) {
        completedCount++;
      }
    }
    final int remainingCount = filteredHabits.length - completedCount;
    final double completionPercent = filteredHabits.isNotEmpty 
        ? (completedCount / filteredHabits.length) 
        : 0.0;

    // Streaks for Filtered Analytics habits specifically
    int analyticsCurrentStreak = 0;
    int analyticsLongestStreak = 0;
    double analyticsRateSum = 0.0;
    for (final h in filteredHabits) {
      final m = getHabitMetrics(h.id, entries, h.createdAt);
      final c = m['currentStreak'] as int;
      final l = m['longestStreak'] as int;
      final r = m['completionRate'] as double;
      if (c > analyticsCurrentStreak) analyticsCurrentStreak = c;
      if (l > analyticsLongestStreak) analyticsLongestStreak = l;
      analyticsRateSum += r;
    }
    final double avgAnalyticsRate = filteredHabits.isNotEmpty 
        ? analyticsRateSum / filteredHabits.length 
        : 0.0;

    return Scaffold(
      appBar: const CustomTopBar(title: 'Habit Tracker'),
      body: Column(
        children: [
          // Custom TabBar inside main body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: AppColors.textPrimaryLight,
                unselectedLabelColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Check-in'),
                  Tab(text: 'Analytics'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ------------------ CHECK-IN VIEW ------------------
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

                // ------------------ ANALYTICS VIEW ------------------
                SingleChildScrollView(
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
                                child: filteredHabits.isEmpty
                                    ? Center(
                                        child: Text(
                                          "No $_selectedAnalyticsGoalType Habits",
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
                                                  color: Colors.white,
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
                          _buildSmallMetricCard(context, 'Total Habits', '${filteredHabits.length}', AppColors.info),
                        ],
                      ).animate().fade(delay: 100.ms, duration: 250.ms),
                      const SizedBox(height: 80),
                    ],
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
