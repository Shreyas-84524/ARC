import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utilities/responsive_layout.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';
import 'package:arc/features/secret_notes/services/secret_notes_security_service.dart';
import 'package:arc/features/secret_notes/widgets/secret_notes_pin_field.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// This settings screen manages only local PIN verifiers, local biometrics, and local storage.
// It is strictly isolated from ARC's global settings.

class SecretNotesSettingsScreen extends ConsumerStatefulWidget {
  const SecretNotesSettingsScreen({super.key});

  @override
  ConsumerState<SecretNotesSettingsScreen> createState() =>
      _SecretNotesSettingsScreenState();
}

class _SecretNotesSettingsScreenState
    extends ConsumerState<SecretNotesSettingsScreen> {
  bool _isHardwareBiometricAvailable = false;
  bool _isCheckingHardware = true;

  @override
  void initState() {
    super.initState();
    _checkHardwareBiometrics();
  }

  Future<void> _checkHardwareBiometrics() async {
    final bioService = ref.read(secretNotesBiometricServiceProvider);
    final available = await bioService.isBiometricAvailable();
    if (mounted) {
      setState(() {
        _isHardwareBiometricAvailable = available;
        _isCheckingHardware = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Change Secret PIN Dialog Flow
  // ---------------------------------------------------------------------------
  Future<void> _openChangePinDialog() async {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String? dialogError;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              title: Row(
                children: const [
                  Icon(LucideIcons.keyRound, color: AppColors.accent, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Change Secret PIN',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (dialogError != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dialogError!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        SecretNotesPinField(
                          controller: currentPinController,
                          label: 'Current PIN',
                          onChanged: (_) {
                            setDialogState(() {
                              if (dialogError != null) dialogError = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        SecretNotesPinField(
                          controller: newPinController,
                          label: 'New PIN (3–6 Digits)',
                          onChanged: (_) {
                            setDialogState(() {
                              if (dialogError != null) dialogError = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        SecretNotesPinField(
                          controller: confirmPinController,
                          label: 'Confirm New PIN',
                          onChanged: (_) {
                            setDialogState(() {
                              if (dialogError != null) dialogError = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textPrimaryLight,
                  ),
                  onPressed: (isSubmitting ||
                          currentPinController.text.length < 3 ||
                          newPinController.text.length < 3 ||
                          confirmPinController.text.length < 3)
                      ? null
                      : () async {
                          final currentPin = currentPinController.text.trim();
                          final newPin = newPinController.text.trim();
                          final confirmPin = confirmPinController.text.trim();

                          final currentValError =
                              SecretNotesSecurityService.validatePin(currentPin);
                          if (currentValError != null) {
                            setDialogState(() => dialogError = 'Current PIN: $currentValError');
                            return;
                          }

                          final confirmValError =
                              SecretNotesSecurityService.validatePinConfirmation(
                            newPin,
                            confirmPin,
                          );
                          if (confirmValError != null) {
                            setDialogState(() => dialogError = confirmValError);
                            return;
                          }

                          if (newPin == currentPin) {
                            setDialogState(() => dialogError =
                                'Your new PIN must be different from your current PIN.');
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(dialogContext);
                          final secService =
                              ref.read(secretNotesSecurityServiceProvider);
                          final error = await secService.changePin(
                            currentPin: currentPin,
                            newPin: newPin,
                          );

                          if (error != null) {
                            setDialogState(() {
                              isSubmitting = false;
                              dialogError = error;
                            });
                          } else {
                            if (dialogContext.mounted) {
                              navigator.pop();
                            }
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Secret PIN changed successfully.',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: AppColors.accent,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimaryLight,
                          ),
                        )
                      : const Text('Save PIN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Biometric Toggle Handler
  // ---------------------------------------------------------------------------
  Future<void> _handleBiometricToggle(bool enable) async {
    final bioService = ref.read(secretNotesBiometricServiceProvider);
    final bioNotifier = ref.read(secretNotesBiometricEnabledProvider.notifier);

    if (enable) {
      // Must verify identity before enabling
      final success = await bioService.authenticate(
        reason: 'Verify biometric identity to enable biometric unlock for Secret Notes',
      );

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric verification cancelled or failed.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      await bioNotifier.setEnabled(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric unlock enabled.'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } else {
      await bioNotifier.setEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric unlock disabled.'),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Danger Zone: Permanently Delete Secret Notes
  // ---------------------------------------------------------------------------
  Future<void> _openPermanentDeleteDialog() async {
    final pinController = TextEditingController();
    final confirmTextController = TextEditingController();

    String? dialogError;
    bool isDeleting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isDeleting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              title: Row(
                children: const [
                  Icon(LucideIcons.alertTriangle, color: AppColors.danger, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Permanently Delete Notes?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'This action cannot be undone. All secret notes, checklist items, your Secret PIN verifier, and preferences will be permanently wiped from this device.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dialogError!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      SecretNotesPinField(
                        controller: pinController,
                        label: 'Enter your Secret PIN to authorize',
                        onChanged: (_) {
                          if (dialogError != null) {
                            setDialogState(() => dialogError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmTextController,
                        decoration: InputDecoration(
                          labelText: 'Type "DELETE" to confirm',
                          labelStyle: const TextStyle(fontSize: 13),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (_) {
                          if (dialogError != null) {
                            setDialogState(() => dialogError = null);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          final pin = pinController.text.trim();
                          final confirmText = confirmTextController.text.trim();

                          if (confirmText != 'DELETE') {
                            setDialogState(() => dialogError =
                                'Please type "DELETE" exactly to confirm.');
                            return;
                          }

                          setDialogState(() {
                            isDeleting = true;
                            dialogError = null;
                          });

                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(dialogContext);
                          final secService =
                              ref.read(secretNotesSecurityServiceProvider);
                          final isPinValid = await secService.verifyPin(pin);

                          if (!isPinValid) {
                            setDialogState(() {
                              isDeleting = false;
                              dialogError = 'Incorrect Secret PIN authorization.';
                            });
                            return;
                          }

                          // Atomic wipe: clear data repo, security repo, preferences, session, and reload
                          final dataRepo =
                              ref.read(secretNotesDataRepositoryProvider);
                          final localRepo =
                              ref.read(secretNotesLocalRepositoryProvider);

                          await dataRepo.clearAll();
                          await localRepo.clearAll();

                          ref.read(secretNotesConfiguredProvider.notifier).setConfigured(false);
                          ref.read(secretNotesSessionProvider.notifier).lock();
                          await ref.read(secretNotesListProvider.notifier).loadNotes();

                          if (dialogContext.mounted) {
                            navigator.pop();
                          }

                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Secret Notes and security configuration wiped.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                          if (context.mounted) {
                            GoRouter.maybeOf(context)?.go('/tasks');
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Permanently Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build Methods
  // ---------------------------------------------------------------------------
  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/secret-notes');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isBioEnabled = ref.watch(secretNotesBiometricEnabledProvider);
    final notesAsync = ref.watch(secretNotesListProvider);

    // Compute summary stats
    final notes = notesAsync.valueOrNull ?? [];
    final totalNotes = notes.length;
    final checklistNotes = notes.where((n) => n.checklist.isNotEmpty).length;
    final totalChecklistItems =
        notes.fold<int>(0, (sum, n) => sum + n.checklist.length);
    final completedChecklistItems = notes.fold<int>(
      0,
      (sum, n) => sum + n.checklist.where((i) => i.isCompleted).length,
    );
    final lastUpdated = notes.isNotEmpty ? notes.first.updatedAt : null;
    final lastUpdatedStr = lastUpdated != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(lastUpdated)
        : 'Never';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Secret Notes Settings'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: _handleBack,
          ),
        ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveLayout.horizontalPadding(context),
                vertical: 16,
              ),
              children: [
                // -------------------------------------------------------------
                // 1. SECURITY SECTION
                // -------------------------------------------------------------
                _buildSectionHeader('Security', LucideIcons.shield),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    side: BorderSide(
                      color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(LucideIcons.keyRound, color: AppColors.accent),
                        title: const Text(
                          'Change Secret PIN',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Update your 3–6 digit Secret Notes PIN',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(LucideIcons.chevronRight, size: 18),
                        onTap: _openChangePinDialog,
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                      ),
                      SwitchListTile(
                        secondary: const Icon(LucideIcons.fingerprint, color: AppColors.accent),
                        title: const Text(
                          'Biometric Unlock',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _isCheckingHardware
                              ? 'Checking device hardware...'
                              : _isHardwareBiometricAvailable
                                  ? 'Unlock using your fingerprint or face authentication'
                                  : 'Biometric hardware unavailable on this device or platform',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: isBioEnabled && _isHardwareBiometricAvailable,
                        onChanged: (_isHardwareBiometricAvailable && !_isCheckingHardware)
                            ? (val) => _handleBiometricToggle(val)
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // 2. SECRET NOTES SUMMARY SECTION
                // -------------------------------------------------------------
                _buildSectionHeader('Secret Notes Summary', LucideIcons.fileText),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    side: BorderSide(
                      color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSummaryRow(
                          label: 'Total Notes',
                          value: '$totalNotes',
                          icon: LucideIcons.stickyNote,
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow(
                          label: 'Checklist Notes',
                          value: '$checklistNotes',
                          icon: LucideIcons.checkSquare,
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow(
                          label: 'Checklist Items',
                          value: '$completedChecklistItems of $totalChecklistItems done',
                          icon: LucideIcons.listTodo,
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow(
                          label: 'Last Updated',
                          value: lastUpdatedStr,
                          icon: LucideIcons.clock,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: const [
                              Icon(LucideIcons.database, size: 16, color: AppColors.accent),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Storage: Isolated Local Device Only (Hive)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // 3. MANDATORY PRIVACY DISCLAIMER
                // -------------------------------------------------------------
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(
                      color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.shieldCheck,
                        size: 22,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Privacy & Local Storage Guarantee',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Secret Notes is stored entirely on this device. It is never synced to Firebase, Firestore, or cloud servers. ARC cannot recover your Secret PIN if forgotten.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // -------------------------------------------------------------
                // 4. DANGER ZONE
                // -------------------------------------------------------------
                _buildSectionHeader('Danger Zone', LucideIcons.alertTriangle, isDanger: true),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: isDark ? Colors.red.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.02),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Permanently Delete Secret Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Erase all notes, checklists, preferences, and your Secret PIN from this device. Secret Notes will return to unconfigured first-time state.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                            ),
                          ),
                          onPressed: _openPermanentDeleteDialog,
                          icon: const Icon(LucideIcons.trash2, size: 18),
                          label: const Text(
                            'Permanently Delete Secret Notes',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {bool isDanger = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDanger ? AppColors.danger : AppColors.accent,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
            color: isDanger ? AppColors.danger : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
