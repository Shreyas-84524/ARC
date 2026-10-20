import 'package:flutter/material.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:arc/core/theme/app_theme.dart';

class PremiumSegmentedControl extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;
  final List<IconData>? icons;
  final ValueChanged<int>? onTap;

  const PremiumSegmentedControl({
    super.key,
    required this.controller,
    required this.tabs,
    this.icons,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFEAEAEF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabCount = tabs.length;
          final totalWidth = constraints.maxWidth;
          final tabWidth = totalWidth / tabCount;

          return AnimatedBuilder(
            animation: controller.animation ?? controller,
            builder: (context, child) {
              final double value = controller.animation?.value ?? controller.index.toDouble();

              return Stack(
                children: [
                  // Sliding active indicator pill
                  Positioned(
                    left: (value * tabWidth).clamp(0.0, totalWidth - tabWidth),
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.35),
                            blurRadius: 12,
                            spreadRadius: -1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab Items (Icons + Text)
                  Row(
                    children: List.generate(tabCount, (index) {
                      final distance = (value - index).abs();
                      final isSelectedFraction = (1.0 - distance).clamp(0.0, 1.0);
                      final isSelected = distance < 0.5;

                      final unselectedTextColor = isDark 
                          ? AppColors.textSecondaryDark 
                          : AppColors.textSecondaryLight;
                      final selectedTextColor = AppColors.textPrimaryLight;

                      final currentColor = Color.lerp(
                        unselectedTextColor,
                        selectedTextColor,
                        isSelectedFraction,
                      )!;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            AppHaptics.selectionClick();
                            controller.animateTo(index);
                            if (onTap != null) onTap!(index);
                          },
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (icons != null && index < icons!.length) ...[
                                    Icon(
                                      icons![index],
                                      size: 16,
                                      color: currentColor,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    tabs[index],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      color: currentColor,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
