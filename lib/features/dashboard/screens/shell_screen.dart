import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';

/// ShellScreen wraps all tab-navigated screens and provides the floating
/// bottom navigation pill. It uses GoRouter.of(context) to read the current
/// route location so that the correct tab is highlighted on every rebuild.
class ShellScreen extends StatelessWidget {
  final Widget child;
  final String? location;

  const ShellScreen({
    super.key,
    required this.child,
    this.location,
  });

  int _indexFromLocation(String location) {
    if (location.startsWith('/tasks')) return 1;
    if (location.startsWith('/habits')) return 2;
    if (location.startsWith('/money')) return 3;
    return 0;
  }

  void _onTabTapped(BuildContext context, int index, int currentIndex) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/tasks');
        break;
      case 2:
        context.go('/habits');
        break;
      case 3:
        context.go('/money');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String currentPath = location ??
        GoRouterState.of(context).uri.path;
    final int currentIndex = _indexFromLocation(currentPath);

    return Scaffold(
      extendBody: false,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurface
              : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.borderSubtle
                  : AppColors.borderSubtleLight,
              width: 1.0,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  context,
                  index: 0,
                  icon: LucideIcons.layoutDashboard,
                  active: currentIndex == 0,
                  onTap: () => _onTabTapped(context, 0, currentIndex),
                ),
                _buildNavItem(
                  context,
                  index: 1,
                  icon: LucideIcons.checkSquare,
                  active: currentIndex == 1,
                  onTap: () => _onTabTapped(context, 1, currentIndex),
                ),
                _buildNavItem(
                  context,
                  index: 2,
                  icon: LucideIcons.zap,
                  active: currentIndex == 2,
                  onTap: () => _onTabTapped(context, 2, currentIndex),
                ),
                _buildNavItem(
                  context,
                  index: 3,
                  icon: LucideIcons.wallet,
                  active: currentIndex == 3,
                  onTap: () => _onTabTapped(context, 3, currentIndex),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: double.infinity,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? (isDark
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : AppColors.accent)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 24,
              color: active
                  ? (isDark ? AppColors.accent : AppColors.textPrimaryLight)
                  : (isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight),
            ),
          ),
        ),
      ),
    );
  }
}
