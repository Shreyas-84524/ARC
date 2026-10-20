import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utils/greeting_utils.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';

class CustomTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool showActions;
  final bool? showDate;
  final VoidCallback? onSettingsPressed;

  const CustomTopBar({
    super.key,
    required this.title,
    this.showActions = true,
    this.showDate,
    this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shouldShowDate = showDate ?? (title == 'Dashboard');

    final userContext = ref.watch(userContextProvider);
    final username = userContext.profile?.displayName ?? userContext.profile?.username;

    final displayTitle = GreetingUtils.getGreetingTitle(
      title: title,
      username: username,
    );

    final formattedDate = DateFormat('EEE, MMM d').format(DateTime.now());

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            if (shouldShowDate) ...[
              const SizedBox(height: 2),
              Text(
                formattedDate,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
              ),
            ],
          ],
        ),
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
                onPressed: onSettingsPressed ??
                    () {
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
