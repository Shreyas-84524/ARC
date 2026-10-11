import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/user_management/services/auth_service.dart';
import 'package:arc/features/user_management/models/auth_exception.dart';

/// Professional Forgot Password Screen for Project Arc.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _emailController.removeListener(_onFieldChanged);
    _emailController.dispose();
    super.dispose();
  }

  bool get _isFormValid => _emailController.text.trim().isNotEmpty;

  Future<void> _handleSendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _emailSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is AuthException) {
            _errorMessage = e.message;
          } else {
            _errorMessage = AuthException.fromFirebase(e).message;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBgColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final buttonBgColor = AppColors.accent;
    const buttonTextColor = Colors.black;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(
                    color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                  ),
                  boxShadow: isDark
                      ? [
                          const BoxShadow(
                            color: Colors.black45,
                            blurRadius: 30,
                            offset: Offset(0, 10),
                          ),
                        ]
                      : [AppColors.cardShadowLight],
                ),
                child: _emailSent
                    ? _buildSuccessView(primaryTextColor, secondaryTextColor, buttonBgColor, buttonTextColor, isDark)
                    : _buildFormView(theme, primaryTextColor, secondaryTextColor, buttonBgColor, buttonTextColor, isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(
    ThemeData theme,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color buttonBgColor,
    Color buttonTextColor,
    bool isDark,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon Badge
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                LucideIcons.keyRound,
                color: AppColors.accent,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Reset Password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Enter your registered email address to receive password reset instructions.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 28),

          // Error Box if any
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.alertTriangle,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Email Label & Field
          Text(
            'Email',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSendResetEmail(),
            style: TextStyle(color: primaryTextColor),
            decoration: InputDecoration(
              hintText: 'name@example.com',
              prefixIcon: Icon(
                LucideIcons.mail,
                size: 20,
                color: secondaryTextColor,
              ),
              hintStyle: TextStyle(
                color: isDark ? AppColors.textPlaceholderDark : AppColors.textPlaceholderLight,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),

          // Primary Button: "Send Reset Link"
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: (_isLoading || !_isFormValid) ? null : _handleSendResetEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBgColor,
                foregroundColor: buttonTextColor,
                disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                disabledForegroundColor: isDark ? Colors.grey[600] : Colors.grey[500],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: buttonTextColor,
                      ),
                    )
                  : const Text(
                      'Send Reset Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Back to Sign In Link
          Center(
            child: TextButton.icon(
              onPressed: _isLoading ? null : () => context.go('/login'),
              icon: const Icon(LucideIcons.arrowLeft, size: 16),
              label: const Text(
                'Back to Sign In',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: secondaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(
    Color primaryTextColor,
    Color secondaryTextColor,
    Color buttonBgColor,
    Color buttonTextColor,
    bool isDark,
  ) {
    final email = _emailController.text.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Check Badge
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.income.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Icon(
              LucideIcons.checkCircle2,
              color: AppColors.income,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        Text(
          'Check Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 12),

        // Body message
        Text(
          'We have sent password reset instructions to:\n$email',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'If you do not see the email shortly, check your spam or junk folder.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // Back to Sign In Primary Button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBgColor,
              foregroundColor: buttonTextColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Back to Sign In',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Resend option
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _emailSent = false;
              });
            },
            child: const Text('Try another email address'),
          ),
        ),
      ],
    );
  }
}
