import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/widgets/empty_state.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/providers/feedback_providers.dart';
import 'package:arc/features/feedback/utils/feedback_ui_constants.dart';

class MyFeedbackScreen extends ConsumerWidget {
  const MyFeedbackScreen({super.key});

  void _handleBack(BuildContext context) {
    AppHaptics.lightImpact();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }

  void _showCategorySelectionSheet(BuildContext context) {
    AppHaptics.lightImpact();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.borderStrong : AppColors.borderStrongLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Send Feedback',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a category to share your thoughts with our team',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),
              _CategorySelectionTile(
                icon: LucideIcons.bug,
                iconColor: AppColors.danger,
                title: 'Report a Bug',
                subtitle: 'Encountered an issue or glitch? Let us know',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/feedback/bug');
                },
              ),
              const SizedBox(height: 8),
              _CategorySelectionTile(
                icon: LucideIcons.sparkles,
                iconColor: AppColors.accent,
                title: 'Suggest a Feature',
                subtitle: 'Have an idea to make Arc better?',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/feedback/feature');
                },
              ),
              const SizedBox(height: 8),
              _CategorySelectionTile(
                icon: LucideIcons.messageSquare,
                iconColor: AppColors.info,
                title: 'General Feedback',
                subtitle: 'Share your thoughts and suggestions',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/feedback/general');
                },
              ),
              const SizedBox(height: 8),
              _CategorySelectionTile(
                icon: LucideIcons.star,
                iconColor: const Color(0xFFFFC857),
                title: 'Rate Arc',
                subtitle: 'Give us a 1–5 star rating and review',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/feedback/rate');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final feedbackAsync = ref.watch(currentUserFeedbackStreamProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            key: const Key('my_feedback_back_button'),
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => _handleBack(context),
          ),
          title: Text(
            'My Feedback',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          actions: [
            IconButton(
              key: const Key('my_feedback_add_button'),
              tooltip: 'Send New Feedback',
              icon: const Icon(LucideIcons.plusCircle),
              onPressed: () => _showCategorySelectionSheet(context),
            ),
          ],
        ),
        body: SafeArea(
          child: feedbackAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.alertTriangle, size: 48, color: AppColors.danger),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to Load Feedback',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your network connection and try again.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      key: const Key('my_feedback_retry_button'),
                      onPressed: () {
                        ref.invalidate(currentUserFeedbackStreamProvider);
                        ref.invalidate(currentUserFeedbackProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (feedbackList) {
              if (feedbackList.isEmpty) {
                return EmptyStateWidget(
                  icon: LucideIcons.inbox,
                  title: 'No Feedback Yet',
                  description:
                      'You haven’t submitted any feedback yet. Help us shape the future of Arc by sharing your thoughts or bug reports.',
                  actionLabel: 'Submit Feedback',
                  onAction: () => _showCategorySelectionSheet(context),
                );
              }

              return RefreshIndicator(
                color: AppColors.accent,
                onRefresh: () async {
                  ref.invalidate(currentUserFeedbackStreamProvider);
                  ref.invalidate(currentUserFeedbackProvider);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: feedbackList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = feedbackList[index];
                    return _FeedbackItemCard(
                      feedback: item,
                      onTap: () {
                        AppHaptics.lightImpact();
                        _showFeedbackDetailsSheet(context, item);
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showFeedbackDetailsSheet(BuildContext context, FeedbackModel feedback) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FeedbackDetailsSheet(feedback: feedback),
    );
  }
}

class _FeedbackItemCard extends StatelessWidget {
  final FeedbackModel feedback;
  final VoidCallback onTap;

  const _FeedbackItemCard({
    required this.feedback,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final catInfo = FeedbackCategoryInfo.forCategory(feedback.category);
    final moduleInfo = FeedbackModuleInfo.forModule(feedback.module);
    final dateStr = DateFormat('MMM d, y • h:mm a').format(feedback.createdAt);

    return Card(
      elevation: 0,
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: BorderSide(
          color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Category Badge + Status Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: catInfo.getColor(isDark).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          catInfo.icon,
                          size: 16,
                          color: catInfo.getColor(isDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        catInfo.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  _StatusBadge(status: feedback.status),
                ],
              ),

              const SizedBox(height: 12),

              // Message Preview
              Text(
                feedback.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),

              if (feedback.status == FeedbackStatus.acknowledged && feedback.acknowledgedAt != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.checkCircle2,
                        size: 13,
                        color: Color(0xFF5C7000),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Acknowledged on ${DateFormat('MMM d, y').format(feedback.acknowledgedAt!)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.accent : const Color(0xFF5C7000),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Footer: Module Tag + Rating + Timestamp
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      moduleInfo.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ),
                  if (feedback.rating != null) ...[
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        const Icon(LucideIcons.star, size: 14, color: Color(0xFFFFC857)),
                        const SizedBox(width: 3),
                        Text(
                          '${feedback.rating}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Text(
                    dateStr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case FeedbackStatus.submitted:
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.warning;
        label = 'Submitted';
        break;
      case FeedbackStatus.emailed:
        bg = AppColors.info.withValues(alpha: 0.15);
        fg = AppColors.info;
        label = 'Dispatched';
        break;
      case FeedbackStatus.reviewed:
        bg = const Color(0xFF8B5CF6).withValues(alpha: 0.15);
        fg = const Color(0xFFA78BFA);
        label = 'In Review';
        break;
      case FeedbackStatus.acknowledged:
        bg = AppColors.accent.withValues(alpha: 0.2);
        fg = const Color(0xFF5C7000);
        label = 'Acknowledged';
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}

class _FeedbackDetailsSheet extends StatelessWidget {
  final FeedbackModel feedback;

  const _FeedbackDetailsSheet({required this.feedback});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final catInfo = FeedbackCategoryInfo.forCategory(feedback.category);
    final moduleInfo = FeedbackModuleInfo.forModule(feedback.module);
    final fullDate = DateFormat('EEEE, MMMM d, y • h:mm a').format(feedback.createdAt);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderStrong : AppColors.borderStrongLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: catInfo.getColor(isDark).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(catInfo.icon, color: catInfo.getColor(isDark), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catInfo.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      moduleInfo.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: feedback.status),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Full Narrative
          Text(
            'Message',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(
              feedback.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),

          if (feedback.rating != null) ...[
            const SizedBox(height: 16),
            Text(
              'Rating',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  LucideIcons.star,
                  size: 20,
                  color: index < feedback.rating!
                      ? const Color(0xFFFFC857)
                      : (isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB)),
                );
              }),
            ),
          ],

          const SizedBox(height: 16),
          // Metadata
          Text(
            'Submitted On',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fullDate,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),

          if (feedback.acknowledgedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Acknowledged On',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.accent : const Color(0xFF5C7000),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  LucideIcons.checkCircle2,
                  size: 14,
                  color: isDark ? AppColors.accent : const Color(0xFF5C7000),
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, MMMM d, y • h:mm a').format(feedback.acknowledgedAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ],

          if (feedback.contactEmail != null && feedback.contactEmail!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Contact Email',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              feedback.contactEmail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.hash, size: 14, color: AppColors.textMutedDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ticket ID: ${feedback.feedbackId}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ),
                Text(
                  'v${feedback.appVersion}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySelectionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CategorySelectionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
