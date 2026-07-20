import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/widgets/top_bar.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomTopBar(title: 'Task Manager'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                hintText: 'Search tasks...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.textPlaceholderDark : AppColors.textDisabledLight,
                ),
              ),
            ).animate().fade(duration: 300.ms),

            const SizedBox(height: 16),

            // Filters horizontal list
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip(context, label: 'All', selected: true),
                  _buildFilterChip(context, label: 'Today', selected: false),
                  _buildFilterChip(context, label: 'Upcoming', selected: false),
                  _buildFilterChip(context, label: 'High Priority', selected: false),
                  _buildFilterChip(context, label: 'Completed', selected: false),
                ],
              ),
            ).animate().fade(delay: 100.ms, duration: 300.ms),

            const SizedBox(height: 24),

            // Tasks Section
            Text(
              "Active Tasks",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Task List (Placeholder Items)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final titles = [
                  'Implement Folder Structure',
                  'Register App with Firebase Console',
                  'Configure Riverpod Providers',
                  'Build Notification Infrastructure',
                ];
                final dueDates = [
                  'Today, 4:00 PM',
                  'Today, 5:30 PM',
                  'Tomorrow, 10:00 AM',
                  'Tomorrow, 2:00 PM',
                ];
                final priorities = [
                  '🔴 High',
                  '🔴 High',
                  '🟠 Much',
                  '🟡 Low',
                ];
                final priorityColors = [
                  AppColors.priorityHigh,
                  AppColors.priorityHigh,
                  AppColors.priorityMuch,
                  AppColors.priorityLow,
                ];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Completion Circle
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: InkWell(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Task completion toggled (placeholder)')),
                              );
                            },
                            borderRadius: BorderRadius.circular(100),
                            child: Container(
                              height: 22,
                              width: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: priorityColors[index],
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Title and Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titles[index],
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    LucideIcons.calendar,
                                    size: 14,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    dueDates[index],
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: priorityColors[index].withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      priorities[index],
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        color: priorityColors[index],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Quick Action Menu
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
                  ),
                );
              },
            ).animate().fade(delay: 200.ms, duration: 300.ms).slideY(begin: 0.08),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (val) {},
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        selectedColor: AppColors.accent,
        checkmarkColor: AppColors.textPrimaryLight,
        labelStyle: TextStyle(
          color: selected
              ? AppColors.textPrimaryLight
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.accent : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight),
          ),
        ),
      ),
    );
  }
}
