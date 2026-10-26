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

/// Dedicated diagnostic bug report screen for technical problem logging.
class BugReportScreen extends ConsumerStatefulWidget {
  const BugReportScreen({super.key});

  @override
  ConsumerState<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends ConsumerState<BugReportScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedModule = 'general';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController();
  final TextEditingController _expectedController = TextEditingController();
  final TextEditingController _actualController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descFocusNode = FocusNode();
  final FocusNode _stepsFocusNode = FocusNode();
  final FocusNode _expectedFocusNode = FocusNode();
  final FocusNode _actualFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isSubmitting = false;
  Timer? _draftDebounce;

  static const Color _diagnosticRed = Color(0xFFFF4D4F);
  static const Color _diagnosticRedDim = Color(0x22FF4D4F);

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _stepsController.addListener(_onFieldChanged);
    _expectedController.addListener(_onFieldChanged);
    _actualController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDraftAndUserEmail();
    });
  }

  Future<void> _initDraftAndUserEmail() async {
    final userContext = ref.read(userContextProvider);
    final userEmail = userContext.profile?.email;

    final draftService = ref.read(feedbackDraftServiceProvider);
    final draft = await draftService.loadDraft(FeedbackCategory.bugReport);

    if (mounted) {
      if (draft != null) {
        final payload = BugReportPayload.fromDraft(draft);
        setState(() {
          _selectedModule = payload.module;
          _titleController.text = payload.title;
          _descriptionController.text = payload.description;
          _stepsController.text = payload.stepsToReproduce;
          _expectedController.text = payload.expectedBehavior;
          _actualController.text = payload.actualBehavior;
          _emailController.text = payload.contactEmail ?? userEmail ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.fileText, color: Colors.black, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Restored your previously saved bug report draft.')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _diagnosticRed,
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
            category: FeedbackCategory.bugReport,
            module: _selectedModule,
            message: payload.toSerializedMessage(),
            contactEmail: _emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : null,
            extraFields: payload.toDraftMap(),
          );
    });
  }

  BugReportPayload _buildCurrentPayload() {
    return BugReportPayload(
      module: _selectedModule,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      stepsToReproduce: _stepsController.text.trim(),
      expectedBehavior: _expectedController.text.trim(),
      actualBehavior: _actualController.text.trim(),
      contactEmail: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
    );
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    _expectedController.dispose();
    _actualController.dispose();
    _emailController.dispose();

    _titleFocusNode.dispose();
    _descFocusNode.dispose();
    _stepsFocusNode.dispose();
    _expectedFocusNode.dispose();
    _actualFocusNode.dispose();
    _emailFocusNode.dispose();
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
        module: _selectedModule,
        message: payload.toSerializedMessage(),
        contactEmail: payload.contactEmail,
      );

      // Invalidate stream & future providers so My Feedback reflects new submission immediately
      ref.invalidate(currentUserFeedbackStreamProvider);
      ref.invalidate(currentUserFeedbackProvider);

      // Clear draft upon verified submission
      await ref.read(feedbackDraftServiceProvider).clearDraft(FeedbackCategory.bugReport);

      if (mounted) {
        _showSuccessDialog(result);
      }
    } catch (e) {
      // Preserve draft on failure
      final payload = _buildCurrentPayload();
      await ref.read(feedbackDraftServiceProvider).saveDraft(
            category: FeedbackCategory.bugReport,
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
    final message = error is String ? error : 'Unable to submit bug report. Your draft has been preserved locally.';

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
              decoration: const BoxDecoration(
                color: _diagnosticRedDim,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.bug, color: _diagnosticRed, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bug Report Submitted',
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
              'Your technical problem report has been dispatched to our engineering team for investigation.',
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
                      'Ticket: ${feedback.feedbackId.substring(0, 8)}...',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                color: _diagnosticRedDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.bug, color: _diagnosticRed, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Report a Bug',
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
              // 1. Diagnostic Banner
              _buildDiagnosticBanner(isDark),

              const SizedBox(height: 20),

              // 2. Section 01: Scope & Target Area
              _buildSectionCard(
                isDark: isDark,
                sectionNumber: '01',
                title: 'Affected Component',
                description: 'Select the module where this issue occurs.',
                icon: LucideIcons.layers,
                child: _buildModuleDropdown(isDark),
              ),

              const SizedBox(height: 16),

              // 3. Section 02: Issue Overview
              _buildSectionCard(
                isDark: isDark,
                sectionNumber: '02',
                title: 'Issue Summary',
                description: 'A brief, concise title of the malfunction.',
                icon: LucideIcons.type,
                child: TextFormField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  maxLength: 150,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _buildInputDecoration(
                    isDark: isDark,
                    hintText: 'e.g. Task reminder triggers 10 minutes late',
                    counterText: '${_titleController.text.length}/150',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please provide a short issue title.';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 4. Section 03: Problem Details
              _buildSectionCard(
                isDark: isDark,
                sectionNumber: '03',
                title: 'Problem Description',
                description: 'Describe the symptoms, error popups, or abnormal behavior.',
                icon: LucideIcons.fileWarning,
                child: TextFormField(
                  controller: _descriptionController,
                  focusNode: _descFocusNode,
                  maxLines: 4,
                  minLines: 3,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  decoration: _buildInputDecoration(
                    isDark: isDark,
                    hintText: 'Provide detailed context on what went wrong...',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 10) {
                      return 'Please enter at least 10 characters.';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 5. Section 04: Steps to Reproduce
              _buildSectionCard(
                isDark: isDark,
                sectionNumber: '04',
                title: 'Steps to Reproduce',
                description: 'Numbered steps our engineers can execute to reproduce the bug.',
                icon: LucideIcons.listOrdered,
                child: TextFormField(
                  controller: _stepsController,
                  focusNode: _stepsFocusNode,
                  maxLines: 4,
                  minLines: 3,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  decoration: _buildInputDecoration(
                    isDark: isDark,
                    hintText: '1. Open Task Manager\n2. Create recurring task\n3. Rotate device to landscape',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Steps to reproduce are required.';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 6. Section 05: Expected vs. Actual Behavior
              _buildSectionCard(
                isDark: isDark,
                sectionNumber: '05',
                title: 'Diagnostic Contrast',
                description: 'Compare what you expected against what actually occurred.',
                icon: LucideIcons.gitCompare,
                child: Column(
                  children: [
                    // Expected Behavior
                    TextFormField(
                      controller: _expectedController,
                      focusNode: _expectedFocusNode,
                      maxLines: 3,
                      minLines: 2,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                      decoration: _buildInputDecoration(
                        isDark: isDark,
                        labelText: 'Expected Behavior',
                        hintText: 'What did you expect to happen?',
                        prefixIcon: const Icon(LucideIcons.checkCircle2, color: AppColors.accent, size: 18),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Expected behavior is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Actual Behavior
                    TextFormField(
                      controller: _actualController,
                      focusNode: _actualFocusNode,
                      maxLines: 3,
                      minLines: 2,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                      decoration: _buildInputDecoration(
                        isDark: isDark,
                        labelText: 'Actual Behavior',
                        hintText: 'What actually happened?',
                        prefixIcon: const Icon(LucideIcons.xCircle, color: _diagnosticRed, size: 18),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Actual behavior is required.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 7. Section 06: Diagnostic Follow-up (Optional)
              _buildSectionCard(
                isDark: isDark,
                sectionNumber: '06',
                title: 'Follow-up Contact (Optional)',
                description: 'Email address if we need additional diagnostic traces.',
                icon: LucideIcons.mail,
                child: TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  decoration: _buildInputDecoration(
                    isDark: isDark,
                    hintText: 'engineer@example.com',
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
                    'Diagnostic Payload Size',
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
                          ? _diagnosticRed
                          : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _diagnosticRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _diagnosticRed.withValues(alpha: 0.3),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.alertOctagon, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Submit Bug Report',
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

  Widget _buildDiagnosticBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: _diagnosticRed.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _diagnosticRedDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.cpu, color: _diagnosticRed, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _diagnosticRedDim,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DIAGNOSTIC PROTOCOL',
                        style: TextStyle(
                          color: _diagnosticRed,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'v1.3.5',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMutedDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Structured Technical Defect Report',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fill in reproduction steps and behavior contrast to enable rapid root-cause isolation.',
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildSectionCard({
    required bool isDark,
    required String sectionNumber,
    required String title,
    required String description,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sectionNumber,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _diagnosticRed,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 16, color: _diagnosticRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildModuleDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBgSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        border: Border.all(
          color: isDark ? AppColors.borderMedium : AppColors.borderMediumLight,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedModule,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          items: FeedbackModuleInfo.modules.map((m) {
            return DropdownMenuItem<String>(
              value: m.key,
              child: Row(
                children: [
                  Icon(m.icon, size: 18, color: _diagnosticRed),
                  const SizedBox(width: 12),
                  Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (newVal) {
            if (newVal != null) {
              AppHaptics.selectionClick();
              setState(() {
                _selectedModule = newVal;
              });
              _saveDraftDebounced();
            }
          },
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required bool isDark,
    String? hintText,
    String? labelText,
    String? counterText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      counterText: counterText,
      prefixIcon: prefixIcon,
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
          color: _diagnosticRed,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
