import 'package:flutter/foundation.dart';

@immutable
class MonthlySummary {
  final String month; // Format "yyyy-MM"
  final double monthlyBudget;
  final double totalIncome;
  final double totalExpenses;
  final double savings;
  final DateTime updatedAt;

  const MonthlySummary({
    required this.month,
    required this.monthlyBudget,
    required this.totalIncome,
    required this.totalExpenses,
    required this.savings,
    required this.updatedAt,
  });

  MonthlySummary copyWith({
    String? month,
    double? monthlyBudget,
    double? totalIncome,
    double? totalExpenses,
    double? savings,
    DateTime? updatedAt,
  }) {
    return MonthlySummary(
      month: month ?? this.month,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      savings: savings ?? this.savings,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'monthlyBudget': monthlyBudget,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'savings': savings,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MonthlySummary.fromMap(Map<String, dynamic> map) {
    return MonthlySummary(
      month: map['month'] ?? '',
      monthlyBudget: (map['monthlyBudget'] ?? 0.0).toDouble(),
      totalIncome: (map['totalIncome'] ?? 0.0).toDouble(),
      totalExpenses: (map['totalExpenses'] ?? 0.0).toDouble(),
      savings: (map['savings'] ?? 0.0).toDouble(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonthlySummary &&
        other.month == month &&
        other.monthlyBudget == monthlyBudget &&
        other.totalIncome == totalIncome &&
        other.totalExpenses == totalExpenses &&
        other.savings == savings &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      month,
      monthlyBudget,
      totalIncome,
      totalExpenses,
      savings,
      updatedAt,
    );
  }
}
