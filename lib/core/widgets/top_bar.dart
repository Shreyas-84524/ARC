import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:arc/core/theme/app_theme.dart';

class CustomTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showActions;

  const CustomTopBar({
    super.key,
    required this.title,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final hour = DateTime.now().hour;
    String greeting = "Hello";
    if (hour < 12) {
      greeting = "Good Morning";
    } else if (hour < 17) {
      greeting = "Good Afternoon";
    } else {
      greeting = "Good Evening";
    }

    final formattedDate = DateFormat('EEE, MMM d').format(DateTime.now());

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title == 'Dashboard' ? '$greeting, User' : title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formattedDate,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
        ],
      ),
      actions: showActions
          ? [
              IconButton(
                icon: Icon(
                  LucideIcons.bell,
                  size: 20,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                onPressed: () {
                  context.push('/notifications');
                },
              ),
              IconButton(
                icon: Icon(
                  LucideIcons.settings,
                  size: 20,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                onPressed: () {
                  context.push('/settings');
                },
              ),
              const SizedBox(width: 12),
            ]
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
}
