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
import 'package:arc/features/feedback/widgets/star_rating_input.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';

class FeedbackFormScreen extends ConsumerStatefulWidget {
  final String? initialCategory;

  const FeedbackFormScreen({
    super.key,
    this.initialCategory,
  });

  @override
  ConsumerState<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends ConsumerState<FeedbackFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedCategory;
  String _selectedModule = 'general';
  int? _rating;

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final FocusNode _messageFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isSubmitting = false;
  Timer? _draftDebounce;

  static const int _maxMessageChars = 5000;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? FeedbackCategory.generalFeedback;
    if (!FeedbackCategory.isValid(_selectedCategory)) {
      _selectedCategory = FeedbackCategory.generalFeedback;
    }

    _messageController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);

    // Populate initial email from current user context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initUserEmailAndDraft();
    });
  }

  Future<void> _initUserEmailAndDraft() async {
    final userContext = ref.read(userContextProvider);
    final userEmail = userContext.profile?.email;

    final draftService = ref.read(feedbackDraftServiceProvider);
    final draft = await draftService.loadDraft(_selectedCategory);

    if (mounted) {
      if (draft != null) {
        setState(() {
          _selectedModule = (draft['module'] as String?) ?? 'general';
          _messageController.text = (draft['message'] as String?) ?? '';
          _rating = (draft['rating'] as num?)?.toInt();
          _emailController.text = (draft['contactEmail'] as String?) ?? userEmail ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.fileText, color: Colors.black, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Restored your previously saved draft.')),
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
    setState(() {}); // Updates live character counter & submit button enabled state
    _saveDraftDebounced();
  }

  void _saveDraftDebounced() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      ref.read(feedbackDraftServiceProvider).saveDraft(
            category: _selectedCategory,
            module: _selectedModule,
            message: _messageController.text,
            rating: _rating,
            contactEmail: _emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : null,
          );
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

  void _onCategoryChanged(String newCategory) async {
    if (newCategory == _selectedCategory) return;
    AppHaptics.selectionClick();

    // Save existing draft for current category before switching
    await ref.read(feedbackDraftServiceProvider).saveDraft(
          category: _selectedCategory,
          module: _selectedModule,
          message: _messageController.text,
          rating: _rating,
          contactEmail: _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
        );

    setState(() {
      _selectedCategory = newCategory;
    });

    // Check if new category has a draft
    final draft = await ref.read(feedbackDraftServiceProvider).loadDraft(newCategory);
    if (mounted) {
      if (draft != null) {
        setState(() {
          _selectedModule = (draft['module'] as String?) ?? 'general';
          _messageController.text = (draft['message'] as String?) ?? '';
          _rating = (draft['rating'] as num?)?.toInt();
          if (draft['contactEmail'] != null) {
            _emailController.text = draft['contactEmail'];
          }
        });
      } else {
        // Reset category-specific message
        setState(() {
          _messageController.clear();
          if (newCategory != FeedbackCategory.appRating) {
            _rating = null;
          }
        });
      }
    }
  }

  bool get _canSubmit {
    if (_isSubmitting) return false;
    final message = _messageController.text.trim();
    if (message.isEmpty || message.length > _maxMessageChars) return false;

    // Rate Arc category requires at least 1 star
    if (_selectedCategory == FeedbackCategory.appRating && _rating == null) {
      return false;
    }

    return true;
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;
    if (!_formKey.currentState!.validate()) return;

    // Unfocus keyboard
    FocusScope.of(context).unfocus();
    AppHaptics.mediumImpact();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(feedbackRepositoryProvider);

      final contactEmail = _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null;

      final submittedFeedback = await repository.submitFeedback(
        category: _selectedCategory,
        module: _selectedModule,
        message: _messageController.text.trim(),
        rating: _rating,
        contactEmail: contactEmail,
      );

      // Invalidate stream & future providers so My Feedback reflects new submission immediately
      ref.invalidate(currentUserFeedbackStreamProvider);
      ref.invalidate(currentUserFeedbackProvider);

      // Clear local draft on confirmed acceptance by Firestore
      await ref.read(feedbackDraftServiceProvider).clearDraft(_selectedCategory);

      if (!mounted) return;

      AppHaptics.heavyImpact();
      _showSuccessDialog(submittedFeedback);
    } catch (e) {
      if (!mounted) return;

      // Preserving draft locally on failure
      await ref.read(feedbackDraftServiceProvider).saveDraft(
            category: _selectedCategory,
            module: _selectedModule,
            message: _messageController.text,
            rating: _rating,
            contactEmail: _emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : null,
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
              child: const Icon(LucideIcons.check, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Feedback Received',
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
              'Thank you for helping us refine Project Arc. Your submission has been securely recorded.',
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
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Submitted',
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
              Navigator.of(ctx).pop(); // Dismiss dialog
              context.pop(); // Return to previous screen
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pushReplacement('/feedback/my-feedback');
            },
            child: const Text('View My Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorNotice(dynamic error) {
    final errorString = error.toString().toLowerCase();
    final isNetworkOrOffline = errorString.contains('network') ||
        errorString.contains('unavailable') ||
        errorString.contains('offline') ||
        errorString.contains('socket');

    final message = isNetworkOrOffline
        ? 'You appear to be offline. Your feedback has been safely preserved as a local draft on your device.'
        : 'Could not send feedback at this time. Your draft is preserved so you can retry shortly.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isNetworkOrOffline ? AppColors.warning : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoryInfo = FeedbackCategoryInfo.forCategory(_selectedCategory);

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
          'Help & Feedback',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. Category Switcher Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: FeedbackCategoryInfo.categories.map((cat) {
                    final isSelected = cat.category == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat.icon,
                              size: 16,
                              color: isSelected
                                  ? Colors.black
                                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            ),
                            const SizedBox(width: 6),
                            Text(cat.title),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.accent,
                        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        labelStyle: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Colors.black
                              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.accent
                                : (isDark ? AppColors.borderMedium : AppColors.borderMediumLight),
                          ),
                        ),
                        onSelected: (_) => _onCategoryChanged(cat.category),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Category Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(
                    color: categoryInfo.getColor(isDark).withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: categoryInfo.getColor(isDark).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        categoryInfo.icon,
                        color: categoryInfo.getColor(isDark),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryInfo.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            categoryInfo.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Star Rating Section (Featured prominently if Rate Arc)
              if (_selectedCategory == FeedbackCategory.appRating) ...[
                Text(
                  'Rate Your Experience',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    child: StarRatingInput(
                      rating: _rating,
                      isRequired: true,
                      onRatingChanged: (val) {
                        setState(() => _rating = val);
                        _saveDraftDebounced();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 4. App Module Selector
              Text(
                'Related Module',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                  border: Border.all(
                    color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedModule,
                    isExpanded: true,
                    dropdownColor: isDark ? AppColors.darkElevated : AppColors.lightCard,
                    icon: const Icon(LucideIcons.chevronDown, size: 20),
                    borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                    items: FeedbackModuleInfo.modules.map((m) {
                      return DropdownMenuItem<String>(
                        value: m.key,
                        child: Row(
                          children: [
                            Icon(
                              m.icon,
                              size: 18,
                              color: isDark ? AppColors.accent : AppColors.darkAccent,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              m.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        AppHaptics.selectionClick();
                        setState(() => _selectedModule = val);
                        _saveDraftDebounced();
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 5. Star Rating for Non-Rate Arc Categories (Optional)
              if (_selectedCategory != FeedbackCategory.appRating) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Feature Rating',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Optional',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: StarRatingInput(
                      rating: _rating,
                      isRequired: false,
                      onRatingChanged: (val) {
                        setState(() => _rating = val);
                        _saveDraftDebounced();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 6. Feedback Narrative Field
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCategory == FeedbackCategory.bugReport
                        ? 'Bug Description & Steps'
                        : _selectedCategory == FeedbackCategory.featureRequest
                            ? 'Feature Concept & Details'
                            : 'Feedback Message',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    '${_messageController.text.length}/$_maxMessageChars',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _messageController.text.length > _maxMessageChars
                          ? AppColors.danger
                          : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                      fontWeight: _messageController.text.length > _maxMessageChars
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                minLines: 5,
                maxLines: 10,
                maxLength: _maxMessageChars,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: _selectedCategory == FeedbackCategory.bugReport
                      ? 'What happened? What did you expect instead? Please share reproduction steps...'
                      : _selectedCategory == FeedbackCategory.featureRequest
                          ? 'Describe the new feature or enhancement you would love to see in Arc...'
                          : _selectedCategory == FeedbackCategory.appRating
                              ? 'Tell us what you love most about Arc or what we can do better...'
                              : 'Tell us your thoughts, ideas or observations...',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.textPlaceholderDark : AppColors.textPlaceholderLight,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  contentPadding: const EdgeInsets.all(18),
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
                      width: 1.8,
                    ),
                  ),
                ),
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Please enter your feedback message.';
                  }
                  if (text.length > _maxMessageChars) {
                    return 'Message cannot exceed $_maxMessageChars characters.';
                  }
                  if (_selectedCategory == FeedbackCategory.bugReport && text.length < 10) {
                    return 'Please provide a bit more detail (at least 10 characters).';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // 7. Optional Contact Email Field
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contact Email',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'Optional',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(LucideIcons.mail, size: 20),
                  hintText: 'yourname@example.com',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.textPlaceholderDark : AppColors.textPlaceholderLight,
                  ),
                  helperText: 'We may reach out if we need reproduction details or updates.',
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      width: 1.8,
                    ),
                  ),
                ),
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailRegex.hasMatch(text)) {
                    return 'Please enter a valid email address.';
                  }
                  if (text.length > 254) {
                    return 'Email address is too long.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // 8. Submit Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: (isDark ? AppColors.darkCard : AppColors.lightBgSecondary),
                    disabledForegroundColor: (isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    ),
                  ),
                  onPressed: _canSubmit ? _handleSubmit : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.send, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Submit Feedback',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
