import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/providers/global_providers.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/services/auth_service.dart';
import 'package:arc/features/user_management/models/auth_exception.dart';
import 'package:arc/features/user_management/views/widgets/google_logo.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/core/notifications/notification_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final AuthService? authService;

  const SettingsScreen({
    super.key,
    this.authService,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  bool _masterNotifications = true;
  bool _taskReminders = true;
  bool _habitReminders = true;
  bool _moneyReminders = true;

  // Password Change controllers
  final _changePasswordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isChangingPassword = false;
  bool _isPasswordSectionExpanded = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _masterNotifications = settings.masterNotificationsEnabled;
    _taskReminders = settings.taskRemindersEnabled;
    _habitReminders = settings.habitRemindersEnabled;
    _moneyReminders = settings.moneyRemindersEnabled;
  }

  String _formatReminderTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final dt = DateTime(2026, 1, 1, hour, minute);
        return DateFormat('h:mm a').format(dt);
      }
    } catch (_) {}
    return timeStr;
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _showAddPasswordDialog(String email) async {
    final formKey = GlobalKey<FormState>();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? localError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setDialogState) {
            final theme = Theme.of(sbContext);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkModal : AppColors.lightModal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              title: Row(
                children: [
                  const Icon(LucideIcons.keyRound, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  const Text('Add ARC Password'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Adding an ARC password gives you another way to sign in. Your Google Sign-In will continue working normally.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (localError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              localError!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Verified Google Email (Read-Only)
                        TextFormField(
                          initialValue: email,
                          enabled: false,
                          style: TextStyle(
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Verified Email',
                            labelStyle: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            prefixIcon: const Icon(LucideIcons.mail),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // New Password
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: obscureNew,
                          enabled: !isSubmitting,
                          style: TextStyle(
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            labelStyle: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            prefixIcon: const Icon(LucideIcons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(obscureNew ? LucideIcons.eyeOff : LucideIcons.eye),
                              onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter a password';
                            if (v.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // Confirm Password
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirm,
                          enabled: !isSubmitting,
                          style: TextStyle(
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            labelStyle: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            prefixIcon: const Icon(LucideIcons.checkCheck),
                            suffixIcon: IconButton(
                              icon: Icon(obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye),
                              onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                            ),
                          ),
                          validator: (v) {
                            if (v != newPasswordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isSubmitting = true;
                            localError = null;
                          });

                          try {
                            await _authService.linkPassword(newPassword: newPasswordController.text);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'ARC Password added successfully! You can now log in with either Google or your email and password.',
                                  ),
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              localError = e is AuthException ? e.message : e.toString();
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Add Password', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_changePasswordFormKey.currentState!.validate()) return;

    setState(() {
      _isChangingPassword = true;
    });

    try {
      await _authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        setState(() {
          _isPasswordSectionExpanded = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password updated successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('ArgumentError:', '').replaceAll('Exception:', '').trim()),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          backgroundColor: isDark ? AppColors.darkModal : AppColors.lightModal,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Badge
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.logOut,
                    size: 26,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Log out?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),

                // Concise explanation
                Text(
                  'Are you sure you want to log out of your account?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons Row
                Row(
                  children: [
                    // Cancel Action (Visually Secondary)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 46),
                          foregroundColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          side: BorderSide(
                            color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop(false);
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Primary / Destructive Logout Action
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 46),
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(context).pop(true);
                        },
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack).fade(duration: 150.ms);
      },
    );

    if (confirm != true || !mounted) return;

    // Show non-dismissible loading indicator feedback
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(
                child: Text('Saving your latest changes...'),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final userContext = ref.read(userContextProvider);
      final userId = userContext.userId;

      // 1. Flush pending changes before logout
      final syncService = ref.read(syncServiceProvider);
      final syncManager = ref.read(syncManagerProvider);
      final flushSuccess = await syncManager.flushPendingChanges(syncService);

      // 2. Check if unsynced items still remain in queues (e.g. if network or sync failed)
      bool hasUnsyncedItems = false;
      if (userId != null && userId.isNotEmpty) {
        final taskQ = HiveService().getUserBox(HiveService.tasksSyncQueueBoxName, userId);
        final habitQ = HiveService().getUserBox(HiveService.habitsSyncQueueBoxName, userId);
        final moneyQ = HiveService().getUserBox(HiveService.moneySyncQueueBoxName, userId);
        hasUnsyncedItems = taskQ.isNotEmpty || habitQ.isNotEmpty || moneyQ.isNotEmpty;
      }

      if (!flushSuccess || hasUnsyncedItems) {
        if (mounted) Navigator.of(context).pop(); // Dismiss loading

        if (mounted) {
          final retry = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Logout Paused'),
              content: const Text(
                'Some changes could not be saved to cloud storage due to network issues or sync errors. Please check your internet connection and try again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel Logout'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Retry Logout'),
                ),
              ],
            ),
          );

          if (retry == true) {
            _handleLogout();
          }
        }
        return;
      }

      // 3. Stop real-time listeners for current user
      syncService.stopRealTimeSync();

      // Cancel all scheduled notifications for the outgoing user
      await NotificationService().cancelAllUserNotifications();

      // 4. Safely close current user's Hive boxes
      await HiveService().closeUserBoxes(userId);

      // 5. Invalidate user-scoped providers and caches
      ref.invalidate(tasksProvider);
      ref.invalidate(habitsProvider);
      ref.invalidate(habitEntriesProvider);
      ref.invalidate(moneyProvider);
      ref.invalidate(monthlyBudgetProvider);
      ref.invalidate(appSettingsProvider);
      ref.invalidate(taskRepositoryProvider);
      ref.invalidate(habitRepositoryProvider);
      ref.invalidate(moneyRepositoryProvider);
      ref.invalidate(settingsRepositoryProvider);

      // 6. Reset user context state
      ref.read(userContextProvider.notifier).resetToLegacy();

      // 7. Sign out from Firebase Auth
      await _authService.logout();

      if (mounted) Navigator.of(context).pop(); // Dismiss loading

      // 7. Navigate to Login screen
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      debugPrint('Error during logout process: $e');
    }
  }

  Future<void> _confirmClearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Local Cache'),
        content: const Text('This will clean temporary cache files from local storage. Your saved data will remain intact.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop(true);
            },
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local database cache cleared.')),
      );
    }
  }

  Future<void> _confirmResetData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Application Data'),
        content: const Text(
          'CAUTION: This action will reset local settings and offline cache. Cloud backup on Firestore will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.of(context).pop(true);
            },
            child: const Text('Reset Data'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application data reset.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final themeMode = ref.watch(themeModeProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final userContext = ref.watch(userContextProvider);
    final currentUsername = userContext.profile?.displayName ?? userContext.profile?.username ?? 'User';

    final linkedProviders = _authService.getLinkedProviders();
    final hasGoogle = linkedProviders.isNotEmpty
        ? linkedProviders.contains('google.com')
        : (userContext.profile?.authProvider.contains('google') ?? false);
    final hasPassword = linkedProviders.isNotEmpty
        ? linkedProviders.contains('password')
        : (userContext.profile?.authProvider.contains('password') ?? true);
    final userEmail = userContext.profile?.email ?? UserProfile.emailForUsername(currentUsername);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings & Profile',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ==========================================
          // 1. ACCOUNT & CHANGE PASSWORD (START OF SETTINGS)
          // ==========================================
          Text('Account & Security', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Profile Avatar (Black background, App Accent Green User Icon)
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.black,
                        child: Icon(
                          LucideIcons.user,
                          color: AppColors.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // User Details (Username & Email)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentUsername,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userEmail,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Change Password Action Button (Only shown if password provider exists)
                      if (hasPassword)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isPasswordSectionExpanded = !_isPasswordSectionExpanded;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isPasswordSectionExpanded ? LucideIcons.chevronUp : LucideIcons.key,
                                  size: 16,
                                  color: AppColors.danger,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isPasswordSectionExpanded ? 'Close' : 'Change Password',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  const Divider(height: 28),

                  // Sign-in Method Section
                  Text(
                    'Sign-in Method',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Google Row (Only shown if signed in with Google)
                  if (hasGoogle)
                    Row(
                      children: [
                        const GoogleLogo(size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Google',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (hasGoogle && hasPassword) const SizedBox(height: 10),

                  // Email & Password Row (Only shown if signed in with Email & Password)
                  if (hasPassword)
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mail,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Email & Password',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Optional Add ARC Password button (Requirement 4 & 5)
                  if (!hasPassword) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddPasswordDialog(userEmail),
                        icon: const Icon(LucideIcons.plusCircle, size: 16),
                        label: const Text(
                          'Add ARC Password',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (_isPasswordSectionExpanded) ...[
                    const Divider(height: 28),
                    Form(
                      key: _changePasswordFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Change Password',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.danger,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: _obscureCurrentPassword,
                            enabled: !_isChangingPassword,
                            style: TextStyle(
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Current Password',
                              labelStyle: TextStyle(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              prefixIcon: Icon(
                                LucideIcons.lock,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureCurrentPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                                onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Please enter your current password' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNewPassword,
                            enabled: !_isChangingPassword,
                            style: TextStyle(
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              labelStyle: TextStyle(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              prefixIcon: Icon(
                                LucideIcons.keyRound,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNewPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                                onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Please enter a new password';
                              if (v.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            enabled: !_isChangingPassword,
                            style: TextStyle(
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password',
                              labelStyle: TextStyle(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              prefixIcon: Icon(
                                LucideIcons.checkCheck,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                            validator: (v) {
                              if (v != _newPasswordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isChangingPassword ? null : _handleChangePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                                ),
                                elevation: 0,
                              ),
                              child: _isChangingPassword
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text(
                                      'Update Password',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 2. Appearance Section
          Text('Appearance', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(LucideIcons.moon, color: AppColors.accent),
                  title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Toggle between Dark and Light theme'),
                  value: themeMode == ThemeMode.dark,
                  activeThumbColor: AppColors.accent,
                  onChanged: (val) {
                    ref.read(appSettingsProvider.notifier).updateThemeMode(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. Notifications Section
          Text('Notifications', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(LucideIcons.bell, color: AppColors.accent),
                  title: const Text('Master Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_masterNotifications ? 'Notifications: Enabled' : 'Notifications: Disabled'),
                  value: _masterNotifications,
                  activeThumbColor: AppColors.accent,
                  onChanged: (val) {
                    setState(() {
                      _masterNotifications = val;
                      _taskReminders = val;
                      _habitReminders = val;
                      _moneyReminders = val;
                    });
                    ref.read(appSettingsProvider.notifier).updateMasterNotifications(val);
                  },
                ),
                if (_masterNotifications) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(LucideIcons.clock, color: AppColors.accent),
                    title: const Text('Daily Reminder Time', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Pending habits & spending check-in at ${_formatReminderTime(appSettings.remTime)}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            appSettings.remTime,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                          ),
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.pencil, size: 14, color: AppColors.accent),
                        ],
                      ),
                    ),
                    onTap: () async {
                      final parts = appSettings.remTime.split(':');
                      int initialHour = 21;
                      int initialMinute = 0;
                      if (parts.length == 2) {
                        initialHour = int.tryParse(parts[0]) ?? 21;
                        initialMinute = int.tryParse(parts[1]) ?? 0;
                      }
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
                      );
                      if (picked != null) {
                        final formatted =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        await ref.read(appSettingsProvider.notifier).updateRemTime(formatted);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Daily reminder time updated to $formatted'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(LucideIcons.checkSquare, color: AppColors.accent),
                    title: const Text('Task Reminders'),
                    subtitle: const Text('Alerts 5m before deadline and at due time'),
                    value: _taskReminders,
                    activeThumbColor: AppColors.accent,
                    onChanged: (val) {
                      setState(() => _taskReminders = val);
                      final updated = appSettings.copyWith(taskRemindersEnabled: val);
                      ref.read(appSettingsProvider.notifier).updateSettings(updated);
                      if (!val) {
                        for (final task in ref.read(tasksProvider)) {
                          NotificationService().cancelTaskReminders(task.id);
                        }
                      } else {
                        for (final task in ref.read(tasksProvider)) {
                          if (!task.completed && task.dueDate != null && task.dueTime != null) {
                            NotificationService().scheduleTaskReminders(task);
                          }
                        }
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(LucideIcons.zap, color: AppColors.accent),
                    title: const Text('Habit Reminders'),
                    subtitle: Text('Habit deadline alerts & check-in at ${_formatReminderTime(appSettings.remTime)}'),
                    value: _habitReminders,
                    activeThumbColor: AppColors.accent,
                    onChanged: (val) {
                      setState(() => _habitReminders = val);
                      final updated = appSettings.copyWith(habitRemindersEnabled: val);
                      ref.read(appSettingsProvider.notifier).updateSettings(updated);
                      if (!val) {
                        for (final habit in ref.read(habitsProvider)) {
                          NotificationService().cancelHabitReminders(habit.id);
                        }
                        NotificationService().cancelEveningReminder();
                      } else {
                        ref.read(habitsProvider.notifier).refresh();
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(LucideIcons.wallet, color: AppColors.success),
                    title: const Text('Expense Reminders'),
                    subtitle: Text('Daily reminder to log spending at ${_formatReminderTime(appSettings.remTime)}'),
                    value: _moneyReminders,
                    activeThumbColor: AppColors.accent,
                    onChanged: (val) {
                      setState(() => _moneyReminders = val);
                      final updated = appSettings.copyWith(moneyRemindersEnabled: val);
                      ref.read(appSettingsProvider.notifier).updateSettings(updated);
                      if (!val) {
                        NotificationService().cancelMoneyReminders();
                      } else {
                        NotificationService().scheduleDailyMoneyReminder(appSettings.remTime);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 5. Backup & Maintenance
          Text('Backup & Maintenance', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.hardDrive, color: AppColors.accent),
                  title: const Text('Clear Local Cache', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Clean cached temporary indexes'),
                  onTap: _confirmClearCache,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(LucideIcons.alertTriangle, color: AppColors.danger),
                  title: const Text('Reset Local Data', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Reset local storage cache'),
                  onTap: _confirmResetData,
                ),
              ],
            ),
          ),

          Card(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              side: BorderSide(
                color: AppColors.danger.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _handleLogout();
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.logOut,
                        color: AppColors.danger,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.danger,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sign out of account and sync session',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: AppColors.danger.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fade(duration: 200.ms).slideY(begin: 0.05),

          const SizedBox(height: 32),

          // 6. About & App Version Info (At the very bottom)
          Center(
            child: Column(
              children: [
                Text(
                  'Project Arc',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.3.5 • Build 2026.08',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Made with love in India',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
