import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utils/display_name_utils.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/features/user_management/services/auth_service.dart';

/// Modal dialog allowing users to customize their in-app display name.
///
/// Enforces whitespace normalization, length constraints (2–50 chars),
/// emoji rejection, and Unicode international character support.
class EditDisplayNameDialog extends ConsumerStatefulWidget {
  final UserProfile currentProfile;
  final AuthService? authService;

  const EditDisplayNameDialog({
    super.key,
    required this.currentProfile,
    this.authService,
  });

  @override
  ConsumerState<EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends ConsumerState<EditDisplayNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  bool _isSaving = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentProfile.displayName);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_inlineError != null) {
      setState(() {
        _inlineError = null;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _handleSave() async {
    final rawText = _controller.text;
    final validationError = DisplayNameUtils.validate(rawText);

    if (validationError != null) {
      AppHaptics.heavyImpact();
      setState(() {
        _inlineError = validationError;
      });
      return;
    }

    final normalized = DisplayNameUtils.normalize(rawText);

    // If name is unchanged, simply dismiss without network activity
    if (normalized == widget.currentProfile.displayName) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });

    try {
      final authService = widget.authService ?? AuthService();
      final updatedProfile = await authService.updateDisplayName(
        userId: widget.currentProfile.id,
        newDisplayName: normalized,
      );

      // Immediately update Riverpod state so dashboard and settings reflect the change
      ref.read(userContextProvider.notifier).updateProfile(updatedProfile);

      AppHaptics.lightImpact();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        debugPrint('EditDisplayNameDialog: successfully popped dialog');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.checkCircle, color: Colors.black, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Display name updated to "$normalized"',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('EditDisplayNameDialog _handleSave error: $e\n$stack');
      AppHaptics.heavyImpact();
      setState(() {
        _isSaving = false;
        _inlineError = e is ArgumentError ? e.message.toString() : 'Failed to update display name. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentLength = _controller.text.length;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.userCheck, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Edit Display Name',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose how your name appears on your dashboard greeting and throughout Arc.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'e.g. Shreyas',
                  prefixIcon: const Icon(LucideIcons.user, size: 18),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            AppHaptics.selectionClick();
                            _controller.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 1.5,
                    ),
                  ),
                  counterText: '$currentLength / 50',
                  counterStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: currentLength > 50
                        ? AppColors.danger
                        : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                  ),
                ),
                onFieldSubmitted: (_) => _handleSave(),
              ),
              if (_inlineError != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.alertCircle, size: 15, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _inlineError!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Note: Emojis and special symbols are not allowed. Valid international and Indian-language names are supported.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  AppHaptics.lightImpact();
                  Navigator.of(context).pop();
                },
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
        ),
      ],
    );
  }
}
