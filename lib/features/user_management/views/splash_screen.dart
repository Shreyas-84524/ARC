import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                LucideIcons.sparkles,
                size: 40,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ARC',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 4.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'TRACK. GROW. ACHIEVE.',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
