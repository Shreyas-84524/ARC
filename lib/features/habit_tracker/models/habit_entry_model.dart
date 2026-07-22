import 'package:hive/hive.dart';

part 'habit_entry_model.g.dart';

@HiveType(typeId: 2)
class HabitEntry extends HiveObject {
  @HiveField(0)
  final String id; // Formatted as "habitId_dateStr" (e.g. "uuid_2026-07-20")

  @HiveField(1)
  final String habitId;

  @HiveField(2)
  final String dateStr; // Format "yyyy-MM-dd"

  @HiveField(3)
  final bool completed;

  HabitEntry({
    required this.id,
    required this.habitId,
    required this.dateStr,
    required this.completed,
  });

  HabitEntry copyWith({
    String? id,
    String? habitId,
    String? dateStr,
    bool? completed,
  }) {
    return HabitEntry(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      dateStr: dateStr ?? this.dateStr,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      'dateStr': dateStr,
      'completed': completed,
    };
  }

  factory HabitEntry.fromMap(Map<String, dynamic> map) {
    return HabitEntry(
      id: map['id'] ?? '',
      habitId: map['habitId'] ?? '',
      dateStr: map['dateStr'] ?? '',
      completed: map['completed'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HabitEntry &&
        other.id == id &&
        other.habitId == habitId &&
        other.dateStr == dateStr &&
        other.completed == completed;
  }

  @override
  int get hashCode {
    return Object.hash(id, habitId, dateStr, completed);
  }
}
