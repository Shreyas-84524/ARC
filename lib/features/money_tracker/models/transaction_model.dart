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

  @HiveField(8)
  final String source; // 'manual', 'sms_auto'

  @HiveField(9)
  final String? automationFingerprint;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.time,
    required this.notes,
    required this.createdAt,
    this.source = 'manual',
    this.automationFingerprint,
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
    String? source,
    String? automationFingerprint,
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
      source: source ?? this.source,
      automationFingerprint: automationFingerprint ?? this.automationFingerprint,
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
      'source': source,
      'automationFingerprint': automationFingerprint,
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
      source: map['source'] ?? 'manual',
      automationFingerprint: map['automationFingerprint'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id &&
        other.amount == amount &&
        other.type == type &&
        other.category == category &&
        other.date == date &&
        other.time == time &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.source == source &&
        other.automationFingerprint == automationFingerprint;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      amount,
      type,
      category,
      date,
      time,
      notes,
      createdAt,
      source,
      automationFingerprint,
    );
  }
}
