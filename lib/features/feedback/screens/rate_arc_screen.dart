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

/// Dedicated Rating-First Interface for Arc App Reviews.
///
/// Features large interactive star components, smooth scale/bounce animations,
/// dynamic sentiment reaction cards, optional written reflections, and
/// guaranteed backend message compatibility for rating-only submissions.
class RateArcScreen extends ConsumerStatefulWidget {
  const RateArcScreen({super.key});

  @override
  ConsumerState<RateArcScreen> createState() => _RateArcScreenState();
}

class _RateArcScreenState extends ConsumerState<RateArcScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _rating;
  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final FocusNode _reviewFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isSubmitting = false;
  Timer? _draftDebounce;

  static const Color _starGold = Color(0xFFFFB800);

  @override
  void initState() {
    super.initState();
    _reviewController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initUserEmailAndDraft();
    });
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _reviewController.dispose();
    _emailController.dispose();
    _reviewFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initUserEmailAndDraft() async {
    final userContext = ref.read(userContextProvider);
    final userEmail = userContext.profile?.email;

    final draftService = ref.read(feedbackDraftServiceProvider);
    final draft = await draftService.loadDraft(FeedbackCategory.appRating);

    if (mounted) {
      if (draft != null) {
        final payload = RateArcPayload.fromDraft(draft);
        setState(() {
          if (payload.rating >= 1 && payload.rating <= 5) {
            _rating = payload.rating;
          }
          _reviewController.text = payload.writtenReview ?? '';
          _emailController.text = payload.contactEmail ?? userEmail ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.fileText, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('Restored your unsaved rating draft'),
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
    final payload = RateArcPayload(
      rating: _rating ?? 0,
      writtenReview: _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
      contactEmail: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
    );

    if (payload.rating == 0 && (payload.writtenReview == null || payload.writtenReview!.isEmpty)) {
      await draftService.clearDraft(FeedbackCategory.appRating);
    } else {
      await draftService.saveDraft(
        category: FeedbackCategory.appRating,
        module: 'general',
        message: payload.toSerializedMessage(),
        rating: payload.rating > 0 ? payload.rating : null,
        contactEmail: payload.contactEmail,
        extraFields: payload.toDraftMap(),
      );
    }
  }

  void _setRating(int stars) {
    AppHaptics.selectionClick();
    setState(() {
      _rating = stars;
    });
    _onFieldChanged();
  }

  Future<void> _submitRating() async {
    FocusScope.of(context).unfocus();

    if (_rating == null || _rating! < 1 || _rating! > 5) {
      AppHaptics.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap a star to choose a rating before submitting.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final payload = RateArcPayload(
      rating: _rating!,
      writtenReview: _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
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
        category: FeedbackCategory.appRating,
        module: payload.module,
        message: payload.toSerializedMessage(),
        rating: payload.rating,
        contactEmail: payload.contactEmail,
      );

      // Invalidate stream & future providers so My Feedback reflects new submission immediately
      ref.invalidate(currentUserFeedbackStreamProvider);
      ref.invalidate(currentUserFeedbackProvider);

      final draftService = ref.read(feedbackDraftServiceProvider);
      await draftService.clearDraft(FeedbackCategory.appRating);

      if (mounted) {
        AppHaptics.lightImpact();
        _showCelebrationDialog(submitted);
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ArgumentError ? e.message.toString() : 'Failed to submit rating. Your selection has been preserved.',
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _submitRating,
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

  Future<void> _showCelebrationDialog(FeedbackModel feedback) async {
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
                decoration: const BoxDecoration(
                  color: Color(0x33FFB800),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.award, color: _starGold, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rating Submitted!',
                  style: theme.textTheme.titleLarge?.copyWith(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final isFilled = index < (_rating ?? 0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      LucideIcons.star,
                      size: 24,
                      color: isFilled ? _starGold : (isDark ? const Color(0xFF404040) : const Color(0xFFE5E7EB)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Thank you for rating Arc! Your honest score guides our roadmap and development priorities.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.45,
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
                backgroundColor: _starGold,
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
        title: const Text('Rate Arc'),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Rating-First Hero Banner
                _buildRatingHero(theme, isDark),
                const SizedBox(height: 24),

                // Interactive 5-Star Component
                _buildStarRatingComponent(theme, isDark),
                const SizedBox(height: 20),

                // Dynamic Contextual Reaction / Sentiment Card
                _buildSentimentReactionCard(theme, isDark),
                const SizedBox(height: 24),

                // Optional Written Review Section
                _buildWrittenReviewSection(theme, isDark),
                const SizedBox(height: 20),

                // Optional Follow-up Email
                _buildContactEmailField(theme, isDark),
                const SizedBox(height: 28),

                // Submit Rating CTA
                _buildSubmitRatingButton(theme, isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingHero(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _starGold.withValues(alpha: 0.25),
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0x22FFB800),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.star, color: _starGold, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            'Your Opinion Matters',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How well is Arc helping you achieve daily momentum and focus?',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRatingComponent(ThemeData theme, bool isDark) {
    final inactiveColor = isDark ? const Color(0xFF383838) : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _rating != null ? _starGold.withValues(alpha: 0.4) : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              final isFilled = _rating != null && _rating! >= starNumber;

              return Semantics(
                button: true,
                label: '$starNumber star${starNumber > 1 ? 's' : ''}',
                selected: isFilled,
                child: InkWell(
                  onTap: () => _setRating(starNumber),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      transform: isFilled
                          ? Matrix4.diagonal3Values(1.18, 1.18, 1.0)
                          : Matrix4.identity(),
                      child: Icon(
                        LucideIcons.star,
                        size: 44,
                        color: isFilled ? _starGold : inactiveColor,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Score Pill
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(_rating),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _rating != null ? _starGold.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _rating != null ? _starGold.withValues(alpha: 0.4) : Colors.transparent,
                ),
              ),
              child: Text(
                _rating != null ? '★ $_rating.0 / 5.0' : 'Tap a star to rate',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                  color: _rating != null
                      ? _starGold
                      : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentReactionCard(ThemeData theme, bool isDark) {
    if (_rating == null) {
      return const SizedBox.shrink();
    }

    final (color, title, desc, icon) = switch (_rating) {
      5 => (
          AppColors.accent,
          'Loved it — Arc is indispensable!',
          'We\'re thrilled Arc is a vital part of your routine. Thank you for your support!',
          LucideIcons.heartHandshake,
        ),
      4 => (
          const Color(0xFF38BDF8),
          'Great — Very satisfied',
          'We\'re glad Arc is working well for you! Let us know if anything would make it a 5-star experience.',
          LucideIcons.thumbsUp,
        ),
      3 => (
          const Color(0xFFF59E0B),
          'Good — Does the job',
          'Good to know! We\'d love to learn what would make your experience even better.',
          LucideIcons.lightbulb,
        ),
      2 => (
          const Color(0xFFFB923C),
          'Fair — Missing key features',
          'We want to do better. Tell us below what felt frustrating or missing.',
          LucideIcons.wrench,
        ),
      1 => (
          AppColors.danger,
          'Poor — Needs major work',
          'We\'re really sorry Arc hasn\'t met your expectations. Please tell us what went wrong.',
          LucideIcons.alertTriangle,
        ),
      _ => (
          _starGold,
          'Rate Your Experience',
          'Select your rating above.',
          LucideIcons.star,
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWrittenReviewSection(ThemeData theme, bool isDark) {
    final hint = switch (_rating) {
      5 => 'What do you love most about using Arc? (Optional)',
      4 => 'What\'s working great, and what could be even better? (Optional)',
      3 => 'What would make Arc a 5-star tool for you? (Optional)',
      1 || 2 => 'What caused friction or fell short of expectations? (Optional)',
      _ => 'Tell us about your experience with Arc... (Optional)',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'WRITTEN REVIEW (OPTIONAL)',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            ),
            Text(
              '${_reviewController.text.length} / 4,500',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                fontFamily: 'monospace',
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
            ),
          ),
          child: TextFormField(
            controller: _reviewController,
            focusNode: _reviewFocusNode,
            minLines: 3,
            maxLines: 6,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? AppColors.textPlaceholderDark : AppColors.textPlaceholderLight,
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Written comments are completely optional. You can submit with just your star rating.',
          style: theme.textTheme.labelSmall?.copyWith(
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildContactEmailField(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitRatingButton(ThemeData theme, bool isDark) {
    final hasRating = _rating != null && _rating! >= 1 && _rating! <= 5;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasRating ? _starGold : (isDark ? const Color(0xFF383838) : const Color(0xFFD1D5DB)),
          foregroundColor: hasRating ? Colors.black : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
          elevation: hasRating ? 3 : 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: (_isSubmitting || !hasRating) ? (_isSubmitting ? null : _submitRating) : _submitRating,
        child: _isSubmitting
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.award,
                    size: 18,
                    color: hasRating ? Colors.black : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    hasRating ? 'Submit $_rating-Star Rating' : 'Tap a Star to Rate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      color: hasRating ? Colors.black : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
