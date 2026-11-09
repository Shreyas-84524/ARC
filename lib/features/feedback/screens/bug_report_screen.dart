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

/// Dedicated screen for reporting technical issues and bugs.
class BugReportScreen extends ConsumerStatefulWidget {
  const BugReportScreen({super.key});

  @override
  ConsumerState<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends ConsumerState<BugReportScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _descFocusNode = FocusNode();

  bool _isSubmitting = false;
  Timer? _draftDebounce;

  static const Color _diagnosticRed = Color(0xFFFF4D4F);
  static const Color _diagnosticRedDim = Color(0x22FF4D4F);

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDraft();
    });
  }

  Future<void> _initDraft() async {
    final draftService = ref.read(feedbackDraftServiceProvider);
    final draft = await draftService.loadDraft(FeedbackCategory.bugReport);

    if (mounted) {
      if (draft != null) {
        final payload = BugReportPayload.fromDraft(draft);
        setState(() {
          _descriptionController.text = payload.description;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.fileText, color: Colors.black, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Restored your previously saved bug report draft.',
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _diagnosticRed,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onFieldChanged() {
    setState(() {}); // Updates character counters and live validation
    _saveDraftDebounced();
  }

  void _saveDraftDebounced() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final payload = _buildCurrentPayload();
      if (payload.description.trim().isEmpty) {
        ref
            .read(feedbackDraftServiceProvider)
            .clearDraft(FeedbackCategory.bugReport);
      } else {
        ref
            .read(feedbackDraftServiceProvider)
            .saveDraft(
              category: FeedbackCategory.bugReport,
              module: 'general',
              message: payload.toSerializedMessage(),
              contactEmail: payload.contactEmail,
              extraFields: payload.toDraftMap(),
            );
      }
    });
  }

  String _deriveTitle(String description) {
    final clean = description.trim();
    if (clean.isEmpty) return 'Bug Report';
    final firstLine = clean.split('\n').first.trim();
    if (firstLine.length <= 100) return firstLine;
    return '${firstLine.substring(0, 97)}...';
  }

  BugReportPayload _buildCurrentPayload() {
    final userContext = ref.read(userContextProvider);
    final userEmail = userContext.profile?.email;
    final description = _descriptionController.text.trim();
    return BugReportPayload(
      module: 'general',
      title: _deriveTitle(description),
      description: description,
      stepsToReproduce: '',
      expectedBehavior: '',
      actualBehavior: '',
      contactEmail: userEmail,
    );
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _descriptionController.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitBugReport() async {
    if (_isSubmitting) return;

    final validationError = _buildCurrentPayload().validate();
    if (validationError != null) {
      AppHaptics.heavyImpact();
      _showErrorNotice(validationError);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      AppHaptics.heavyImpact();
      return;
    }

    AppHaptics.mediumImpact();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final payload = _buildCurrentPayload();
      final repository = ref.read(feedbackRepositoryProvider);

      final result = await repository.submitFeedback(
        category: FeedbackCategory.bugReport,
        module: 'general',
        message: payload.toSerializedMessage(),
        contactEmail: payload.contactEmail,
      );

      // Invalidate stream & future providers so My Feedback reflects new submission immediately
      ref.invalidate(currentUserFeedbackStreamProvider);
      ref.invalidate(currentUserFeedbackProvider);

      // Clear draft upon verified submission
      await ref
          .read(feedbackDraftServiceProvider)
          .clearDraft(FeedbackCategory.bugReport);

      if (mounted) {
        _showSuccessDialog(result);
      }
    } catch (e) {
      // Preserve draft on failure
      final payload = _buildCurrentPayload();
      await ref
          .read(feedbackDraftServiceProvider)
          .saveDraft(
            category: FeedbackCategory.bugReport,
            module: 'general',
            message: payload.toSerializedMessage(),
            contactEmail: payload.contactEmail,
            extraFields: payload.toDraftMap(),
          );
      _showErrorNotice(e);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showErrorNotice(dynamic error) {
    if (!mounted) return;
    final message = error is String
        ? error
        : 'Unable to submit bug report. Your draft has been preserved locally.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              LucideIcons.alertTriangle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessDialog(FeedbackModel feedback) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: _diagnosticRedDim,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.bug,
                color: _diagnosticRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bug Report Submitted',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your report has been dispatched to our engineering team for investigation.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.lightBgSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.hash,
                    size: 16,
                    color: AppColors.textMutedDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ticket: ${feedback.feedbackId.substring(0, feedback.feedbackId.length > 8 ? 8 : feedback.feedbackId.length)}...',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _diagnosticRedDim,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'submitted',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _diagnosticRed,
                        fontWeight: FontWeight.bold,
                      ),
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
              Navigator.of(ctx).pop();
              context.pop();
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _diagnosticRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pushReplacement('/feedback/my-feedback');
            },
            child: const Text('View Ticket Status'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            AppHaptics.lightImpact();
            context.pop();
          },
        ),
        title: Text(
          'Report a Bug',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
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
                  child: _buildDescriptionCard(isDark),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _buildSubmitButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _diagnosticRed,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _diagnosticRed.withValues(
          alpha: 0.3,
        ),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        ),
      ),
      onPressed: _isSubmitting ? null : _submitBugReport,
      child: _isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white,
                ),
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.alertOctagon, size: 18),
                SizedBox(width: 8),
                Text(
                  'Submit Bug Report',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDescriptionCard(bool isDark) {
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _diagnosticRedDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.fileWarning,
                  size: 16,
                  color: _diagnosticRed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Problem Description',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Describe the symptoms, error popups, or abnormal behavior.',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: TextFormField(
              controller: _descriptionController,
              focusNode: _descFocusNode,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              decoration: _buildInputDecoration(
                isDark: isDark,
                hintText: 'Provide detailed context on what went wrong...',
                counterText: '${_descriptionController.text.length} / 5,000',
              ),
              validator: (v) {
                if (v == null || v.trim().length < 10) {
                  return 'Please enter at least 10 characters.';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required bool isDark,
    String? hintText,
    String? counterText,
  }) {
    return InputDecoration(
      hintText: hintText,
      counterText: counterText,
      hintStyle: TextStyle(
        fontSize: 13,
        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
      ),
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        borderSide: const BorderSide(color: _diagnosticRed, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
