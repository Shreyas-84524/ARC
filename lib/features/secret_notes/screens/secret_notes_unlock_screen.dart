import 'dart:async';
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
// All unlock attempts and throttling are evaluated strictly locally.

class SecretNotesUnlockScreen extends ConsumerStatefulWidget {
  const SecretNotesUnlockScreen({super.key});

  @override
  ConsumerState<SecretNotesUnlockScreen> createState() => _SecretNotesUnlockScreenState();
}

class _SecretNotesUnlockScreenState extends ConsumerState<SecretNotesUnlockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();

  String? _errorMessage;
  bool _isLoading = false;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  bool _canUseBiometrics = false;
  bool _biometricAuthInProgress = false;
  bool _hasAuthenticated = false;
  bool _autoBiometricsAttempted = false;

  @override
  void initState() {
    super.initState();
    _checkInitialLockout();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final securityService = ref.read(secretNotesSecurityServiceProvider);
    final isBioPrefEnabled = await securityService.isBiometricEnabled();
    if (!isBioPrefEnabled) return;

    final bioService = ref.read(secretNotesBiometricServiceProvider);
    final available = await bioService.isBiometricAvailable();
    if (mounted) {
      setState(() {
        _canUseBiometrics = available;
      });
      // Prompt on screen open if not locked out, not already attempted, and not authenticated
      if (available && _lockoutSeconds == 0 && !_autoBiometricsAttempted && !_hasAuthenticated) {
        _autoBiometricsAttempted = true;
        attemptBiometricUnlock();
      }
    }
  }

  /// Authoritative method for biometric authentication.
  /// Guarded against duplicate simultaneous calls, post-auth re-entrance, and active lockouts.
  Future<void> attemptBiometricUnlock() async {
    if (_biometricAuthInProgress || _hasAuthenticated || _isLoading || _lockoutSeconds > 0) {
      return;
    }

    _biometricAuthInProgress = true;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bioService = ref.read(secretNotesBiometricServiceProvider);
      final success = await bioService.authenticate(
        reason: 'Authenticate to unlock your Secret Notes',
      );

      if (success) {
        _hasAuthenticated = true;
        ref.read(secretNotesSessionProvider.notifier).unlock();
        if (mounted) {
          final router = GoRouter.maybeOf(context);
          if (router != null) {
            router.go('/secret-notes');
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      }
      // If user cancels or biometric fails, DO NOT increment failed attempts or lock out.
      // Simply allow user to retry biometrics or enter their PIN.
    } catch (e) {
      debugPrint('Biometric unlock attempt cancelled or failed: $e');
    } finally {
      _biometricAuthInProgress = false;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialLockout() async {
    final securityService = ref.read(secretNotesSecurityServiceProvider);
    final remaining = await securityService.getLockoutRemainingSeconds();
    if (remaining > 0) {
      _startLockoutTimer(remaining);
    }
  }

  void _startLockoutTimer(int seconds) {
    _lockoutTimer?.cancel();
    setState(() {
      _lockoutSeconds = seconds;
      _errorMessage = 'Too many failed attempts. Try again in $_lockoutSeconds seconds.';
    });

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_lockoutSeconds <= 1) {
          _lockoutSeconds = 0;
          _errorMessage = null;
          timer.cancel();
        } else {
          _lockoutSeconds--;
          _errorMessage = 'Too many failed attempts. Try again in $_lockoutSeconds seconds.';
        }
      });
    });
  }

  Future<void> _handleUnlock() async {
    if (_isLoading || _lockoutSeconds > 0) return;

    final pin = _pinController.text.trim();
    final validationError = SecretNotesSecurityService.validatePin(pin);
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final securityService = ref.read(secretNotesSecurityServiceProvider);
      final isUnlocked = await securityService.verifyPin(pin);

      if (isUnlocked) {
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
        final remainingLockout = await securityService.getLockoutRemainingSeconds();
        if (remainingLockout > 0) {
          _startLockoutTimer(remainingLockout);
        } else {
          setState(() {
            _errorMessage = 'Incorrect PIN.';
            _pinController.clear();
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unlock failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _exitToTasks() {
    ref.read(secretNotesSessionProvider.notifier).lock();
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
    final isLocked = _lockoutSeconds > 0;
    final pinLength = _pinController.text.length;
    final isUnlockEnabled =
        pinLength >= 3 && pinLength <= 6 && !_isLoading && !isLocked;

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
                        color: isLocked
                            ? AppColors.danger.withValues(alpha: 0.15)
                            : AppColors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isLocked ? LucideIcons.shieldAlert : LucideIcons.lock,
                        color: isLocked ? AppColors.danger : AppColors.accent,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Enter Secret PIN',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your Secret PIN to unlock your private space.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SecretNotesPinField(
                    controller: _pinController,
                    focusNode: _pinFocus,
                    autofocus: !isLocked,
                    label: 'Secret PIN',
                    errorText: _errorMessage,
                    onChanged: (val) {
                      setState(() {
                        if (_errorMessage != null && !isLocked) {
                          _errorMessage = null;
                        }
                      });
                    },
                    onSubmitted: (_) => isUnlockEnabled ? _handleUnlock() : null,
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
                    onPressed: isUnlockEnabled ? _handleUnlock : null,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimaryLight,
                            ),
                          )
                        : Text(
                            isLocked ? 'Locked ($_lockoutSeconds s)' : 'Unlock',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  if (_canUseBiometrics && !isLocked) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                        ),
                      ),
                      onPressed: (_isLoading || _biometricAuthInProgress || _hasAuthenticated)
                          ? null
                          : attemptBiometricUnlock,
                      icon: const Icon(LucideIcons.fingerprint, size: 20),
                      label: const Text(
                        'Unlock with Biometrics',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
