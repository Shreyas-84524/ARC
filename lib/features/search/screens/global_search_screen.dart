import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utilities/currency_formatter.dart';
import 'package:arc/providers/global_providers.dart';
import 'package:arc/features/task_manager/widgets/task_editor_sheet.dart';
import 'package:arc/features/habit_tracker/widgets/habit_editor_sheet.dart';
import 'package:arc/features/money_tracker/widgets/transaction_editor_sheet.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tasks = ref.watch(tasksProvider);
    final habits = ref.watch(habitsProvider);
    final transactions = ref.watch(moneyProvider);

    final cleanQuery = _query.trim().toLowerCase();

    final matchedTasks = cleanQuery.isEmpty
        ? []
        : tasks.where((t) {
            return t.title.toLowerCase().contains(cleanQuery) ||
                t.description.toLowerCase().contains(cleanQuery) ||
                t.category.toLowerCase().contains(cleanQuery) ||
                t.labels.any((l) => l.toLowerCase().contains(cleanQuery));
          }).toList();

    final matchedHabits = cleanQuery.isEmpty
        ? []
        : habits.where((h) {
            return h.name.toLowerCase().contains(cleanQuery) ||
                h.category.toLowerCase().contains(cleanQuery);
          }).toList();

    final matchedTransactions = cleanQuery.isEmpty
        ? []
        : transactions.where((tx) {
            return tx.category.toLowerCase().contains(cleanQuery) ||
                tx.notes.toLowerCase().contains(cleanQuery) ||
                tx.amount.toString().contains(cleanQuery) ||
                tx.type.toLowerCase().contains(cleanQuery);
          }).toList();

    final totalMatches =
        matchedTasks.length + matchedHabits.length + matchedTransactions.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: (val) {
            setState(() {
              _query = val;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search tasks, habits, transactions...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                      });
                    },
                  )
                : null,
          ),
        ),
      ),
      body: cleanQuery.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.search,
                    size: 48,
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search across all modules',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search by title, category, notes, or tags',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            )
          : totalMatches == 0
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.fileSearch,
                        size: 48,
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No results found for "$_query"',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // Matched Tasks
                    if (matchedTasks.isNotEmpty) ...[
                      Text(
                        'Tasks (${matchedTasks.length})',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...matchedTasks.map((task) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Theme.of(context)
                                    .dialogTheme
                                    .backgroundColor,
                                builder: (context) =>
                                    TaskEditorSheet(taskToEdit: task),
                              );
                            },
                            leading: const Icon(LucideIcons.checkSquare,
                                color: AppColors.info, size: 20),
                            title: Text(
                              task.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                                '${task.category} • Priority: ${task.displayPriority}'),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Matched Habits
                    if (matchedHabits.isNotEmpty) ...[
                      Text(
                        'Habits (${matchedHabits.length})',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...matchedHabits.map((habit) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Theme.of(context)
                                    .dialogTheme
                                    .backgroundColor,
                                builder: (context) =>
                                    HabitEditorSheet(habitToEdit: habit),
                              );
                            },
                            leading: Icon(LucideIcons.zap,
                                color: Color(habit.colorValue), size: 20),
                            title: Text(
                              habit.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(habit.category),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Matched Transactions
                    if (matchedTransactions.isNotEmpty) ...[
                      Text(
                        'Transactions (${matchedTransactions.length})',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...matchedTransactions.map((tx) {
                        final isIncome = tx.type == 'Income';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Theme.of(context)
                                    .dialogTheme
                                    .backgroundColor,
                                builder: (context) =>
                                    TransactionEditorSheet(transactionToEdit: tx),
                              );
                            },
                            leading: Icon(
                              isIncome
                                  ? LucideIcons.trendingUp
                                  : LucideIcons.trendingDown,
                              color: isIncome
                                  ? AppColors.success
                                  : AppColors.danger,
                              size: 20,
                            ),
                            title: Text(
                              tx.category,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              tx.notes.isNotEmpty
                                  ? tx.notes
                                  : DateFormat('MMM d, yyyy').format(tx.date),
                            ),
                            trailing: Text(
                              '${isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isIncome
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
    );
  }
}
