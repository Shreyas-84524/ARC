import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:arc/core/theme/app_theme.dart';

/// Accessible and interactive 1–5 star rating input with visual feedback.
class StarRatingInput extends StatelessWidget {
  final int? rating;
  final ValueChanged<int?> onRatingChanged;
  final bool isRequired;

  const StarRatingInput({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.isRequired = false,
  });

  String _getRatingLabel(int? stars) {
    switch (stars) {
      case 1:
        return '1 Star — Needs Improvement';
      case 2:
        return '2 Stars — Fair';
      case 3:
        return '3 Stars — Good';
      case 4:
        return '4 Stars — Very Good';
      case 5:
        return '5 Stars — Excellent!';
      default:
        return isRequired ? 'Tap a star to rate (Required)' : 'Tap a star to rate (Optional)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const starActiveColor = Color(0xFFFFC857);
    final starInactiveColor = isDark ? const Color(0xFF404040) : const Color(0xFFE5E7EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starNumber = index + 1;
            final isFilled = rating != null && rating! >= starNumber;

            return Semantics(
              button: true,
              label: '$starNumber star${starNumber > 1 ? 's' : ''}',
              selected: isFilled,
              child: InkWell(
                onTap: () {
                  AppHaptics.selectionClick();
                  if (rating == starNumber && !isRequired) {
                    onRatingChanged(null);
                  } else {
                    onRatingChanged(starNumber);
                  }
                },
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    transform: isFilled
                        ? Matrix4.diagonal3Values(1.15, 1.15, 1.0)
                        : Matrix4.identity(),
                    child: Icon(
                      LucideIcons.star,
                      size: 36,
                      color: isFilled ? starActiveColor : starInactiveColor,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _getRatingLabel(rating),
              key: ValueKey(rating),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: rating != null ? FontWeight.bold : FontWeight.normal,
                color: rating != null
                    ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                    : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
