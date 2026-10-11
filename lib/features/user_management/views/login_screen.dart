import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/features/user_management/services/auth_service.dart';
import 'package:arc/features/user_management/services/login_rate_limiter.dart';
import 'package:arc/features/user_management/models/auth_exception.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/views/widgets/google_logo.dart';

/// Professional Login Screen for Project Arc supporting Email/Password and
/// Google Authentication with ARC-level 10-attempt rate limiting.
class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback? onLoginSuccess;
  final AuthService? authService;
  final LoginRateLimiter? rateLimiter;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
    this.authService,
    this.rateLimiter,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AuthService _authService;
  late final LoginRateLimiter _rateLimiter;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _rateLimiter = widget.rateLimiter ?? LoginRateLimiter();
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _emailController.removeListener(_onFieldChanged);
    _passwordController.removeListener(_onFieldChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isFormValid =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.trim().isNotEmpty;

  Future<void> _handleLogin() async {
    // 1. Form validation — if invalid, do NOT increment attempt counter
    if (!_formKey.currentState!.validate()) return;

    // 2. Check if password login is currently rate-limited
    if (await _rateLimiter.isLocked()) {
      final remaining = await _rateLimiter.getRemainingLockDuration();
      if (mounted) {
        setState(() {
          _errorMessage = LoginRateLimiter.getThrottledMessage(remaining);
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final input = _emailController.text.trim();
    final password = _passwordController.text;

    // 3. Count this actual submitted attempt to Firebase
    await _rateLimiter.recordAttempt();

    try {
      UserProfile profile;
      if (input.contains('@')) {
        // Standard Firebase Email/Password Sign-In
        profile = await _authService.signInWithEmailAndPassword(
          email: input,
          password: password,
        );
      } else {
        // Legacy Username Sign-In fallback
        profile = await _authService.loginWithUsername(
          username: input,
          password: password,
        );
      }

      // 4. Successful login resets attempt counter
      await _rateLimiter.reset();

      if (mounted) {
        _onAuthSuccess(profile);
      }
    } catch (e) {
      if (mounted) {
        final isNowLocked = await _rateLimiter.isLocked();
        setState(() {
          if (isNowLocked) {
            _rateLimiter.getRemainingLockDuration().then((rem) {
              if (mounted) {
                setState(() {
                  _errorMessage = LoginRateLimiter.getThrottledMessage(rem);
                });
              }
            });
            _errorMessage = LoginRateLimiter.getThrottledMessage(const Duration(hours: 6));
          } else {
            final rawMsg = e.toString();
            if (rawMsg.contains('Invalid username')) {
              _errorMessage = 'Invalid username';
            } else if (rawMsg.contains('Invalid password')) {
              _errorMessage = 'Invalid password';
            } else if (e is AuthException) {
              _errorMessage = e.message;
            } else {
              _errorMessage = AuthException.fromFirebase(e).message;
            }
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _authService.signInWithGoogle();
      if (mounted) {
        _onAuthSuccess(profile);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is AuthException) {
            if (e.code == 'cancelled' || e.code == 'popup-closed-by-user') {
              // Sign-in cancelled by user, no error banner needed
              _errorMessage = null;
            } else {
              _errorMessage = e.message;
            }
          } else {
            _errorMessage = AuthException.fromFirebase(e).message;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _onAuthSuccess(UserProfile profile) {
    ref.read(userContextProvider.notifier).setActiveUser(
      userId: profile.id,
      profile: profile,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Welcome back, ${profile.displayName}!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );

    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
    } else {
      final userContext = ref.read(userContextProvider);
      if (userContext.isAdmin) {
        context.go('/admin');
      } else {
        context.go('/');
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

    final anyLoading = _isLoading || _isGoogleLoading;

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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Branding Badge
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
                            LucideIcons.sparkles,
                            color: AppColors.accent,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title (Large, Bold, Serif)
                      Text(
                        'Welcome Back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Subtitle
                      Text(
                        'Enter your email and password to access your account',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 32),

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

                      // Email / Username Label & Field
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
                        enabled: !anyLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
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
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Password Label & Forgot Password Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: anyLoading
                                ? null
                                : () {
                                    context.go('/forgot-password');
                                  },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !anyLoading,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        style: TextStyle(color: primaryTextColor),
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          prefixIcon: Icon(
                            LucideIcons.lock,
                            size: 20,
                            color: secondaryTextColor,
                          ),
                          hintStyle: TextStyle(
                            color: isDark ? AppColors.textPlaceholderDark : AppColors.textPlaceholderLight,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                              color: secondaryTextColor,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Primary Button: "Sign In"
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (anyLoading || !_isFormValid) ? null : _handleLogin,
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
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: buttonTextColor,
                                  ),
                                )
                              : Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _isFormValid ? buttonTextColor : null,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // OR Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Continue with Google Button
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: anyLoading ? null : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryTextColor,
                            side: BorderSide(
                              color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                            ),
                          ),
                          child: _isGoogleLoading
                              ? SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: primaryTextColor,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const GoogleLogo(size: 20),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Don't have an account? Sign Up Link
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: anyLoading
                                ? null
                                : () {
                                    context.go('/signup');
                                  },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
}
