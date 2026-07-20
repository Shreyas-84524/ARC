import 'package:hive/hive.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 3)
class Transaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final String type; // Income, Expense

  @HiveField(3)
  final String category;

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final String time; // e.g. "12:30"

  @HiveField(6)
  final String notes;

  @HiveField(7)
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.time,
    required this.notes,
    required this.createdAt,
  });

  Transaction copyWith({
    String? id,
    double? amount,
    String? type,
    String? category,
    DateTime? date,
    String? time,
    String? notes,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      time: time ?? this.time,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'category': category,
      'date': date.toIso8601String(),
      'time': time,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      type: map['type'] ?? 'Expense',
      category: map['category'] ?? 'Other',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      time: map['time'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }
}
