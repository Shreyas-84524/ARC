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

/// Dedicated creative ideation screen for proposing new Arc features.
class FeatureRequestScreen extends ConsumerStatefulWidget {
  const FeatureRequestScreen({super.key});

  @override
  ConsumerState<FeatureRequestScreen> createState() => _FeatureRequestScreenState();
}

class _FeatureRequestScreenState extends ConsumerState<FeatureRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedModule = 'general';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _benefitController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descFocusNode = FocusNode();
  final FocusNode _benefitFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isSubmitting = false;
  Timer? _draftDebounce;

  static const Color _warmGold = Color(0xFFFFC857);

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _benefitController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDraftAndUserEmail();
    });
  }

  Future<void> _initDraftAndUserEmail() async {
    final userContext = ref.read(userContextProvider);
    final userEmail = userContext.profile?.email;

    final draftService = ref.read(feedbackDraftServiceProvider);
    final draft = await draftService.loadDraft(FeedbackCategory.featureRequest);

    if (mounted) {
      if (draft != null) {
        final payload = FeatureRequestPayload.fromDraft(draft);
        setState(() {
          _selectedModule = payload.module;
          _titleController.text = payload.title;
          _descriptionController.text = payload.description;
          _benefitController.text = payload.benefit ?? '';
          _emailController.text = payload.contactEmail ?? userEmail ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.sparkles, color: Colors.black, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Restored your previously saved feature suggestion.')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (userEmail != null && userEmail.isNotEmpty && _emailController.text.isEmpty) {
        setState(() {
          _emailController.text = userEmail;
        });
      }
    }
  }

  void _onFieldChanged() {
    setState(() {}); // Updates live validation status and character counters
    _saveDraftDebounced();
  }

  void _saveDraftDebounced() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final payload = _buildCurrentPayload();
      ref.read(feedbackDraftServiceProvider).saveDraft(
            category: FeedbackCategory.featureRequest,
            module: _selectedModule,
            message: payload.toSerializedMessage(),
            contactEmail: _emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : null,
            extraFields: payload.toDraftMap(),
          );
    });
  }

  FeatureRequestPayload _buildCurrentPayload() {
    return FeatureRequestPayload(
      module: _selectedModule,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      benefit: _benefitController.text.trim().isNotEmpty ? _benefitController.text.trim() : null,
      contactEmail: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
    );
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _benefitController.dispose();
    _emailController.dispose();

    _titleFocusNode.dispose();
    _descFocusNode.dispose();
    _benefitFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitFeatureSuggestion() async {
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
        category: FeedbackCategory.featureRequest,
        module: _selectedModule,
        message: payload.toSerializedMessage(),
        contactEmail: payload.contactEmail,
      );

      // Invalidate stream & future providers so My Feedback reflects new submission immediately
      ref.invalidate(currentUserFeedbackStreamProvider);
      ref.invalidate(currentUserFeedbackProvider);

      // Clear draft upon verified submission
      await ref.read(feedbackDraftServiceProvider).clearDraft(FeedbackCategory.featureRequest);

      if (mounted) {
        _showSuccessDialog(result);
      }
    } catch (e) {
      // Preserve draft on failure
      final payload = _buildCurrentPayload();
      await ref.read(feedbackDraftServiceProvider).saveDraft(
            category: FeedbackCategory.featureRequest,
            module: _selectedModule,
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
    final message = error is String ? error : 'Unable to submit suggestion. Your draft has been preserved locally.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Colors.white, size: 20),
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
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.sparkles, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Idea Received!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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
              'Thank you for sharing your vision for Arc! Your suggestion will be reviewed during product planning.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.hash, size: 16, color: AppColors.textMutedDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ref: ${feedback.feedbackId.substring(0, 8)}...',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'submitted',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? AppColors.accent : AppColors.darkAccent,
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
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pushReplacement('/feedback/my-feedback');
            },
            child: const Text('View My Ideas'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final payload = _buildCurrentPayload();
    final serializedLength = payload.toSerializedMessage().length;

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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.sparkles, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Suggest a Feature',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ],
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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. Creative Hero Banner
              _buildCreativeHeroBanner(isDark),

              const SizedBox(height: 24),

              // 2. Feature Title Input
              _buildIdeaCard(
                isDark: isDark,
                title: 'Idea Title',
                subtitle: 'Give your feature concept a clear, catchy name.',
                icon: LucideIcons.lightbulb,
                iconColor: _warmGold,
                child: TextFormField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  decoration: _buildInputDecoration(
                    isDark: isDark,
                    hintText: 'e.g. Smart Daily Time-blocking with Auto-Reschedule',
                    counterText: '${_titleController.text.length}/120',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please give your idea a title.';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 3. Where does this fit? (Module Selector Chips)
              _buildIdeaCard(
                isDark: isDark,
                title: 'Where does this belong?',
                subtitle: 'Select the module that best fits your suggestion.',
                icon: LucideIcons.compass,
                iconColor: AppColors.accent,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FeedbackModuleInfo.modules.map((m) {
                    final isSelected = m.key == _selectedModule;
                    return FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            m.icon,
                            size: 14,
                            color: isSelected
                                ? Colors.black
                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                          const SizedBox(width: 6),
                          Text(m.label),
                        ],
                      ),
                      selectedColor: AppColors.accent,
                      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.black
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.accent
                              : (isDark ? AppColors.borderMedium : AppColors.borderMediumLight),
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          AppHaptics.selectionClick();
                          setState(() {
                            _selectedModule = m.key;
                          });
                          _saveDraftDebounced();
                        }
                      },
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // 4. Large Idea Description
              _buildIdeaCard(
                isDark: isDark,
                title: 'Tell Us About Your Idea',
                subtitle: 'How should this feature work? Describe the workflow or interaction.',
                icon: LucideIcons.pencil,
                iconColor: AppColors.info,
                child: TextFormField(
                  controller: _descriptionController,
                  focusNode: _descFocusNode,
                  maxLines: 7,
                  minLines: 5,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  decoration: _buildInputDecoration(
                    isDark: isDark,
                    hintText:
                        'Imagine how you would use this in your daily routine. What buttons, screens, or automated behaviors would you see?',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 10) {
                      return 'Please share at least 10 characters describing your idea.';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 5. Why is this valuable? (Value & Benefit Section)
              _buildIdeaCard(
                isDark: isDark,
                title: 'Why is this valuable? (Optional)',
                subtitle: 'Who does this help, and what specific problem does it solve?',
                icon: LucideIcons.heartHandshake,
                iconColor: const Color(0xFFF472B6),
                child: TextFormField(
                  controller: _benefitController,
                  focusNode: _benefitFocusNode,
                  maxLines: 4,
                  minLines: 3,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  decoration: _buildInputDecoration(
                    isDark: isDark,
                    hintText: 'e.g. This saves 15 minutes of manual re-planning every evening...',
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 6. Stay in touch (Optional)
              _buildIdeaCard(
                isDark: isDark,
                title: 'Stay in the Loop (Optional)',
                subtitle: 'Provide your email if you’d like updates or early access to this feature.',
                icon: LucideIcons.mail,
                iconColor: AppColors.accent,
                child: TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  decoration: _buildInputDecoration(
                    isDark: isDark,
                    hintText: 'creator@example.com',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!emailRegex.hasMatch(v.trim())) {
                      return 'Please enter a valid email address.';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Payload Character Meter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Serialized Suggestion Size',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                  Text(
                    '$serializedLength / 5,000 chars',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: serializedLength > 5000
                          ? AppColors.danger
                          : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.3),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitFeatureSuggestion,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.sparkles, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Submit Suggestion',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreativeHeroBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.sparkles, color: AppColors.accent, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'FEATURE LAB',
                        style: TextStyle(
                          color: isDark ? AppColors.accent : AppColors.darkAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.heart, size: 12, color: _warmGold),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Have a great idea for Arc?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We build Arc collaboratively with our users. Propose enhancements, workflow automations, or new views.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdeaCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
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
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 14),
          child,
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
        borderSide: const BorderSide(
          color: AppColors.accent,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
