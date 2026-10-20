import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/secret_notes/models/secret_note.dart';
import 'package:arc/features/secret_notes/models/secret_note_color.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// This card renders strictly local in-memory notes.

class SecretNoteCard extends StatelessWidget {
  final SecretNote note;
  final VoidCallback onTap;

  const SecretNoteCard({
    super.key,
    required this.note,
    required this.onTap,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDay = DateTime(dt.year, dt.month, dt.day);

    if (noteDay == today) {
      return DateFormat('h:mm a').format(dt);
    } else if (now.difference(dt).inDays < 7 && noteDay.isBefore(today)) {
      return DateFormat('EEE, h:mm a').format(dt);
    } else if (now.year == dt.year) {
      return DateFormat('MMM d').format(dt);
    } else {
      return DateFormat('MMM d, y').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final colorOption = SecretNoteColors.getById(note.color);
    final cardBg = colorOption.backgroundColor(isDark);
    final cardBorder = colorOption.borderColor(isDark);

    final hasTitle = note.title.trim().isNotEmpty;
    final hasDescription = note.description.trim().isNotEmpty;
    final hasChecklist = note.checklist.isNotEmpty;

    // Up to 2 preview checklist items
    final checklistPreview = hasChecklist ? note.checklist.take(2).toList() : const [];
    final extraCount = hasChecklist ? note.checklist.length - checklistPreview.length : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasTitle) ...[
                  Text(
                    note.title.trim(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasDescription || hasChecklist) const SizedBox(height: 6),
                ],
                if (hasDescription) ...[
                  Text(
                    note.description.trim(),
                    style: hasTitle
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            height: 1.35,
                          )
                        : theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                            height: 1.35,
                          ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasChecklist) const SizedBox(height: 8),
                ],
                if (hasChecklist) ...[
                  ...checklistPreview.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            item.isCompleted
                                ? LucideIcons.checkSquare
                                : LucideIcons.square,
                            size: 15,
                            color: item.isCompleted
                                ? (isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMutedLight)
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.text.trim(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: item.isCompleted
                                    ? (isDark
                                        ? AppColors.textMutedDark
                                        : AppColors.textMutedLight)
                                    : (isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight),
                                decoration: item.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (extraCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+$extraCount more items',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMutedLight,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(note.updatedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
                        fontSize: 11,
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorOption.dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
