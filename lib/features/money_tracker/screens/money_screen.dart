import 'package:flutter/material.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utilities/currency_formatter.dart';
import 'package:arc/core/utilities/responsive_layout.dart';
import 'package:arc/core/widgets/top_bar.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/widgets/transaction_editor_sheet.dart';
import 'package:arc/features/money_tracker/widgets/transaction_details_sheet.dart';
import 'package:arc/core/widgets/empty_state.dart';
import 'package:arc/core/widgets/premium_segmented_control.dart';
import 'package:arc/providers/global_providers.dart';
import 'package:arc/features/money_tracker/providers/money_automation_provider.dart';
import 'package:arc/features/money_tracker/widgets/automatic_spending_prompt_card.dart';
import 'package:arc/features/money_tracker/widgets/automatic_spending_info_dialog.dart';
import 'package:arc/features/money_tracker/widgets/money_tracker_settings_sheet.dart';

class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Color> _redPalette = const [
    Color(0xFFEF4444), // Bright Red
    Color(0xFFF87171), // Light Red
    Color(0xFFDC2626), // Medium Red
    Color(0xFFB91C1C), // Dark Red
    Color(0xFF991B1B), // Deep Red
    Color(0xFFE11D48), // Crimson
    Color(0xFFF43F5E), // Rose Red
    Color(0xFFFB923C), // Red-Orange
    Color(0xFF7F1D1D), // Dark Crimson
    Color(0xFFBE123C), // Burgundy
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(moneyAutomationProvider.notifier).resetVisitState();
        ref.read(moneyAutomationProvider.notifier).checkListenerHealth();
        _checkAndRecordPromptAppearance();
      }
    });
  }

  void _checkAndRecordPromptAppearance() {
    final state = ref.read(moneyAutomationProvider);
    final budget = ref.read(monthlyBudgetProvider);
    final month = ref.read(currentMonthProvider);
    if (state.shouldShowPrompt(hasMonthlyBudget: budget > 0, currentMonth: month)) {
      ref.read(moneyAutomationProvider.notifier).markPromptShown(month);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showTransactionEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
      builder: (context) => const TransactionEditorSheet(),
    );
  }

  void _showTransactionDetails(BuildContext context, Transaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
      builder: (context) => TransactionDetailsSheet(transaction: tx),
    );
  }

  Future<void> _showSetBudgetDialog(BuildContext context, double currentBudget) async {
    final controller = TextEditingController(text: currentBudget > 0 ? currentBudget.toString() : '');
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Enter monthly budget amount...',
            prefixText: '${CurrencyFormatter.symbol} ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final double? amount = double.tryParse(controller.text.trim());
              if (amount != null && amount >= 0) {
                AppHaptics.mediumImpact();
                ref.read(monthlyBudgetProvider.notifier).setBudget(amount);
                _checkAndRecordPromptAppearance();
                Navigator.of(context).pop();
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, Transaction tx) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to delete this ${tx.type.toLowerCase()} of ${CurrencyFormatter.format(tx.amount)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              AppHaptics.mediumImpact();
              Navigator.of(context).pop(true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final transactions = ref.watch(moneyProvider);
    final monthlyBudget = ref.watch(monthlyBudgetProvider);
    final currentMonthStr = ref.watch(currentMonthProvider);

    // Filter current month transactions
    final currentMonthTransactions = transactions.where((tx) {
      final txMonthStr = DateFormat('yyyy-MM').format(tx.date);
      return txMonthStr == currentMonthStr;
    }).toList();

    currentMonthTransactions.sort((a, b) => b.date.compareTo(a.date));

    // Calculate dynamic budget details
    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    Map<String, double> categoryExpenses = {};
    Map<int, double> dailySpending = {};

    for (final tx in currentMonthTransactions) {
      if (tx.type == 'Income') {
        totalIncome += tx.amount;
      } else {
        totalExpenses += tx.amount;
        // Category breakdown
        categoryExpenses[tx.category] = (categoryExpenses[tx.category] ?? 0.0) + tx.amount;
        // Daily breakdown
        final day = tx.date.day;
        dailySpending[day] = (dailySpending[day] ?? 0.0) + tx.amount;
      }
    }

    final double savings = totalIncome - totalExpenses;
    final double remainingBudget = monthlyBudget - totalExpenses;
    
    // Savings Progress calculations
    final double savingsRate = totalIncome > 0 ? (savings / totalIncome).clamp(0.0, 1.0) : 0.0;

    final automationState = ref.watch(moneyAutomationProvider);
    final hasMonthlyBudget = monthlyBudget > 0.0;
    final bool showAutomationPrompt = automationState.shouldShowPrompt(
      hasMonthlyBudget: hasMonthlyBudget,
      currentMonth: currentMonthStr,
    );

    return Scaffold(
      appBar: CustomTopBar(
        title: 'Money Tracker',
        onSettingsPressed: () => MoneyTrackerSettingsSheet.show(context),
      ),
      body: Column(
        children: [
          // Premium Segmented Control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PremiumSegmentedControl(
              controller: _tabController,
              tabs: const ['Transactions', 'Analytics'],
              icons: const [LucideIcons.arrowLeftRight, LucideIcons.pieChart],
            ),
          ),
          const SizedBox(height: 12),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ------------------ TRANSACTIONS VIEW ------------------
                RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(moneyProvider.notifier).syncTransactions();
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
                      // Automatic Spending Tracking Prompt (shown above Monthly Budget when budget exists)
                      if (showAutomationPrompt) ...[
                        AutomaticSpendingPromptCard(
                          onYes: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => const AutomaticSpendingInfoDialog(),
                            );
                            if (confirmed == true && context.mounted) {
                              await ref.read(moneyAutomationProvider.notifier).enableAutomation();
                            }
                          },
                          onNo: () {
                            ref.read(moneyAutomationProvider.notifier).dismissPromptForSession();
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Set Budget Banner
                      if (monthlyBudget == 0.0)
                        Card(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(LucideIcons.wallet, color: AppColors.accent, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Set your monthly budget for ${DateFormat('MMMM yyyy').format(DateTime.now())} to start tracking balance!",
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => _showSetBudgetDialog(context, monthlyBudget),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 44),
                                  ),
                                  child: const Text('Configure Monthly Budget'),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fade(duration: 200.ms).slideY(begin: -0.1),

                      if (monthlyBudget == 0.0) const SizedBox(height: 16),

                      // Balance card
                      Card(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                          side: BorderSide(
                            color: isDark ? AppColors.borderStrong : AppColors.borderStrongLight,
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _showSetBudgetDialog(context, monthlyBudget),
                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "REMAINING BALANCE",
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    CurrencyFormatter.format(remainingBudget),
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: remainingBudget >= 0 ? AppColors.success : AppColors.danger,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: _buildBudgetStat(
                                        context,
                                        label: 'Budget Limit',
                                        value: CurrencyFormatter.format(monthlyBudget),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildBudgetStat(
                                        context,
                                        label: 'Total Income',
                                        value: CurrencyFormatter.format(totalIncome),
                                        isIncome: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildBudgetStat(
                                        context,
                                        label: 'Total Expense',
                                        value: CurrencyFormatter.format(totalExpenses),
                                        isNegative: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fade(duration: 200.ms),

                      const SizedBox(height: 24),
                      Text(
                        "Recent Transactions",
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      // Transactions list
                      if (currentMonthTransactions.isEmpty)
                        _buildEmptyState(context)
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: currentMonthTransactions.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final tx = currentMonthTransactions[index];
                            return _buildTransactionSlidable(context, tx);
                          },
                        ).animate().fade(delay: 100.ms, duration: 300.ms).slideY(begin: 0.08),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

                // ------------------ ANALYTICS VIEW ------------------
                RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(moneyProvider.notifier).syncTransactions();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Monthly Summary Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Monthly Summary (${DateFormat('MMMM').format(DateTime.now())})",
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              _buildSummaryRow(context, 'Monthly Budget Limit', monthlyBudget, isMuted: true),
                              const SizedBox(height: 10),
                              _buildSummaryRow(context, 'Total Monthly Income', totalIncome, color: AppColors.success),
                              const SizedBox(height: 10),
                              _buildSummaryRow(context, 'Total Monthly Expenses', totalExpenses, color: AppColors.danger),
                              const SizedBox(height: 10),
                              _buildSummaryRow(context, 'Savings (Income - Expense)', savings, color: savings >= 0 ? AppColors.accent : AppColors.danger),
                              const Divider(height: 24),
                              _buildSummaryRow(context, 'Remaining Budget Balance', remainingBudget, color: remainingBudget >= 0 ? AppColors.success : AppColors.danger, isBold: true),
                            ],
                          ),
                        ),
                      ).animate().fade(duration: 200.ms),

                      const SizedBox(height: 24),

                      // 2. Savings Progress Card (Ring)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Savings Rate",
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      savings >= 0
                                          ? "You've saved ${savingsRate > 0 ? (savingsRate * 100).toInt() : 0}% of your total earnings this month."
                                          : "You are spending more than your earnings this month.",
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    height: 72,
                                    width: 72,
                                    child: CircularProgressIndicator(
                                      value: savingsRate,
                                      strokeWidth: 7,
                                      backgroundColor: isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary,
                                      valueColor: AlwaysStoppedAnimation<Color>(savings >= 0 ? AppColors.accent : AppColors.danger),
                                    ),
                                  ),
                                  Text(
                                    "${(savingsRate * 100).toInt()}%",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ).animate().fade(delay: 100.ms, duration: 250.ms),

                      const SizedBox(height: 24),

                      // 3. Income vs Expense Bar Chart
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Income vs Expense Compare",
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 160,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceEvenly,
                                    maxY: totalIncome > totalExpenses ? (totalIncome * 1.2 + 10) : (totalExpenses * 1.2 + 10),
                                    barTouchData: BarTouchData(enabled: true),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            if (value == 0) return const Text('Income', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
                                            if (value == 1) return const Text('Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                    ),
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    barGroups: [
                                      BarChartGroupData(
                                        x: 0,
                                        barRods: [
                                          BarChartRodData(
                                            toY: totalIncome,
                                            color: AppColors.success,
                                            width: 32,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          ),
                                        ],
                                      ),
                                      BarChartGroupData(
                                        x: 1,
                                        barRods: [
                                          BarChartRodData(
                                            toY: totalExpenses,
                                            color: AppColors.danger,
                                            width: 32,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fade(delay: 150.ms, duration: 250.ms),

                      const SizedBox(height: 24),

                      // 4. Monthly Budget Based Spending Donut Chart
                      Builder(
                        builder: (context) {
                          final double effectiveBudget = monthlyBudget > 0
                              ? monthlyBudget
                              : (totalExpenses > 0 ? totalExpenses : 1.0);
                          final double remainingUnspentAmount =
                              (monthlyBudget - totalExpenses)
                                  .clamp(0.0, effectiveBudget);
                          final double remainingPct =
                              (remainingUnspentAmount / effectiveBudget) * 100.0;
                          final bool isOverBudget =
                              monthlyBudget > 0 && totalExpenses > monthlyBudget;
                          final double excessAmount =
                              isOverBudget ? totalExpenses - monthlyBudget : 0.0;
                          final int budgetUsedPct = monthlyBudget > 0
                              ? ((totalExpenses / monthlyBudget) * 100.0).round()
                              : 100;

                          // Build Pie Chart Sections
                          final List<PieChartSectionData> donutSections = [];
                          if (categoryExpenses.isEmpty) {
                            donutSections.add(
                              PieChartSectionData(
                                color: AppColors.success,
                                value: 100.0,
                                title: '100%',
                                radius: 44,
                                titleStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          } else {
                            if (remainingUnspentAmount > 0) {
                              donutSections.add(
                                PieChartSectionData(
                                  color: AppColors.success,
                                  value: remainingUnspentAmount,
                                  title: remainingPct >= 5
                                      ? '${remainingPct.round()}%'
                                      : '',
                                  radius: 44,
                                  titleStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            }

                            int colorIdx = 0;
                            final categoryEntries = categoryExpenses.entries.toList();
                            for (final entry in categoryEntries) {
                              final catAmount = entry.value;
                              final color =
                                  _redPalette[colorIdx % _redPalette.length];
                              colorIdx++;

                              final double sliceValue = isOverBudget
                                  ? (catAmount / totalExpenses) * effectiveBudget
                                  : catAmount;
                              final double catPct =
                                  (catAmount / effectiveBudget) * 100.0;

                              donutSections.add(
                                PieChartSectionData(
                                  color: color,
                                  value: sliceValue,
                                  title: catPct >= 4 ? '${catPct.round()}%' : '',
                                  radius: 44,
                                  titleStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }
                          }

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Monthly Budget Spending Breakdown",
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 24),

                                  // Donut Chart with Center Text Overlay
                                  SizedBox(
                                    height: 180,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        PieChart(
                                          PieChartData(
                                            sectionsSpace: 3,
                                            centerSpaceRadius: 52,
                                            sections: donutSections,
                                          ),
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isOverBudget
                                                  ? "${CurrencyFormatter.symbol}0 Left"
                                                  : "${CurrencyFormatter.format(remainingUnspentAmount, decimalDigits: 0)} Left",
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isOverBudget
                                                    ? AppColors.danger
                                                    : (isDark
                                                        ? AppColors
                                                            .textPrimaryDark
                                                        : AppColors
                                                            .textPrimaryLight),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isOverBudget
                                                  ? "100% Used"
                                                  : "${remainingPct.round()}% Remaining",
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                color: isOverBudget
                                                    ? AppColors.danger
                                                    : AppColors.success,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Legend
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      if (remainingUnspentAmount > 0 ||
                                          categoryExpenses.isEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              height: 10,
                                              width: 10,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.success,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Remaining: ${CurrencyFormatter.format(remainingUnspentAmount, decimalDigits: 0)} (${remainingPct.round()}%)',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ...List.generate(
                                        categoryExpenses.length,
                                        (index) {
                                          final key = categoryExpenses.keys
                                              .elementAt(index);
                                          final val = categoryExpenses[key]!;
                                          final col = _redPalette[
                                              index % _redPalette.length];
                                          final pct =
                                              (val / effectiveBudget) * 100.0;
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                height: 10,
                                                width: 10,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: col,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '$key: ${CurrencyFormatter.format(val, decimalDigits: 0)} (${pct.round()}%)',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),

                                  // Overbudget Warning Card
                                  if (isOverBudget) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border:
                                            Border.all(color: AppColors.danger),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.alertTriangle,
                                            color: AppColors.danger,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '⚠️ You have exceeded your monthly budget by ${CurrencyFormatter.format(excessAmount, decimalDigits: 0)}.',
                                                  style: const TextStyle(
                                                    color: AppColors.danger,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Budget Used: $budgetUsedPct%',
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppColors.textMutedDark
                                                        : AppColors
                                                            .textMutedLight,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ).animate().fade(delay: 200.ms, duration: 250.ms),

                      const SizedBox(height: 24),

                      // 5. Monthly Spending Trend Line Chart
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Monthly Spending Trend",
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 24),
                              
                              SizedBox(
                                height: 160,
                                child: currentMonthTransactions.isEmpty
                                    ? Center(
                                        child: Text(
                                          "No transactions this month",
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                          ),
                                        ),
                                      )
                                    : LineChart(
                                        LineChartData(
                                          lineTouchData: const LineTouchData(enabled: true),
                                          gridData: const FlGridData(show: false),
                                          titlesData: FlTitlesData(
                                            show: true,
                                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                interval: 5,
                                                getTitlesWidget: (value, meta) {
                                                  return Text(
                                                    '${value.toInt()}',
                                                    style: const TextStyle(fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          borderData: FlBorderData(show: false),
                                          lineBarsData: [
                                            LineChartBarData(
                                              spots: List.generate(31, (index) {
                                                final day = index + 1;
                                                final val = dailySpending[day] ?? 0.0;
                                                return FlSpot(day.toDouble(), val);
                                              }),
                                              isCurved: true,
                                              color: AppColors.accent,
                                              barWidth: 3,
                                              isStrokeCapRound: true,
                                              dotData: const FlDotData(show: false),
                                              belowBarData: BarAreaData(
                                                show: true,
                                                color: AppColors.accent.withValues(alpha: 0.1),
                                              ),
                                            ),
                                          ],
                                        ),
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fade(delay: 250.ms, duration: 250.ms),
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
        onPressed: () => _showTransactionEditor(context),
        child: const Icon(LucideIcons.plus, size: 24),
      ).animate().scale(delay: 200.ms, duration: 250.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, double amount, {Color? color, bool isBold = false, bool isMuted = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? (isMuted 
              ? (isDark ? AppColors.textMutedDark : AppColors.textMutedLight)
              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(CurrencyFormatter.format(amount), style: style),
      ],
    );
  }

  Widget _buildTransactionSlidable(BuildContext context, Transaction tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = tx.type == 'Income';
    final Color color = isIncome ? AppColors.income : AppColors.danger;
    final bool showCategoryPrompt = tx.category == 'Uncategorized' && tx.source == 'sms_auto';
    
    final IconData icon = _getCategoryIcon(tx.category);

    return Slidable(
      key: ValueKey(tx.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) async {
              final confirm = await _showDeleteConfirmation(context, tx);
              if (confirm == true) {
                ref.read(moneyProvider.notifier).deleteTransaction(tx.id);
              }
            },
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: LucideIcons.trash2,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
        ],
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _showTransactionDetails(context, tx),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(AppTheme.radiusCard),
                bottom: Radius.circular(showCategoryPrompt ? 0 : AppTheme.radiusCard),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                tx.category,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (tx.source == 'sms_auto') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: isDark ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Auto-added',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tx.notes.isNotEmpty ? tx.notes : '${DateFormat('MMM d').format(tx.date)} at ${tx.time}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isIncome ? AppColors.income : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showCategoryPrompt)
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 14.0),
                child: InkWell(
                  onTap: () => _showCategoryPickerForTransaction(context, tx),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.tag, size: 14, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Add category to this transaction?',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPickerForTransaction(BuildContext context, Transaction tx) {
    AppHaptics.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = [
      'Food',
      'Travel',
      'Shopping',
      'Fuel',
      'Bills',
      'Entertainment',
      'Health',
      'Education',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Select Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    final catIcon = _getCategoryIcon(cat);
                    return ActionChip(
                      avatar: Icon(catIcon, size: 16, color: AppColors.accent),
                      label: Text(cat),
                      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      onPressed: () async {
                        AppHaptics.lightImpact();
                        Navigator.of(bottomSheetContext).pop();
                        final updated = tx.copyWith(category: cat);
                        await ref.read(moneyProvider.notifier).updateTransaction(updated);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return LucideIcons.utensils;
      case 'Transport':
      case 'Travel':
      case 'Fuel':
        return LucideIcons.car;
      case 'Rent':
        return LucideIcons.home;
      case 'Bills':
        return LucideIcons.fileText;
      case 'Entertainment':
        return LucideIcons.film;
      case 'Shopping':
        return LucideIcons.shoppingBag;
      case 'Salary':
        return LucideIcons.banknote;
      case 'Freelance':
      case 'Freelancing':
        return LucideIcons.laptop;
      case 'Health':
        return LucideIcons.activity;
      case 'Education':
        return LucideIcons.bookOpen;
      case 'Uncategorized':
        return LucideIcons.helpCircle;
      default:
        return LucideIcons.wallet;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyStateWidget(
      icon: LucideIcons.receipt,
      title: 'No transactions logged this month',
      description: 'Record your daily income and expenses to track your financial health.',
      actionLabel: 'Add Transaction',
      onAction: () => _showTransactionEditor(context),
    );
  }

  Widget _buildBudgetStat(
    BuildContext context, {
    required String label,
    required String value,
    bool isNegative = false,
    bool isIncome = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color valColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    if (isNegative) {
      valColor = AppColors.danger;
    } else if (isIncome) {
      valColor = AppColors.success;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: valColor,
            ),
          ),
        ),
      ],
    );
  }
}
