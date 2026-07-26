import 'package:flutter/material.dart';
import 'package:arc/core/theme/app_theme.dart';

enum TaskPriority {
  high,
  much,
  low;

  Color get color {
    switch (this) {
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.much:
        return AppColors.priorityMuch;
      case TaskPriority.low:
        return AppColors.priorityLow;
    }
  }

  String get displayName {
    switch (this) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.much:
        return 'Much';
      case TaskPriority.low:
        return 'Low';
    }
  }

  String get emoji {
    switch (this) {
      case TaskPriority.high:
        return '🔴';
      case TaskPriority.much:
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
  static const double gridUnit = 8.0;

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

  static const List<String> habitCategories = [
    'Fitness',
    'Mind',
    'Work',
    'Study',
    'Finance',
    'Routine',
    'Other'
  ];

  static const List<String> moneyCategories = [
    'Food',
    'Shopping',
    'Fuel',
    'Travel',
    'Entertainment',
    'Bills',
    'Health',
    'Education',
    'Salary',
    'Freelancing',
    'Investment',
    'Other'
  ];

  static const List<Color> habitColors = [
    Color(0xffD7FF2F), // Neon Lime
    Color(0xffFF4D4F), // Red
    Color(0xffFF9F43), // Orange
    Color(0xffFFD93D), // Yellow
    Color(0xff5AA9FF), // Blue
    Color(0xff7DFF72), // Green
    Color(0xffD6D6D6), // Silver
  ];
}
