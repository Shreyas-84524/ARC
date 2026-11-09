import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:arc/core/notifications/notification_controller.dart';
import 'package:arc/core/notifications/notification_models.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:arc/core/theme/app_theme.dart';

String notificationErrorMessage(String error) {
  final normalized = error.toLowerCase();
  if (normalized.contains('typetoken') ||
      normalized.contains('loadschedulednotifications') ||
      normalized.contains('pendingnotificationrequests')) {
    return 'Scheduled reminders could not be read. Update the app and try again.';
  }
  return 'Reminder status is temporarily unavailable. Pull down to retry.';
}

/// Shows the coordinator's expected/pending notification state.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(notificationControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: isDark ? AppColors.darkElevated : Colors.white,
              onRefresh: () => ref
                  .read(notificationControllerProvider.notifier)
                  .refreshPermissionState(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  if (health.desiredNotifications.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 64),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.bellOff,
                              size: 48,
                              color: isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMutedLight,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No reminders scheduled',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMutedLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...health.desiredNotifications.map(
                      (spec) => _NotificationTile(spec: spec),
                    ),
                ],
              ),
            ),
          ),
          // Clear Notifications button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(LucideIcons.bellOff, size: 18),
                label: const Text(
                  'Clear Notifications',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                onPressed: () async {
                  AppHaptics.mediumImpact();
                  await ref
                      .read(notificationControllerProvider.notifier)
                      .handleLogout();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(LucideIcons.checkCircle2,
                                size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Text('All notifications cleared'),
                          ],
                        ),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final ArcNotificationSpec spec;

  const _NotificationTile({required this.spec});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final icon = switch (spec.type) {
      ArcNotificationType.taskReminder => LucideIcons.clock,
      ArcNotificationType.taskDeadline => LucideIcons.checkSquare,
      ArcNotificationType.habitReminder => LucideIcons.zap,
      ArcNotificationType.habitPending => LucideIcons.zap,
      ArcNotificationType.habitEveningCheckIn => LucideIcons.bell,
      ArcNotificationType.moneyDaily => LucideIcons.wallet,
      ArcNotificationType.feedbackAcknowledged => LucideIcons.messageSquare,
    };

    final timeStr = DateFormat('h:mm a').format(spec.scheduledAt);
    final dateStr = DateFormat('MMM d, y').format(spec.scheduledAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top header row: Time on top left, Date on top right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeStr,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              Text(
                dateStr,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Content row with Icon, Title, and Message Body
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    if (spec.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        spec.body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
