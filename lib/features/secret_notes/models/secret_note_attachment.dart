import 'dart:math';

enum SecretNoteAttachmentType { image, audio }

class SecretNoteAttachment {
  final String id;
  final SecretNoteAttachmentType type;
  final String localPath;
  final String name;
  final int durationMs;
  final DateTime createdAt;

  const SecretNoteAttachment({
    required this.id,
    required this.type,
    required this.localPath,
    required this.name,
    this.durationMs = 0,
    required this.createdAt,
  });

  static String generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random.secure().nextInt(1000000).toString().padLeft(6, '0');
    return 'attachment_${timestamp}_$random';
  }

  bool get isValid => id.isNotEmpty && localPath.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'localPath': localPath,
    'name': name,
    'durationMs': durationMs,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SecretNoteAttachment.fromMap(Map<dynamic, dynamic> map) {
    final typeName = map['type']?.toString();
    final type = SecretNoteAttachmentType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => SecretNoteAttachmentType.image,
    );
    return SecretNoteAttachment(
      id: map['id']?.toString() ?? '',
      type: type,
      localPath: map['localPath']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Attachment',
      durationMs: map['durationMs'] is num
          ? (map['durationMs'] as num).toInt()
          : int.tryParse(map['durationMs']?.toString() ?? '') ?? 0,
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SecretNoteAttachment &&
      id == other.id &&
      type == other.type &&
      localPath == other.localPath &&
      name == other.name &&
      durationMs == other.durationMs &&
      createdAt == other.createdAt;

  @override
  int get hashCode =>
      Object.hash(id, type, localPath, name, durationMs, createdAt);
}
