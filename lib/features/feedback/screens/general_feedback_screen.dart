import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/providers/feedback_providers.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';

/// Dedicated Conversational Interface for General User Feedback.
///
/// Features a minimal, warm, and inviting layout encouraging honest thoughts,
/// comfortable distraction-free writing canvas, and debounced category-isolated
/// draft preservation.
class GeneralFeedbackScreen extends ConsumerStatefulWidget {
  const GeneralFeedbackScreen({super.key});

  @override
  ConsumerState<GeneralFeedbackScreen> createState() =>
      _GeneralFeedbackScreenState();
}

class _GeneralFeedbackScreenState extends ConsumerState<GeneralFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  bool _isSubmitting = false;
  Timer? _draftDebounce;

  static const Color _conversationalCyan = Color(0xFF38BDF8);

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initUserEmailAndDraft();
    });
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initUserEmailAndDraft() async {
    final draftService = ref.read(feedbackDraftServiceProvider);
    final draft = await draftService.loadDraft(
      FeedbackCategory.generalFeedback,
    );

    if (mounted) {
      if (draft != null) {
        final payload = GeneralFeedbackPayload.fromDraft(draft);
        setState(() {
          _messageController.text = payload.message;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.fileText, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('Restored your unsaved feedback draft'),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.darkCard,
          ),
        );
      }
    }
  }

  void _onFieldChanged() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 600), () {
      _saveDraft();
    });
    if (mounted) setState(() {});
  }

  Future<void> _saveDraft() async {
    if (!mounted) return;
    final userContext = ref.read(userContextProvider);
    final userEmail = userContext.profile?.email;
    final draftService = ref.read(feedbackDraftServiceProvider);
    final payload = GeneralFeedbackPayload(
      module: 'general',
      message: _messageController.text,
      contactEmail: userEmail,
    );

    if (payload.message.trim().isEmpty) {
      await draftService.clearDraft(FeedbackCategory.generalFeedback);
    } else {
      await draftService.saveDraft(
        category: FeedbackCategory.generalFeedback,
        module: payload.module,
        message: payload.message,
        contactEmail: payload.contactEmail,
        extraFields: payload.toDraftMap(),
      );
    }
  }

  Future<void> _submitFeedback() async {
    FocusScope.of(context).unfocus();

    final userContext = ref.read(userContextProvider);
    final userEmail = userContext.profile?.email;
    final payload = GeneralFeedbackPayload(
      module: 'general',
      message: _messageController.text,
      contactEmail: userEmail,
    );

    final error = payload.validate();
    if (error != null) {
      AppHaptics.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    AppHaptics.mediumImpact();

    try {
      final repository = ref.read(feedbackRepositoryProvider);
      final submitted = await repository.submitFeedback(
        category: FeedbackCategory.generalFeedback,
        module: payload.module,
        message: payload.toSerializedMessage(),
        contactEmail: payload.contactEmail,
      );

      // Invalidate stream & future providers so My Feedback reflects new submission immediately
      ref.invalidate(currentUserFeedbackStreamProvider);
      ref.invalidate(currentUserFeedbackProvider);

      final draftService = ref.read(feedbackDraftServiceProvider);
      await draftService.clearDraft(FeedbackCategory.generalFeedback);

      if (mounted) {
        AppHaptics.lightImpact();
        _showSuccessDialog(submitted);
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ArgumentError
                  ? e.message.toString()
                  : 'Failed to submit feedback. Your draft has been preserved.',
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _submitFeedback,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showSuccessDialog(FeedbackModel feedback) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _conversationalCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.heartHandshake,
                  color: _conversationalCyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Thank You!',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your thoughts have been delivered directly to our team. Every note helps us build a more mindful and effective Arc.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightBgSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderSubtle
                        : AppColors.borderSubtleLight,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Ref: ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        feedback.feedbackId,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted) context.pop();
              },
              child: Text(
                'Done',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _conversationalCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  context.pushReplacement('/feedback/my-feedback');
                }
              },
              child: const Text(
                'View Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('General Feedback'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            AppHaptics.lightImpact();
            context.pop();
          },
        ),
        actions: [
          IconButton(
            tooltip: 'My Feedback Submissions',
            icon: const Icon(LucideIcons.inbox),
            onPressed: () {
              AppHaptics.lightImpact();
              context.push('/feedback/my-feedback');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                Expanded(
                  child: _buildMergedFeedbackCard(theme, isDark),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _buildSubmitButton(theme, isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMergedFeedbackCard(ThemeData theme, bool isDark) {
    final currentLength = _messageController.text.length;
    const hintText = 'What\'s on your mind? Tell us anything about your experience...';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _conversationalCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.messageCircle,
                  color: _conversationalCyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'We\'re All Ears',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Direct, thoughtful conversations with the builders',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Whether you love an aspect of Arc, feel friction with a workflow, or just want to share an impression — we read every single message.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderMedium
                      : AppColors.borderMediumLight,
                ),
              ),
              child: TextFormField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  counterText: '$currentLength / 5,000',
                  hintStyle: TextStyle(
                    color: isDark
                        ? AppColors.textPlaceholderDark
                        : AppColors.textPlaceholderLight,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 10) {
                    return 'Please enter at least 10 characters.';
                  }
                  return null;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _conversationalCyan,
          foregroundColor: Colors.black,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _isSubmitting ? null : _submitFeedback,
        child: _isSubmitting
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.black,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.send, size: 18, color: Colors.black),
                  SizedBox(width: 10),
                  Text(
                    'Submit Feedback',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
