import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:arc/features/secret_notes/models/secret_checklist_item.dart';
import 'package:arc/features/secret_notes/models/secret_note_attachment.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// This model is strictly persisted in isolated local device storage.

class SecretNote {
  final String id;
  final String title;
  final String description;
  final String color;
  final List<SecretChecklistItem> checklist;
  final List<String> labels;
  final List<SecretNoteAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SecretNote({
    required this.id,
    this.title = '',
    this.description = '',
    this.color = 'default',
    this.checklist = const [],
    this.labels = const [],
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Generates a stable cryptographically unique identifier.
  static String generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random.secure().nextInt(1000000).toString().padLeft(6, '0');
    return 'note_${timestamp}_$random';
  }

  /// Validates whether a note contains meaningful content.
  /// A note is valid if title OR description OR at least one checklist item contains non-whitespace text.
  static bool isValidContent({
    required String title,
    required String description,
    List<SecretChecklistItem>? checklist,
    List<String>? labels,
    List<SecretNoteAttachment>? attachments,
  }) {
    if (title.trim().isNotEmpty) return true;
    if (description.trim().isNotEmpty) return true;
    if (checklist != null && checklist.any((item) => item.isValid)) return true;
    if (attachments != null && attachments.any((item) => item.isValid)) {
      return true;
    }
    return false;
  }

  /// Instance property to check validity.
  bool get isValid => isValidContent(
    title: title,
    description: description,
    checklist: checklist,
    attachments: attachments,
  );

  SecretNote copyWith({
    String? id,
    String? title,
    String? description,
    String? color,
    List<SecretChecklistItem>? checklist,
    List<String>? labels,
    List<SecretNoteAttachment>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SecretNote(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      color: color ?? this.color,
      checklist: checklist ?? this.checklist,
      labels: labels ?? this.labels,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'color': color,
      'checklist': checklist.map((item) => item.toMap()).toList(),
      'labels': labels,
      'attachments': attachments.map((item) => item.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SecretNote.fromMap(Map<dynamic, dynamic> map) {
    final List<SecretChecklistItem> checklistItems = [];
    final List<SecretNoteAttachment> attachmentItems = [];
    final rawChecklist = map['checklist'];

    if (rawChecklist is List) {
      for (final item in rawChecklist) {
        try {
          if (item is Map) {
            checklistItems.add(SecretChecklistItem.fromMap(item));
          }
        } catch (e) {
          // Gracefully skip single corrupted checklist item without breaking the note
          debugPrint('Secret Notes: skipped corrupted checklist item: $e');
        }
      }
    }

    final rawAttachments = map['attachments'];
    if (rawAttachments is List) {
      for (final item in rawAttachments) {
        if (item is Map) {
          final attachment = SecretNoteAttachment.fromMap(item);
          if (attachment.isValid) attachmentItems.add(attachment);
        }
      }
    }

    final labels = <String>[];
    final rawLabels = map['labels'];
    if (rawLabels is List) {
      for (final label in rawLabels) {
        final value = label.toString().trim();
        if (value.isNotEmpty && !labels.contains(value)) labels.add(value);
      }
    }

    return SecretNote(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      color: map['color']?.toString() ?? 'default',
      checklist: List.unmodifiable(checklistItems),
      labels: List.unmodifiable(labels),
      attachments: List.unmodifiable(attachmentItems),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecretNote &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          color == other.color &&
          listEquals(checklist, other.checklist) &&
          listEquals(labels, other.labels) &&
          listEquals(attachments, other.attachments) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      color.hashCode ^
      Object.hashAll(checklist) ^
      Object.hashAll(labels) ^
      Object.hashAll(attachments) ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
