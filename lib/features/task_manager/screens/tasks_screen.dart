import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/constants/app_constants.dart';
import 'package:arc/core/widgets/top_bar.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/widgets/task_editor_sheet.dart';
import 'package:arc/core/widgets/empty_state.dart';
import 'package:arc/providers/global_providers.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTaskEditor(BuildContext context, [Task? task]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
      builder: (context) => TaskEditorSheet(taskToEdit: task),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, Task task) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text(
          'Are you sure you want to delete "${task.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
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
    // Subscriptions
    final filteredTasks = ref.watch(filteredTasksProvider);
    final activeStatus = ref.watch(taskStatusFilterProvider);
    final activeDate = ref.watch(taskDateFilterProvider);
    final activeSort = ref.watch(taskSortProvider);
    final activeCategory = ref.watch(taskCategoryFilterProvider);
    final taskStats = ref.watch(taskStatisticsProvider);

    return Scaffold(
      appBar: const CustomTopBar(title: 'Task Manager'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task Statistics Strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatBadge(context, 'Total', '${taskStats['totalTasks']}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBadge(
                    context,
                    'Pending',
                    '${taskStats['pendingTasks']}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBadge(
                    context,
                    'Overdue',
                    '${taskStats['overdueTasks']}',
                    isError: (taskStats['overdueTasks'] as int) > 0,
                  ),
                ),
              ],
            ),
          ),

          // Search & Filter header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                // Live Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    ref.read(taskSearchQueryProvider.notifier).state = val;
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(taskSearchQueryProvider.notifier).state =
                                  '';
                            },
                          )
                        : null,
                    hintText: 'Search tasks...',
                  ),
                ),
                const SizedBox(height: 12),

                // Sorting and category filters row
                Row(
                  children: [
                    // Sorting Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: activeSort,
                        decoration: const InputDecoration(
                          labelText: 'Sort By',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'DueDate',
                            child: Text('Due Date'),
                          ),
                          DropdownMenuItem(
                            value: 'Priority',
                            child: Text('Priority'),
                          ),
                          DropdownMenuItem(
                            value: 'CreationDate',
                            child: Text('Creation Date'),
                          ),
                          DropdownMenuItem(
                            value: 'Alphabetical',
                            child: Text('Alphabetical'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(taskSortProvider.notifier).state = val;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Category Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: activeCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All'),
                          ),
                          ...AppConstants.taskCategories.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }),
                        ],
                        onChanged: (val) {
                          ref.read(taskCategoryFilterProvider.notifier).state =
                              val;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filters row (Status, Date range)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20),
                children: [
                  // Single-Selection Filter Control
                  _buildFilterChip(
                    context,
                    label: 'All Tasks',
                    selected: activeStatus == 'All' && activeDate == 'All',
                    onTap: () {
                      ref.read(taskStatusFilterProvider.notifier).state = 'All';
                      ref.read(taskDateFilterProvider.notifier).state = 'All';
                    },
                  ),
                  _buildFilterChip(
                    context,
                    label: 'Pending',
                    selected: activeStatus == 'Pending' && activeDate == 'All',
                    onTap: () {
                      ref.read(taskStatusFilterProvider.notifier).state = 'Pending';
                      ref.read(taskDateFilterProvider.notifier).state = 'All';
                    },
                  ),
                  _buildFilterChip(
                    context,
                    label: 'Completed',
                    selected: activeStatus == 'Completed' && activeDate == 'All',
                    onTap: () {
                      ref.read(taskStatusFilterProvider.notifier).state = 'Completed';
                      ref.read(taskDateFilterProvider.notifier).state = 'All';
                    },
                  ),
                  _buildFilterChip(
                    context,
                    label: 'Today',
                    selected: activeDate == 'Today' && activeStatus == 'All',
                    onTap: () {
                      ref.read(taskStatusFilterProvider.notifier).state = 'All';
                      ref.read(taskDateFilterProvider.notifier).state = 'Today';
                    },
                  ),
                  _buildFilterChip(
                    context,
                    label: 'Upcoming',
                    selected: activeDate == 'Upcoming' && activeStatus == 'All',
                    onTap: () {
                      ref.read(taskStatusFilterProvider.notifier).state = 'All';
                      ref.read(taskDateFilterProvider.notifier).state = 'Upcoming';
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Task List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(tasksProvider.notifier).syncTasks();
              },
              child: filteredTasks.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        _buildEmptyState(context),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        bottom: 96,
                      ),
                      itemCount: filteredTasks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return _buildTaskSlidable(context, task);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimaryLight,
        shape: const CircleBorder(),
        elevation: 6,
        onPressed: () => _showTaskEditor(context),
        child: const Icon(LucideIcons.plus, size: 24),
      ).animate().scale(delay: 200.ms, duration: 250.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyStateWidget(
      icon: LucideIcons.clipboardList,
      title: 'No tasks found',
      description:
          'Add your first task to stay organized and boost productivity.',
      actionLabel: 'Create Task',
      onAction: () => _showTaskEditor(context),
    );
  }

  Widget _buildTaskSlidable(BuildContext context, Task task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Choose priority color
    Color priorityColor = AppColors.priorityLow;
    if (task.priority == 'High') {
      priorityColor = AppColors.priorityHigh;
    } else if (task.priority == 'Much') {
      priorityColor = AppColors.priorityMuch;
    }

    return Slidable(
      key: ValueKey(task.id),
      // Left side swipe (complete/undo)
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) {
              HapticFeedback.lightImpact();
              ref.read(tasksProvider.notifier).toggleTask(task.id);
            },
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.textPrimaryLight,
            icon: task.completed ? LucideIcons.rotateCcw : LucideIcons.check,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
        ],
      ),
      // Right side swipe (delete)
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) async {
              final confirm = await _showDeleteConfirmation(context, task);
              if (confirm == true) {
                ref.read(tasksProvider.notifier).deleteTask(task.id);
              }
            },
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: LucideIcons.trash2,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
        ],
      ),
      child: AnimatedOpacity(
        opacity: task.completed ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Card(
          child: InkWell(
            onTap: () => _showTaskEditor(context, task),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Priority circle dot / Checkbox indicator
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(tasksProvider.notifier).toggleTask(task.id);
                      },
                      borderRadius: BorderRadius.circular(100),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 22,
                        width: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: task.completed
                              ? priorityColor
                              : Colors.transparent,
                          border: Border.all(color: priorityColor, width: 2.0),
                        ),
                        alignment: Alignment.center,
                        child: task.completed
                            ? const Icon(
                                LucideIcons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                // Task Content details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: task.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.completed
                              ? (isDark
                                    ? AppColors.textDisabledDark
                                    : AppColors.textDisabledLight)
                              : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMutedLight,
                                decoration: task.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // Details row (Date, Category tags)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (task.dueDate != null) ...[
                            Icon(
                              LucideIcons.calendar,
                              size: 14,
                              color: isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMutedLight,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              DateFormat('MMM d').format(task.dueDate!) +
                                  (task.dueTime != null
                                      ? ', ${task.dueTime}'
                                      : ''),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: isDark
                                        ? AppColors.textMutedDark
                                        : AppColors.textMutedLight,
                                  ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark
                                  ? AppColors.darkBgSecondary
                                  : AppColors.lightBgSecondary),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.borderSubtle
                                    : AppColors.borderSubtleLight,
                              ),
                            ),
                            child: Text(
                              task.category,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          for (final label in task.labels)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentGlow,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$label',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: isDark
                                          ? AppColors.accent
                                          : AppColors.accentPressed,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ).animate().fade(duration: 200.ms);
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (val) => onTap(),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        selectedColor: AppColors.accent,
        checkmarkColor: AppColors.textPrimaryLight,
        labelStyle: TextStyle(
          color: selected
              ? AppColors.textPrimaryLight
              : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? AppColors.accent
                : (isDark
                      ? AppColors.borderSubtle
                      : AppColors.borderSubtleLight),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(
    BuildContext context,
    String label,
    String value, {
    bool isError = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.danger.withValues(alpha: 0.1)
            : (isDark ? AppColors.darkCard : AppColors.lightCard),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? AppColors.danger
              : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isError
                  ? AppColors.danger
                  : (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark
                  ? AppColors.textMutedDark
                  : AppColors.textMutedLight,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
