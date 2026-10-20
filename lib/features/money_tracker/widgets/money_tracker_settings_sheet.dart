import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:arc/features/money_tracker/models/money_automation_listener_status.dart';
import 'package:arc/features/money_tracker/providers/money_automation_provider.dart';
import 'package:arc/features/money_tracker/widgets/automatic_spending_info_dialog.dart';

class MoneyTrackerSettingsSheet extends ConsumerWidget {
  const MoneyTrackerSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const MoneyTrackerSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final automationState = ref.watch(moneyAutomationProvider);
    final status = automationState.listenerStatus;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkModal : AppColors.lightModal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderStrong : AppColors.borderStrongLight,
            width: 1.5,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.settings,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Money Tracker Settings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Local Preferences & Automation',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Automatic Spending Tracking Card
          Card(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              side: BorderSide(
                color: isDark ? AppColors.borderStrong : AppColors.borderStrongLight,
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(LucideIcons.sparkles, color: AppColors.accent),
                    title: const Text(
                      'Automatic Spending Tracking',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Detect confirmed spendings locally from notifications',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                    value: automationState.isEnabled,
                    activeThumbColor: AppColors.accent,
                    onChanged: (val) async {
                      AppHaptics.lightImpact();
                      if (val) {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => const AutomaticSpendingInfoDialog(),
                        );
                        if (confirmed == true) {
                          await ref.read(moneyAutomationProvider.notifier).enableAutomation();
                        }
                      } else {
                        await ref.read(moneyAutomationProvider.notifier).disableAutomation();
                      }
                    },
                  ),

                  // Status indicator row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          'Status: ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                        ),
                        _buildStatusBadge(context, status),
                        const Spacer(),
                        if (status == MoneyAutomationListenerStatus.permissionRequired)
                          TextButton(
                            onPressed: () {
                              AppHaptics.mediumImpact();
                              ref.read(moneyAutomationProvider.notifier).requestPermissionAgain();
                            },
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            child: const Text('Enable Access'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Privacy note
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preferences are strictly stored locally on this device and are never synced to the cloud.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, MoneyAutomationListenerStatus status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case MoneyAutomationListenerStatus.ready:
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        icon = LucideIcons.checkCircle2;
        break;
      case MoneyAutomationListenerStatus.permissionRequired:
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.warning;
        icon = LucideIcons.alertCircle;
        break;
      case MoneyAutomationListenerStatus.unavailable:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey;
        icon = LucideIcons.ban;
        break;
      case MoneyAutomationListenerStatus.error:
        bg = AppColors.danger.withValues(alpha: 0.15);
        fg = AppColors.danger;
        icon = LucideIcons.alertTriangle;
        break;
      case MoneyAutomationListenerStatus.disabled:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey;
        icon = LucideIcons.power;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
