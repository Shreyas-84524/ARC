import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// All dialogs and acknowledgements are strictly local.

class SecretNotesIntroDialog extends ConsumerWidget {
  const SecretNotesIntroDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          side: BorderSide(
            color: isDark ? AppColors.borderStrong : AppColors.borderMediumLight,
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                LucideIcons.shieldCheck,
                color: AppColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Secret Notes',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to your private vault. Please review the essential rules:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),
              _buildPoint(
                context,
                index: '1',
                title: 'Local only',
                description:
                    'Secret Notes are stored only on this device and are never synced with Firebase or ARC cloud services.',
                icon: LucideIcons.hardDrive,
              ),
              const SizedBox(height: 12),
              _buildPoint(
                context,
                index: '2',
                title: 'Separate PIN',
                description:
                    'Your Secret Notes PIN is separate from your ARC account password or Google sign-in.',
                icon: LucideIcons.keyRound,
              ),
              const SizedBox(height: 12),
              _buildPoint(
                context,
                index: '3',
                title: 'Independent settings',
                description:
                    'Secret Notes will have their own settings, separate from ARC\'s global settings.',
                icon: LucideIcons.sliders,
              ),
              const SizedBox(height: 12),
              _buildPoint(
                context,
                index: '4',
                title: 'Possible permanent loss',
                description:
                    'Clearing app data, uninstalling ARC, or permanently deleting Secret Notes may permanently remove these notes.',
                icon: LucideIcons.alertTriangle,
              ),
              const SizedBox(height: 12),
              _buildPoint(
                context,
                index: '5',
                title: 'Keep your PIN safe',
                description:
                    'ARC must not store your original PIN in readable form, so the user should keep the Secret PIN safe.',
                icon: LucideIcons.lock,
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textPrimaryLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              onPressed: () async {
                final securityService = ref.read(secretNotesSecurityServiceProvider);
                await securityService.markIntroSeen();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text(
                'I Understand',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoint(
    BuildContext context, {
    required String index,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.accent,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$index. $title',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
