import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utilities/responsive_layout.dart';
import 'package:arc/features/secret_notes/models/secret_note.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';
import 'package:arc/features/secret_notes/widgets/secret_note_card.dart';
import 'package:arc/features/secret_notes/widgets/secret_notes_intro_dialog.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// This dashboard operates completely offline and presents only local notes.

class SecretNotesDashboardScreen extends ConsumerStatefulWidget {
  const SecretNotesDashboardScreen({super.key});

  @override
  ConsumerState<SecretNotesDashboardScreen> createState() =>
      _SecretNotesDashboardScreenState();
}

class _SecretNotesDashboardScreenState
    extends ConsumerState<SecretNotesDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowIntroPopup();
    });
  }

  Future<void> _checkAndShowIntroPopup() async {
    final securityService = ref.read(secretNotesSecurityServiceProvider);
    final hasSeen = await securityService.hasSeenIntro();
    if (!hasSeen && mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const SecretNotesIntroDialog(),
      );
    }
  }

  void _handleLock() {
    ref.read(secretNotesSessionProvider.notifier).lock();
    context.go('/tasks');
  }

  void _openCreateNote() {
    context.push('/secret-notes/new');
  }

  void _openEditNote(SecretNote note) {
    context.push('/secret-notes/${note.id}');
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.lock,
                color: AppColors.accent,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No secret notes yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first private note.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textPrimaryLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                ),
              ),
              onPressed: _openCreateNote,
              icon: const Icon(LucideIcons.plus, size: 20),
              label: const Text(
                'Add Note',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notesAsync = ref.watch(secretNotesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secret Notes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/tasks');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Secret Notes Settings',
            icon: const Icon(LucideIcons.settings),
            onPressed: () => context.push('/secret-notes/settings'),
          ),
          IconButton(
            tooltip: 'Lock Secret Notes',
            icon: const Icon(LucideIcons.lock),
            onPressed: _handleLock,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimaryLight,
        onPressed: _openCreateNote,
        icon: const Icon(LucideIcons.plus),
        label: const Text(
          'Add Note',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveLayout.horizontalPadding(context),
              ),
              child: notesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => Center(
                  child: Text('Failed to load notes: $error'),
                ),
                data: (notes) {
                  if (notes.isEmpty) {
                    return _buildEmptyState(context, theme, isDark);
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 12, bottom: 84),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return SecretNoteCard(
                        note: note,
                        onTap: () => _openEditNote(note),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
