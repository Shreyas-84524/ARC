import 'package:hive/hive.dart';

part 'habit_model.g.dart';

@HiveType(typeId: 1)
class Habit extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String goalType; // Daily, Weekly, Monthly

  @HiveField(3)
  final String category;

  @HiveField(4)
  final int colorValue; // ARGB value

  @HiveField(5)
  final String? reminderTime; // e.g. "08:00"

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  Habit({
    required this.id,
    required this.name,
    required this.goalType,
    required this.category,
    required this.colorValue,
    this.reminderTime,
    required this.createdAt,
    required this.updatedAt,
  });

  Habit copyWith({
    String? id,
    String? name,
    String? goalType,
    String? category,
    int? colorValue,
    String? reminderTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      goalType: goalType ?? this.goalType,
      category: category ?? this.category,
      colorValue: colorValue ?? this.colorValue,
      reminderTime: reminderTime ?? this.reminderTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'goalType': goalType,
      'category': category,
      'colorValue': colorValue,
      'reminderTime': reminderTime,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      goalType: map['goalType'] ?? 'Daily',
      category: map['category'] ?? 'Other',
      colorValue: map['colorValue'] ?? 0xffffffff,
      reminderTime: map['reminderTime'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }
}
