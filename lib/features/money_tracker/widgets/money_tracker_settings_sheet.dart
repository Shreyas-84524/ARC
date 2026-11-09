import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:arc/features/money_tracker/providers/money_settings_provider.dart';

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
    final addIncomeToBudget = ref.watch(addIncomeToBudgetProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkModal : AppColors.lightModal,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusCard),
          ),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.borderStrong
                  : AppColors.borderStrongLight,
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
        child: SingleChildScrollView(
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
                      'Local Preferences',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
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

          // Add income to Monthly budget Card
          Card(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              side: BorderSide(
                color: isDark
                    ? AppColors.borderStrong
                    : AppColors.borderStrongLight,
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: addIncomeToBudget
                            ? AppColors.accent.withValues(alpha: 0.15)
                            : (isDark
                                ? AppColors.darkSurface
                                : AppColors.lightBgSecondary),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        LucideIcons.plusCircle,
                        color: addIncomeToBudget
                            ? AppColors.accent
                            : (isDark
                                ? AppColors.textMutedDark
                                : AppColors.textMutedLight),
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Add income to Monthly budget ?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        addIncomeToBudget
                            ? 'Income is added to your total monthly budget and reflected in analytics.'
                            : 'Income is kept separate and will not increase your monthly budget limit or analytics summary.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMutedLight,
                          height: 1.35,
                        ),
                      ),
                    ),
                    value: addIncomeToBudget,
                    activeThumbColor: AppColors.accent,
                    onChanged: (val) async {
                      AppHaptics.lightImpact();
                      await ref
                          .read(addIncomeToBudgetProvider.notifier)
                          .setAddIncomeToBudget(val);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          'Mode: ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textMutedDark
                                : AppColors.textMutedLight,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: addIncomeToBudget
                                ? AppColors.accent.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            addIncomeToBudget
                                ? 'Included in Budget'
                                : 'Separated from Budget',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: addIncomeToBudget
                                  ? (isDark
                                      ? AppColors.accent
                                      : AppColors.darkAccent)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Privacy note
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.shieldCheck,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preferences are strictly stored locally on this device and are never synced to the cloud.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    ),
  ),
);
  }
}
