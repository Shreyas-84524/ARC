import 'package:flutter/material.dart';
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
                Icons.auto_awesome,
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
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}
