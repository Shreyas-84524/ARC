import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/services/app_haptics.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/providers/feedback_providers.dart';
import 'package:arc/features/feedback/utils/feedback_ui_constants.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';

/// Dedicated Conversational Interface for General User Feedback.
///
/// Features a minimal, warm, and inviting layout encouraging honest thoughts,
/// optional prompt inspirations, comfortable distraction-free writing canvas,
/// and debounced category-isolated draft preservation.
class GeneralFeedbackScreen extends ConsumerStatefulWidget {
  const GeneralFeedbackScreen({super.key});

  @override
  ConsumerState<GeneralFeedbackScreen> createState() => _GeneralFeedbackScreenState();
}

class _GeneralFeedbackScreenState extends ConsumerState<GeneralFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedModule = 'general';
  String? _selectedPrompt;

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final FocusNode _messageFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _showDetails = false;
  Timer? _draftDebounce;

  static const Color _conversationalCyan = Color(0xFF38BDF8);

  static const List<String> _inspirationPrompts = [
    'What do you enjoy about Arc?',
    'What could we improve?',
    'Is anything making the app difficult to use?',
    'How does Arc fit into your daily routine?',
  ];

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initUserEmailAndDraft();
    });
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _messageController.dispose();
    _emailController.dispose();
    _messageFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initUserEmailAndDraft() async {
    final userContext = ref.read(userContextProvider);
    final userEmail = userContext.profile?.email;

    final draftService = ref.read(feedbackDraftServiceProvider);
    final draft = await draftService.loadDraft(FeedbackCategory.generalFeedback);

    if (mounted) {
      if (draft != null) {
        final payload = GeneralFeedbackPayload.fromDraft(draft);
        setState(() {
          _selectedModule = payload.module;
          _selectedPrompt = payload.selectedPrompt;
          _messageController.text = payload.message;
          _emailController.text = payload.contactEmail ?? userEmail ?? '';
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
      } else if (userEmail != null && userEmail.isNotEmpty) {
        setState(() {
          _emailController.text = userEmail;
        });
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
    final draftService = ref.read(feedbackDraftServiceProvider);
    final payload = GeneralFeedbackPayload(
      module: _selectedModule,
      message: _messageController.text,
      selectedPrompt: _selectedPrompt,
      contactEmail: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
    );

    if (payload.message.trim().isEmpty && _selectedPrompt == null) {
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

  void _togglePrompt(String prompt) {
    AppHaptics.selectionClick();
    setState(() {
      if (_selectedPrompt == prompt) {
        _selectedPrompt = null;
      } else {
        _selectedPrompt = prompt;
      }
    });
    _onFieldChanged();
  }

  Future<void> _submitFeedback() async {
    FocusScope.of(context).unfocus();

    final payload = GeneralFeedbackPayload(
      module: _selectedModule,
      message: _messageController.text,
      selectedPrompt: _selectedPrompt,
      contactEmail: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
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
              e is ArgumentError ? e.message.toString() : 'Failed to submit feedback. Your draft has been preserved.',
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _conversationalCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.heartHandshake, color: _conversationalCyan, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Thank You!',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Ref: ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
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
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _conversationalCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  context.pushReplacement('/feedback/my-feedback');
                }
              },
              child: const Text('View Status', style: TextStyle(fontWeight: FontWeight.bold)),
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcoming Conversational Hero Header
                _buildConversationalHero(theme, isDark),
                const SizedBox(height: 24),

                // Inspiration Prompts Section
                _buildPromptChips(theme, isDark),
                const SizedBox(height: 20),

                // Large Comfortable Writing Area
                _buildMessageCanvas(theme, isDark),
                const SizedBox(height: 16),

                // Expandable Details (Module & Email)
                _buildOptionalDetails(theme, isDark),
                const SizedBox(height: 28),

                // Submit Button
                _buildSubmitButton(theme, isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationalHero(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _conversationalCyan.withValues(alpha: 0.2),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _conversationalCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.messageCircle, color: _conversationalCyan, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'We\'re All Ears',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Direct, thoughtful conversations with the builders',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Whether you love an aspect of Arc, feel friction with a workflow, or just want to share an impression — we read every single message.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptChips(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.sparkles, size: 14, color: _conversationalCyan),
            const SizedBox(width: 6),
            Text(
              'INSPIRATION PROMPTS (OPTIONAL)',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _inspirationPrompts.map((prompt) {
            final isSelected = _selectedPrompt == prompt;
            return FilterChip(
              selected: isSelected,
              showCheckmark: false,
              label: Text(
                prompt,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
              ),
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
              selectedColor: _conversationalCyan.withValues(alpha: 0.85),
              side: BorderSide(
                color: isSelected
                    ? _conversationalCyan
                    : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (_) => _togglePrompt(prompt),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMessageCanvas(ThemeData theme, bool isDark) {
    final currentLength = _messageController.text.length;
    final hintText = _selectedPrompt != null
        ? 'Regarding "$_selectedPrompt":\n\nShare your thoughts here...'
        : 'What\'s on your mind? Tell us anything about your experience...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedPrompt != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _conversationalCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _conversationalCyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.tag, size: 13, color: _conversationalCyan),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Topic: $_selectedPrompt',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    AppHaptics.selectionClick();
                    setState(() => _selectedPrompt = null);
                    _onFieldChanged();
                  },
                  child: Icon(
                    LucideIcons.x,
                    size: 14,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
            ),
          ),
          child: Column(
            children: [
              TextFormField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                minLines: 6,
                maxLines: 12,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.textPlaceholderDark : AppColors.textPlaceholderLight,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '$currentLength / 5,000',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: currentLength > 4500
                            ? AppColors.danger
                            : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionalDetails(ThemeData theme, bool isDark) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            AppHaptics.selectionClick();
            setState(() => _showDetails = !_showDetails);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _showDetails ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 16,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
                const SizedBox(width: 8),
                Text(
                  _showDetails ? 'Hide additional context' : 'Add context (component & follow-up email)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showDetails) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'APP COMPONENT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedModule,
                  dropdownColor: isDark ? AppColors.darkElevated : AppColors.lightSurface,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                      ),
                    ),
                  ),
                  items: FeedbackModuleInfo.modules.map((opt) {
                    return DropdownMenuItem(
                      value: opt.key,
                      child: Text(opt.label),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedModule = val);
                      _onFieldChanged();
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'FOLLOW-UP EMAIL (OPTIONAL)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'name@example.com',
                    prefixIcon: const Icon(LucideIcons.mail, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _isSubmitting ? null : _submitFeedback,
        child: _isSubmitting
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
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
