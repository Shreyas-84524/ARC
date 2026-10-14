import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utilities/responsive_layout.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';
import 'package:arc/features/secret_notes/services/secret_notes_security_service.dart';
import 'package:arc/features/secret_notes/widgets/secret_notes_pin_field.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// All PIN setup actions are processed and stored strictly locally.

class SecretNotesSetupScreen extends ConsumerStatefulWidget {
  const SecretNotesSetupScreen({super.key});

  @override
  ConsumerState<SecretNotesSetupScreen> createState() => _SecretNotesSetupScreenState();
}

class _SecretNotesSetupScreenState extends ConsumerState<SecretNotesSetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  final FocusNode _pinFocus = FocusNode();
  final FocusNode _confirmPinFocus = FocusNode();

  String? _pinError;
  String? _confirmPinError;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _pinFocus.dispose();
    _confirmPinFocus.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    setState(() {
      _pinError = SecretNotesSecurityService.validatePin(pin);
      if (_pinError == null) {
        if (confirmPin.isEmpty) {
          _confirmPinError = 'Please confirm your PIN';
        } else if (pin != confirmPin) {
          _confirmPinError = 'PINs do not match';
        } else {
          _confirmPinError = null;
        }
      } else {
        _confirmPinError = null;
      }
    });

    if (_pinError != null || _confirmPinError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final securityService = ref.read(secretNotesSecurityServiceProvider);
      final success = await securityService.setupPin(pin);

      if (success) {
        ref.read(secretNotesConfiguredProvider.notifier).setConfigured(true);
        ref.read(secretNotesSessionProvider.notifier).unlock();

        if (mounted) {
          final router = GoRouter.maybeOf(context);
          if (router != null) {
            router.go('/secret-notes');
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save Secret PIN. Please try again.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _exitToTasks() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/tasks');
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _exitToTasks();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Secret Notes'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: _exitToTasks,
          ),
        ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.horizontalPadding(context),
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.lock,
                        color: AppColors.accent,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create Secret PIN',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set a 6-digit numeric PIN to protect your private notes. This PIN is stored only on this device.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SecretNotesPinField(
                    controller: _pinController,
                    focusNode: _pinFocus,
                    autofocus: true,
                    label: 'Create Secret PIN',
                    errorText: _pinError,
                    onChanged: (val) {
                      if (_pinError != null) {
                        setState(() => _pinError = null);
                      }
                    },
                    onSubmitted: (_) {
                      _confirmPinFocus.requestFocus();
                    },
                  ),
                  const SizedBox(height: 20),
                  SecretNotesPinField(
                    controller: _confirmPinController,
                    focusNode: _confirmPinFocus,
                    label: 'Confirm Secret PIN',
                    errorText: _confirmPinError,
                    onChanged: (val) {
                      if (_confirmPinError != null) {
                        setState(() => _confirmPinError = null);
                      }
                    },
                    onSubmitted: (_) => _handleContinue(),
                  ),
                  const SizedBox(height: 36),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.textPrimaryLight,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _handleContinue,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimaryLight,
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
