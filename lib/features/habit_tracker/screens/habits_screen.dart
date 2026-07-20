import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/widgets/top_bar.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomTopBar(title: 'Habit Tracker'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(context, title: 'Current Streak', value: '8 Days', icon: LucideIcons.zap, color: AppColors.accent),
                    Container(height: 40, width: 1, color: isDark ? AppColors.borderStrong : AppColors.borderStrongLight),
                    _buildStatColumn(context, title: 'Longest Streak', value: '15 Days', icon: LucideIcons.trophy, color: AppColors.warning),
                    Container(height: 40, width: 1, color: isDark ? AppColors.borderStrong : AppColors.borderStrongLight),
                    _buildStatColumn(context, title: 'Completion Rate', value: '88%', icon: LucideIcons.award, color: AppColors.success),
                  ],
                ),
              ),
            ).animate().fade(duration: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Habit Grid / Table Placeholder
            Text(
              "Weekly Check-in",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // We will draw a custom habit card list containing weekly bubbles
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final habitNames = [
                  'Read 10 Pages',
                  'Morning Meditation',
                  'Gym / Workout',
                ];
                final habitCategories = [
                  'Study',
                  'Mind',
                  'Fitness',
                ];
                final habitColors = [
                  AppColors.info,
                  AppColors.accent,
                  AppColors.warning,
                ];

                final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                // Represent completion states for this week
                final completionStates = [
                  [true, true, true, false, false, false, false],
                  [true, false, true, true, false, false, false],
                  [true, true, false, true, false, false, false],
                ];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  habitNames[index],
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  habitCategories[index],
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                LucideIcons.moreVertical,
                                size: 18,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Week Days check-in
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (dayIdx) {
                            final completed = completionStates[index][dayIdx];
                            return Column(
                              children: [
                                Text(
                                  weekDays[dayIdx],
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${habitNames[index]} day ${weekDays[dayIdx]} toggled (placeholder)')),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    height: 32,
                                    width: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: completed
                                          ? habitColors[index]
                                          : (isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary),
                                      border: Border.all(
                                        color: completed
                                            ? Colors.transparent
                                            : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight),
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: completed
                                        ? const Icon(
                                            LucideIcons.check,
                                            size: 16,
                                            color: AppColors.textPrimaryLight,
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ],
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
