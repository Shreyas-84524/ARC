import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/core/utilities/responsive_layout.dart';
import 'package:arc/features/secret_notes/models/secret_note.dart';
import 'package:arc/features/secret_notes/models/secret_checklist_item.dart';
import 'package:arc/features/secret_notes/models/secret_note_color.dart';
import 'package:arc/features/secret_notes/models/secret_note_attachment.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// All editor persistence is strictly local and private.

class _EditableChecklistItem {
  final String id;
  final TextEditingController controller;
  final FocusNode focusNode;
  bool isCompleted;
  final DateTime createdAt;
  int order;

  _EditableChecklistItem({
    required this.id,
    required this.controller,
    required this.focusNode,
    this.isCompleted = false,
    required this.createdAt,
    this.order = 0,
  });

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class SecretNoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;

  const SecretNoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<SecretNoteEditorScreen> createState() =>
      _SecretNoteEditorScreenState();
}

class _SecretNoteEditorScreenState
    extends ConsumerState<SecretNoteEditorScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<_EditableChecklistItem> _checklistItems = [];
  final List<String> _labels = [];
  final List<SecretNoteAttachment> _attachments = [];
  final List<SecretNoteAttachment> _pendingAttachmentDeletes = [];
  late final String _draftId = widget.noteId ?? SecretNote.generateId();

  String _selectedColorId = SecretNoteColors.defaultColorId;
  DateTime? _createdAt;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isNewNote = true;
  bool _showChecklistSection = false;
  bool _isRecording = false;
  bool _isAddingMedia = false;
  String? _recordingPath;
  String? _playingAudioPath;
  Timer? _playbackTimer;

  // Snapshot for unsaved changes detection
  String _initialTitle = '';
  String _initialDescription = '';
  String _initialColorId = SecretNoteColors.defaultColorId;
  List<Map<String, dynamic>> _initialChecklistSnapshot = [];
  List<String> _initialLabels = [];
  List<String> _initialAttachmentIds = [];

  @override
  void initState() {
    super.initState();
    _loadNoteData();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    for (final item in _checklistItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadNoteData() async {
    final id = widget.noteId;
    if (id == null || id.isEmpty) {
      setState(() {
        _isNewNote = true;
        _isLoading = false;
        _createdAt = DateTime.now();
        _captureInitialSnapshot();
      });
      return;
    }

    final repo = ref.read(secretNotesDataRepositoryProvider);
    final note = await repo.getNoteById(id);

    if (!mounted) return;

    if (note != null) {
      setState(() {
        _isNewNote = false;
        _titleController.text = note.title;
        _descriptionController.text = note.description;
        _selectedColorId = note.color;
        _createdAt = note.createdAt;
        _labels
          ..clear()
          ..addAll(note.labels);
        _attachments
          ..clear()
          ..addAll(note.attachments);

        _checklistItems.clear();
        for (var i = 0; i < note.checklist.length; i++) {
          final item = note.checklist[i];
          _checklistItems.add(
            _EditableChecklistItem(
              id: item.id,
              controller: TextEditingController(text: item.text),
              focusNode: FocusNode(),
              isCompleted: item.isCompleted,
              createdAt: item.createdAt,
              order: item.order,
            ),
          );
        }
        if (_checklistItems.isNotEmpty) {
          _showChecklistSection = true;
        }

        _isLoading = false;
        _captureInitialSnapshot();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note not found'),
          duration: Duration(seconds: 2),
        ),
      );
      _returnToDashboard();
    }
  }

  void _returnToDashboard() {
    ref.read(secretNotesMediaServiceProvider).stopAudio();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.go('/secret-notes');
      }
    }
  }

  void _captureInitialSnapshot() {
    _initialTitle = _titleController.text.trim();
    _initialDescription = _descriptionController.text.trim();
    _initialColorId = _selectedColorId;
    _initialChecklistSnapshot = _checklistItems
        .map(
          (item) => {
            'id': item.id,
            'text': item.controller.text.trim(),
            'isCompleted': item.isCompleted,
          },
        )
        .toList();
    _initialLabels = List.of(_labels);
    _initialAttachmentIds = _attachments.map((item) => item.id).toList();
  }

  bool _hasUnsavedChanges() {
    if (_titleController.text.trim() != _initialTitle) return true;
    if (_descriptionController.text.trim() != _initialDescription) return true;
    if (_selectedColorId != _initialColorId) return true;
    if (!_stringListsEqual(_labels, _initialLabels)) return true;
    if (!_stringListsEqual(
      _attachments.map((item) => item.id).toList(),
      _initialAttachmentIds,
    )) {
      return true;
    }

    final currentItems = _checklistItems
        .map(
          (item) => {
            'id': item.id,
            'text': item.controller.text.trim(),
            'isCompleted': item.isCompleted,
          },
        )
        .toList();

    if (currentItems.length != _initialChecklistSnapshot.length) return true;

    for (var i = 0; i < currentItems.length; i++) {
      final cur = currentItems[i];
      final init = _initialChecklistSnapshot[i];
      if (cur['id'] != init['id'] ||
          cur['text'] != init['text'] ||
          cur['isCompleted'] != init['isCompleted']) {
        return true;
      }
    }

    return false;
  }

  bool _stringListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _addLabel() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Personal, Ideas'),
          onSubmitted: (text) => Navigator.pop(dialogContext, text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    final label = value?.trim();
    if (label == null || label.isEmpty || !mounted) return;
    if (_labels.any((item) => item.toLowerCase() == label.toLowerCase())) {
      return;
    }
    setState(() => _labels.add(label));
  }

  Future<void> _addImage() async {
    if (_isAddingMedia) return;
    setState(() => _isAddingMedia = true);
    try {
      final attachment = await ref
          .read(secretNotesMediaServiceProvider)
          .pickImage(_draftId);
      if (attachment != null && mounted) {
        setState(() => _attachments.add(attachment));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add that image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingMedia = false);
    }
  }

  Future<void> _toggleRecording() async {
    final media = ref.read(secretNotesMediaServiceProvider);
    try {
      if (_isRecording) {
        final path = _recordingPath;
        if (path == null) return;
        final attachment = await media.stopRecording(path);
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _recordingPath = null;
          if (attachment != null) _attachments.add(attachment);
        });
      } else {
        final path = await media.startRecording(_draftId);
        if (mounted) {
          setState(() {
            _isRecording = true;
            _recordingPath = path;
          });
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordingPath = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Voice note unavailable: $error')));
    }
  }

  Future<void> _toggleAudio(SecretNoteAttachment attachment) async {
    final media = ref.read(secretNotesMediaServiceProvider);
    try {
      if (_playingAudioPath == attachment.localPath) {
        _playbackTimer?.cancel();
        await media.pauseAudio();
        if (mounted) setState(() => _playingAudioPath = null);
      } else {
        await media.playAudio(attachment.localPath);
        if (mounted) {
          setState(() => _playingAudioPath = attachment.localPath);
          _playbackTimer?.cancel();
          if (attachment.durationMs > 0) {
            _playbackTimer = Timer(
              Duration(milliseconds: attachment.durationMs),
              () {
                if (mounted && _playingAudioPath == attachment.localPath) {
                  setState(() => _playingAudioPath = null);
                }
              },
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This voice note could not be played.')),
        );
      }
    }
  }

  Future<void> _removeAttachment(SecretNoteAttachment attachment) async {
    if (mounted) {
      setState(() {
        _attachments.remove(attachment);
        _pendingAttachmentDeletes.add(attachment);
      });
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges()) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Discard changes?'),
          content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Editing'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );

    return discard == true;
  }

  void _addChecklistItem([String initialText = '']) {
    setState(() {
      _showChecklistSection = true;
      final newItem = _EditableChecklistItem(
        id: SecretChecklistItem.generateId(),
        controller: TextEditingController(text: initialText),
        focusNode: FocusNode(),
        isCompleted: false,
        createdAt: DateTime.now(),
        order: _checklistItems.length,
      );
      _checklistItems.add(newItem);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (newItem.focusNode.canRequestFocus) {
          newItem.focusNode.requestFocus();
        }
      });
    });
  }

  void _removeChecklistItem(int index) {
    setState(() {
      final removed = _checklistItems.removeAt(index);
      removed.dispose();
      // Re-index remaining
      for (var i = 0; i < _checklistItems.length; i++) {
        _checklistItems[i].order = i;
      }
    });
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final trimmedTitle = _titleController.text.trim();
    final trimmedDescription = _descriptionController.text.trim();

    // Clean up empty checklist items before validation and saving
    final List<SecretChecklistItem> validChecklist = [];
    for (var i = 0; i < _checklistItems.length; i++) {
      final item = _checklistItems[i];
      final itemText = item.controller.text.trim();
      if (itemText.isNotEmpty) {
        validChecklist.add(
          SecretChecklistItem(
            id: item.id,
            text: itemText,
            isCompleted: item.isCompleted,
            createdAt: item.createdAt,
            order: i,
          ),
        );
      }
    }

    if (!SecretNote.isValidContent(
      title: trimmedTitle,
      description: trimmedDescription,
      checklist: validChecklist,
      attachments: _attachments,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Note cannot be empty. Add text, a checklist item, an image, or a voice note.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final id = _draftId;
      final createdAt = _createdAt ?? now;

      final note = SecretNote(
        id: id,
        title: trimmedTitle,
        description: trimmedDescription,
        color: _selectedColorId,
        checklist: validChecklist,
        labels: List.unmodifiable(_labels),
        attachments: List.unmodifiable(_attachments),
        createdAt: createdAt,
        updatedAt: now,
      );

      await ref.read(secretNotesListProvider.notifier).saveNote(note);

      for (final attachment in _pendingAttachmentDeletes) {
        await ref
            .read(secretNotesMediaServiceProvider)
            .deleteAttachment(attachment);
      }
      _pendingAttachmentDeletes.clear();

      _captureInitialSnapshot();

      if (mounted) {
        _returnToDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save secret note.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    final id = widget.noteId;
    if (id == null || id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Delete this secret note?'),
          content: const Text(
            'This note will be permanently removed from this device. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      for (final attachment in _attachments) {
        await ref
            .read(secretNotesMediaServiceProvider)
            .deleteAttachment(attachment);
      }
      await ref.read(secretNotesListProvider.notifier).deleteNote(id);
      if (mounted) {
        _returnToDashboard();
      }
    }
  }

  Future<void> _handleBackPress() async {
    if (_isRecording) await _toggleRecording();
    final canLeave = await _confirmDiscardChanges();
    if (canLeave && mounted) {
      final initialIds = _initialAttachmentIds.toSet();
      for (final attachment in _attachments) {
        if (!initialIds.contains(attachment.id)) {
          await ref
              .read(secretNotesMediaServiceProvider)
              .deleteAttachment(attachment);
        }
      }
      _returnToDashboard();
    }
  }

  Widget _buildColorSelector(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: SecretNoteColors.palette.map((colorOpt) {
          final isSelected = colorOpt.id == _selectedColorId;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() => _selectedColorId = colorOpt.id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorOpt.backgroundColor(isDark),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? colorOpt.dotColor
                        : colorOpt.borderColor(isDark),
                    width: isSelected ? 2.5 : 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colorOpt.dotColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        LucideIcons.check,
                        size: 18,
                        color: colorOpt.dotColor,
                      )
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChecklistSection(ThemeData theme, bool isDark) {
    final pendingItems = _checklistItems.where((i) => !i.isCompleted).toList();
    final completedItems = _checklistItems.where((i) => i.isCompleted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Checklist',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            TextButton.icon(
              onPressed: () => _addChecklistItem(),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add item'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...pendingItems.map(
          (item) => _buildChecklistItemRow(item, theme, isDark),
        ),
        if (completedItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Completed (${completedItems.length})',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark
                  ? AppColors.textMutedDark
                  : AppColors.textMutedLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ...completedItems.map(
            (item) => _buildChecklistItemRow(item, theme, isDark),
          ),
        ],
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _addChecklistItem(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  LucideIcons.plus,
                  size: 18,
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight,
                ),
                const SizedBox(width: 12),
                Text(
                  'List item',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItemRow(
    _EditableChecklistItem item,
    ThemeData theme,
    bool isDark,
  ) {
    final index = _checklistItems.indexOf(item);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              item.isCompleted ? LucideIcons.checkSquare : LucideIcons.square,
              size: 20,
              color: item.isCompleted
                  ? AppColors.accent
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            ),
            onPressed: () {
              setState(() {
                item.isCompleted = !item.isCompleted;
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: item.controller,
              focusNode: item.focusNode,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: item.isCompleted
                    ? (isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight)
                    : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
                decoration: item.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
              decoration: InputDecoration(
                hintText: 'Item...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                _addChecklistItem();
              },
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              LucideIcons.x,
              size: 18,
              color: isDark
                  ? AppColors.textMutedDark
                  : AppColors.textMutedLight,
            ),
            onPressed: () => _removeChecklistItem(index),
          ),
        ],
      ),
    );
  }

  Widget _buildLabels(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._labels.map(
          (label) => InputChip(
            avatar: const Icon(LucideIcons.tag, size: 14),
            label: Text(label),
            onDeleted: () => setState(() => _labels.remove(label)),
          ),
        ),
        ActionChip(
          avatar: const Icon(LucideIcons.plus, size: 15),
          label: const Text('Label'),
          onPressed: _addLabel,
        ),
      ],
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildAttachments(ThemeData theme, bool isDark) {
    if (_attachments.isEmpty && !_isRecording) return const SizedBox.shrink();
    final images = _attachments
        .where((item) => item.type == SecretNoteAttachmentType.image)
        .toList();
    final audio = _attachments
        .where((item) => item.type == SecretNoteAttachmentType.audio)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        if (_isRecording)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.mic, color: AppColors.danger),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Recording… tap the microphone to finish'),
                ),
              ],
            ),
          ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final attachment = images[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(attachment.localPath),
                        width: 190,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 190,
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          child: const Center(
                            child: Icon(LucideIcons.imageOff),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Remove image',
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () => _removeAttachment(attachment),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        if (audio.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...audio.map(
            (attachment) => Card(
              elevation: 0,
              child: ListTile(
                leading: IconButton.filledTonal(
                  tooltip: _playingAudioPath == attachment.localPath
                      ? 'Pause'
                      : 'Play',
                  icon: Icon(
                    _playingAudioPath == attachment.localPath
                        ? LucideIcons.pause
                        : LucideIcons.play,
                  ),
                  onPressed: () => _toggleAudio(attachment),
                ),
                title: Text(
                  attachment.name.isEmpty ? 'Voice note' : attachment.name,
                ),
                subtitle: Text(_formatDuration(attachment.durationMs)),
                trailing: IconButton(
                  tooltip: 'Remove voice note',
                  icon: const Icon(LucideIcons.trash2),
                  onPressed: () => _removeAttachment(attachment),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentColor = SecretNoteColors.getById(_selectedColorId);
    final screenBg = currentColor.backgroundColor(isDark);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: screenBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _isNewNote ? 'New Secret Note' : 'Edit Secret Note',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: _handleBackPress,
          ),
          actions: [
            IconButton(
              icon: Icon(
                _showChecklistSection
                    ? LucideIcons.checkSquare
                    : LucideIcons.listPlus,
              ),
              tooltip: _showChecklistSection
                  ? 'Checklist Active'
                  : 'Add Checklist',
              onPressed: () {
                if (!_showChecklistSection) {
                  _addChecklistItem();
                } else {
                  setState(
                    () => _showChecklistSection = !_showChecklistSection,
                  );
                }
              },
            ),
            if (!_isNewNote)
              IconButton(
                icon: const Icon(LucideIcons.trash2),
                tooltip: 'Delete Note',
                color: AppColors.danger,
                onPressed: _isSaving ? null : _handleDelete,
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textPrimaryLight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textPrimaryLight,
                        ),
                      )
                    : const Icon(LucideIcons.check, size: 18),
                label: Text(_isSaving ? 'Saving' : 'Save'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveLayout.horizontalPadding(context),
                ),
                child: Column(
                  children: [
                    _buildColorSelector(isDark),
                    const Divider(height: 1),
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: _isAddingMedia ? null : _addImage,
                            icon: const Icon(LucideIcons.imagePlus, size: 18),
                            label: const Text('Image'),
                          ),
                          TextButton.icon(
                            onPressed: _toggleRecording,
                            icon: Icon(
                              _isRecording
                                  ? LucideIcons.square
                                  : LucideIcons.mic,
                              size: 18,
                              color: _isRecording ? AppColors.danger : null,
                            ),
                            label: Text(_isRecording ? 'Stop' : 'Voice'),
                          ),
                          TextButton.icon(
                            onPressed: _addLabel,
                            icon: const Icon(LucideIcons.tag, size: 18),
                            label: const Text('Label'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _titleController,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Title',
                                hintStyle: theme.textTheme.headlineSmall
                                    ?.copyWith(
                                      color: isDark
                                          ? AppColors.textMutedDark
                                          : AppColors.textMutedLight,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              textInputAction: TextInputAction.next,
                              maxLines: null,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _descriptionController,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Note content...',
                                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                  color: isDark
                                      ? AppColors.textMutedDark
                                      : AppColors.textMutedLight,
                                  height: 1.5,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              keyboardType: TextInputType.multiline,
                              maxLines: null,
                            ),
                            const SizedBox(height: 14),
                            _buildLabels(theme),
                            _buildAttachments(theme, isDark),
                            if (_showChecklistSection) ...[
                              _buildChecklistSection(theme, isDark),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
