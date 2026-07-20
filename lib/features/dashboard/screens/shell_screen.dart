import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;

  const ShellScreen({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine current index based on route path
    final GoRouterState state = GoRouterState.of(context);
    final String location = state.uri.path;
    
    int currentIndex = 0;
    if (location.startsWith('/tasks')) {
      currentIndex = 1;
    } else if (location.startsWith('/habits')) {
      currentIndex = 2;
    } else if (location.startsWith('/money')) {
      currentIndex = 3;
    }

    void onTabTapped(int index) {
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

    return Scaffold(
      extendBody: true, // Allows child content to draw under bottom nav bar
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Hero(
            tag: 'bottom_nav_pill',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDark 
                        ? AppColors.darkSurface.withOpacity(0.85) 
                        : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: isDark 
                          ? AppColors.borderStrong 
                          : AppColors.borderStrongLight,
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(
                        context,
                        index: 0,
                        icon: LucideIcons.layoutDashboard,
                        active: currentIndex == 0,
                        onTap: () => onTabTapped(0),
                      ),
                      _buildNavItem(
                        context,
                        index: 1,
                        icon: LucideIcons.checkSquare,
                        active: currentIndex == 1,
                        onTap: () => onTabTapped(1),
                      ),
                      _buildNavItem(
                        context,
                        index: 2,
                        icon: LucideIcons.zap,
                        active: currentIndex == 2,
                        onTap: () => onTabTapped(2),
                      ),
                      _buildNavItem(
                        context,
                        index: 3,
                        icon: LucideIcons.wallet,
                        active: currentIndex == 3,
                        onTap: () => onTabTapped(3),
                      ),
                    ],
                  ),
                ),
              ),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active 
                  ? (isDark 
                      ? AppColors.accent.withOpacity(0.15) 
                      : AppColors.accentPressed.withOpacity(0.15)) 
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 24,
              color: active 
                  ? (isDark ? AppColors.accent : AppColors.accentPressed) 
                  : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
            ),
          ),
        ),
      ),
    );
  }
}
