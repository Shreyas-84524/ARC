import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utilities/currency_formatter.dart';
import 'package:arc/features/money_tracker/providers/money_settings_provider.dart';
import 'package:arc/providers/global_providers.dart';

/// Premium, friction-free onboarding sheet for first-time Money Tracker users.
///
/// Prompts the user to set an optional baseline monthly budget and explicitly configure
/// the "Add income to Monthly budget ?" preference.
class MoneyTrackerOnboardingSheet extends ConsumerStatefulWidget {
  const MoneyTrackerOnboardingSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (ctx) => const MoneyTrackerOnboardingSheet(),
    );
  }

  @override
  ConsumerState<MoneyTrackerOnboardingSheet> createState() =>
      _MoneyTrackerOnboardingSheetState();
}

class _MoneyTrackerOnboardingSheetState
    extends ConsumerState<MoneyTrackerOnboardingSheet> {
  final TextEditingController _budgetController = TextEditingController();
  bool _addIncomeToBudget = false;

  @override
  void initState() {
    super.initState();
    final currentBudget = ref.read(monthlyBudgetProvider);
    if (currentBudget > 0) {
      _budgetController.text = currentBudget.toStringAsFixed(0);
    }
    _addIncomeToBudget = ref.read(addIncomeToBudgetProvider);
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    AppHaptics.mediumImpact();

    // 1. Save monthly budget if provided
    final rawText = _budgetController.text.trim();
    if (rawText.isNotEmpty) {
      final amount = double.tryParse(rawText);
      if (amount != null && amount >= 0) {
        await ref.read(monthlyBudgetProvider.notifier).setBudget(amount);
      }
    }

    // 2. Save "Add income to Monthly budget ?" toggle
    await ref
        .read(addIncomeToBudgetProvider.notifier)
        .setAddIncomeToBudget(_addIncomeToBudget);

    // 3. Mark onboarding as completed so it never prompts again
    await ref.read(moneyRepositoryProvider).setMoneyOnboardingCompleted(true);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSkip() async {
    AppHaptics.lightImpact();
    await ref.read(moneyRepositoryProvider).setMoneyOnboardingCompleted(true);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentMonthFormatted = DateFormat(
      'MMMM yyyy',
    ).format(DateTime.now());

    return Container(
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
            // Center drag handle
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

            // Header with badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    LucideIcons.wallet,
                    color: AppColors.accent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'WELCOME TO MONEY TRACKER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set Up Your Rhythm',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: _handleSkip,
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              'Configure your monthly baseline and customize how income interacts with your budget. Everything stays 100% private on your device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            // Section 1: Monthly Budget Limit Input
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.target,
                          color: AppColors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Monthly Budget Limit (Optional)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your baseline spending allowance for $currentMonthFormatted.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _budgetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. 2,000',
                        prefixText: '${CurrencyFormatter.symbol} ',
                        prefixStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightBgSecondary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInput,
                          ),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.borderMedium
                                : AppColors.borderMediumLight,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInput,
                          ),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.borderMedium
                                : AppColors.borderMediumLight,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInput,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.accent,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Section 2: "Add income to Monthly budget ?" Toggle
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
                          color: _addIncomeToBudget
                              ? AppColors.success.withValues(alpha: 0.15)
                              : (isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightBgSecondary),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          LucideIcons.plusCircle,
                          color: _addIncomeToBudget
                              ? AppColors.success
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
                      subtitle: Text(
                        _addIncomeToBudget
                            ? 'Yes — income increases your available budget and activates detailed analytics'
                            : 'No — budget remains fixed; income is excluded from analytics',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMutedLight,
                        ),
                      ),
                      value: _addIncomeToBudget,
                      activeThumbColor: AppColors.accent,
                      onChanged: (val) {
                        AppHaptics.selectionClick();
                        setState(() {
                          _addIncomeToBudget = val;
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _addIncomeToBudget
                              ? AppColors.success.withValues(alpha: 0.12)
                              : (isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightBgSecondary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _addIncomeToBudget
                                  ? LucideIcons.checkCircle2
                                  : LucideIcons.shield,
                              size: 14,
                              color: _addIncomeToBudget
                                  ? AppColors.success
                                  : (isDark
                                      ? AppColors.textMutedDark
                                      : AppColors.textMutedLight),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _addIncomeToBudget
                                    ? 'Income will be added to your budget & analytics'
                                    : 'Strict fixed budget • Income excluded from analytics',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _addIncomeToBudget
                                      ? AppColors.success
                                      : (isDark
                                          ? AppColors.textMutedDark
                                          : AppColors.textMutedLight),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Call to Action Buttons
            ElevatedButton(
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.arrowRight, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Save & Get Started',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Center(
              child: TextButton(
                onPressed: _handleSkip,
                child: Text(
                  'I\'ll configure this later in Settings',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
