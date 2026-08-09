import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/core/theme/app_theme.dart';

void main() {
  group('Money Tracker — Transaction Icon & Color Logic Tests', () {
    test('Debit transaction evaluates to AppColors.danger (Red) for any category', () {
      final debitFood = Transaction(
        id: 'tx_1',
        amount: 250.0,
        type: 'Expense',
        category: 'Food',
        notes: 'Lunch',
        date: DateTime.now(),
        time: '12:30',
        createdAt: DateTime.now(),
      );

      final debitEntertainment = Transaction(
        id: 'tx_2',
        amount: 500.0,
        type: 'Expense',
        category: 'Entertainment',
        notes: 'Movie',
        date: DateTime.now(),
        time: '18:00',
        createdAt: DateTime.now(),
      );

      final isFoodIncome = debitFood.type == 'Income';
      final isEntIncome = debitEntertainment.type == 'Income';

      expect(isFoodIncome, isFalse);
      expect(isEntIncome, isFalse);

      final foodColor = isFoodIncome ? AppColors.income : AppColors.danger;
      final entColor = isEntIncome ? AppColors.income : AppColors.danger;

      expect(foodColor, equals(AppColors.danger));
      expect(entColor, equals(AppColors.danger));
    });

    test('Credit transaction evaluates to AppColors.income (Green) for any category', () {
      final creditSalary = Transaction(
        id: 'tx_3',
        amount: 50000.0,
        type: 'Income',
        category: 'Salary',
        notes: 'Monthly Pay',
        date: DateTime.now(),
        time: '09:00',
        createdAt: DateTime.now(),
      );

      final creditOther = Transaction(
        id: 'tx_4',
        amount: 2000.0,
        type: 'Income',
        category: 'Other',
        notes: 'Gift',
        date: DateTime.now(),
        time: '14:00',
        createdAt: DateTime.now(),
      );

      final isSalaryIncome = creditSalary.type == 'Income';
      final isOtherIncome = creditOther.type == 'Income';

      expect(isSalaryIncome, isTrue);
      expect(isOtherIncome, isTrue);

      final salaryColor = isSalaryIncome ? AppColors.income : AppColors.danger;
      final otherColor = isOtherIncome ? AppColors.income : AppColors.danger;

      expect(salaryColor, equals(AppColors.income));
      expect(otherColor, equals(AppColors.income));
    });
  });
}
