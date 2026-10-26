import 'package:flutter/material.dart';
import 'package:arc/core/theme/app_theme.dart';

enum TaskPriority {
  high,
  must,
  low;

  Color get color {
    switch (this) {
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.must:
        return AppColors.priorityMust;
      case TaskPriority.low:
        return AppColors.priorityLow;
    }
  }

  String get displayName {
    switch (this) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.must:
        return 'Must';
      case TaskPriority.low:
        return 'Low';
    }
  }

  String get emoji {
    switch (this) {
      case TaskPriority.high:
        return '🔴';
      case TaskPriority.must:
        return '🟠';
      case TaskPriority.low:
        return '🟡';
    }
  }
}

enum TransactionType {
  income,
  expense;

  Color get color {
    switch (this) {
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.expense:
        return AppColors.danger;
    }
  }

  String get displayName {
    switch (this) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
    }
  }
}

class AppConstants {
  // Categories
  static const List<String> taskCategories = [
    'Work',
    'Personal',
    'Education',
    'Health',
    'Finance',
    'Social',
    'Other'
  ];
}
