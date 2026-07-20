import 'package:hive/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String priority; // High, Much, Low

  @HiveField(4)
  final String category; // Work, Personal, etc.

  @HiveField(5)
  final List<String> labels;

  @HiveField(6)
  final DateTime? dueDate;

  @HiveField(7)
  final String? dueTime; // e.g. "14:30"

  @HiveField(8)
  final DateTime? reminder;

  @HiveField(9)
  final bool completed;

  @HiveField(10)
  final DateTime createdAt;

  @HiveField(11)
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.category,
    required this.labels,
    this.dueDate,
    this.dueTime,
    this.reminder,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? priority,
    String? category,
    List<String>? labels,
    DateTime? dueDate,
    String? dueTime,
    DateTime? reminder,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      labels: labels ?? this.labels,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      reminder: reminder ?? this.reminder,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'category': category,
      'labels': labels,
      'dueDate': dueDate?.toIso8601String(),
      'dueTime': dueTime,
      'reminder': reminder?.toIso8601String(),
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      priority: map['priority'] ?? 'Low',
      category: map['category'] ?? 'Other',
      labels: List<String>.from(map['labels'] ?? []),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      dueTime: map['dueTime'],
      reminder: map['reminder'] != null ? DateTime.parse(map['reminder']) : null,
      completed: map['completed'] ?? false,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }
}
