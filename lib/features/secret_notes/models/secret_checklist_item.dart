import 'dart:math';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// This checklist item is strictly persisted in isolated local device storage.

class SecretChecklistItem {
  final String id;
  final String text;
  final bool isCompleted;
  final DateTime createdAt;
  final int order;

  const SecretChecklistItem({
    required this.id,
    required this.text,
    this.isCompleted = false,
    required this.createdAt,
    this.order = 0,
  });

  /// Generates a stable cryptographically unique identifier for checklist items.
  static String generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random.secure().nextInt(1000000).toString().padLeft(6, '0');
    return 'item_${timestamp}_$random';
  }

  /// Whether this item has meaningful content.
  bool get isValid => text.trim().isNotEmpty;

  SecretChecklistItem copyWith({
    String? id,
    String? text,
    bool? isCompleted,
    DateTime? createdAt,
    int? order,
  }) {
    return SecretChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'order': order,
    };
  }

  factory SecretChecklistItem.fromMap(Map<dynamic, dynamic> map) {
    return SecretChecklistItem(
      id: map['id']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      isCompleted: map['isCompleted'] == true,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      order: map['order'] is int
          ? map['order'] as int
          : int.tryParse(map['order']?.toString() ?? '0') ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecretChecklistItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          isCompleted == other.isCompleted &&
          createdAt == other.createdAt &&
          order == other.order;

  @override
  int get hashCode =>
      id.hashCode ^
      text.hashCode ^
      isCompleted.hashCode ^
      createdAt.hashCode ^
      order.hashCode;
}
