import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/dashboard/repository/dashboard_repository.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/money_tracker/models/monthly_summary_model.dart';

class MockTaskRepository implements TaskRepository {
  @override
  String? get userId => 'test_user';
  @override
  List<Task> getTasks() => [];
  @override
  Future<void> saveTask(Task task) async {}
  @override
  Future<void> deleteTask(String id) async {}
  @override
  Future<bool> syncPending() async => true;
  @override
  Future<int> performEndOfDayCleanup({String? overrideDateStr}) async => 0;
}

class MockHabitRepository implements HabitRepository {
  @override
  String? get userId => 'test_user';
  @override
  List<Habit> getHabits() => [];
  @override
  List<HabitEntry> getEntries() => [];
  @override
  Future<void> saveHabit(Habit habit) async {}
  @override
  Future<void> deleteHabit(String id) async {}
  @override
  Future<void> toggleEntry(String habitId, String dateStr, bool completed) async {}
  @override
  Future<bool> syncPending() async => true;
}

class InMemoryMoneyRepository implements MoneyRepository {
  double _budget = 0.0;
  final List<Transaction> _transactions = [];

  @override
  String? get userId => 'test_user';

  @override
  double getMonthlyBudget(String yearMonth) => _budget;

  @override
  Future<void> saveMonthlyBudget(String yearMonth, double amount) async {
    _budget = amount;
  }

  @override
  List<Transaction> getTransactions() => List.unmodifiable(_transactions);

  @override
  Future<void> saveTransaction(Transaction tx) async {
    final idx = _transactions.indexWhere((t) => t.id == tx.id);
    if (idx != -1) {
      _transactions[idx] = tx;
    } else {
      _transactions.add(tx);
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> saveMonthlySummary(MonthlySummary summary) async {}

  @override
  Future<bool> syncPending() async => true;
}

void main() {
  late InMemoryMoneyRepository moneyRepo;
  late DashboardRepository dashboardRepo;
  final currentMonthStr = '2026-08';
  final now = DateTime.now();

  setUp(() {
    moneyRepo = InMemoryMoneyRepository();
    dashboardRepo = DashboardRepository(
      taskRepository: MockTaskRepository(),
      habitRepository: MockHabitRepository(),
      moneyRepository: moneyRepo,
    );
  });

  group('Money Tracker — Income & Monthly Budget Separation Tests', () {
    test('TEST 1: Setting budget to ₹20,000 and adding ₹5,000 income leaves monthly budget at ₹20,000', () async {
      await moneyRepo.saveMonthlyBudget(currentMonthStr, 20000.0);
      await moneyRepo.saveTransaction(Transaction(
        id: 'tx_inc_1',
        type: 'Income',
        amount: 5000.0,
        category: 'Salary',
        notes: 'Monthly bonus',
        date: now,
        time: '12:00',
        createdAt: now,
      ));

      final budget = moneyRepo.getMonthlyBudget(currentMonthStr);
      expect(budget, equals(20000.0));

      final dashData = dashboardRepo.getDashboardData(currentMonthStr);
      expect(dashData['totalBudget'], equals(20000.0));
      expect(dashData['remainingBudget'], equals(20000.0));
      expect(dashData['todayIncome'], equals(5000.0));
    });

    test('TEST 2: Budget ₹20,000 + Income ₹10,000 + Expense ₹5,000 => Remaining budget is ₹15,000', () async {
      await moneyRepo.saveMonthlyBudget(currentMonthStr, 20000.0);
      await moneyRepo.saveTransaction(Transaction(
        id: 'tx_inc_2',
        type: 'Income',
        amount: 10000.0,
        category: 'Freelance',
        notes: 'Project payout',
        date: now,
        time: '12:00',
        createdAt: now,
      ));
      await moneyRepo.saveTransaction(Transaction(
        id: 'tx_exp_1',
        type: 'Expense',
        amount: 5000.0,
        category: 'Food',
        notes: 'Groceries',
        date: now,
        time: '12:00',
        createdAt: now,
      ));

      final budget = moneyRepo.getMonthlyBudget(currentMonthStr);
      expect(budget, equals(20000.0));

      final dashData = dashboardRepo.getDashboardData(currentMonthStr);
      expect(dashData['remainingBudget'], equals(15000.0)); // 20,000 - 5,000
      expect(dashData['todayIncome'], equals(10000.0));
      expect(dashData['todayExpenses'], equals(5000.0));
    });

    test('TEST 3: Editing income transaction from ₹10,000 to ₹15,000 does NOT alter monthly budget or remaining budget', () async {
      await moneyRepo.saveMonthlyBudget(currentMonthStr, 20000.0);
      final tx = Transaction(
        id: 'tx_inc_3',
        type: 'Income',
        amount: 10000.0,
        category: 'Salary',
        notes: 'Salary',
        date: now,
        time: '12:00',
        createdAt: now,
      );
      await moneyRepo.saveTransaction(tx);
      await moneyRepo.saveTransaction(Transaction(
        id: 'tx_exp_2',
        type: 'Expense',
        amount: 5000.0,
        category: 'Bills',
        notes: 'Electricity',
        date: now,
        time: '12:00',
        createdAt: now,
      ));

      // Edit income
      await moneyRepo.saveTransaction(tx.copyWith(amount: 15000.0));

      final budget = moneyRepo.getMonthlyBudget(currentMonthStr);
      expect(budget, equals(20000.0));

      final dashData = dashboardRepo.getDashboardData(currentMonthStr);
      expect(dashData['remainingBudget'], equals(15000.0)); // 20,000 - 5,000
      expect(dashData['todayIncome'], equals(15000.0));
    });

    test('TEST 4: Deleting income transaction does NOT alter monthly budget or remaining budget', () async {
      await moneyRepo.saveMonthlyBudget(currentMonthStr, 20000.0);
      await moneyRepo.saveTransaction(Transaction(
        id: 'tx_inc_4',
        type: 'Income',
        amount: 8000.0,
        category: 'Investments',
        notes: 'Dividends',
        date: now,
        time: '12:00',
        createdAt: now,
      ));
      await moneyRepo.saveTransaction(Transaction(
        id: 'tx_exp_3',
        type: 'Expense',
        amount: 5000.0,
        category: 'Transport',
        notes: 'Fuel',
        date: now,
        time: '12:00',
        createdAt: now,
      ));

      // Delete income transaction
      await moneyRepo.deleteTransaction('tx_inc_4');

      final budget = moneyRepo.getMonthlyBudget(currentMonthStr);
      expect(budget, equals(20000.0));

      final dashData = dashboardRepo.getDashboardData(currentMonthStr);
      expect(dashData['remainingBudget'], equals(15000.0)); // 20,000 - 5,000
      expect(dashData['todayIncome'], equals(0.0));
    });

    test('TEST 5: Adding expenses until ₹20,000 budget is spent results in 0 remaining budget (100% used)', () async {
      await moneyRepo.saveMonthlyBudget(currentMonthStr, 20000.0);
      await moneyRepo.saveTransaction(Transaction(
        id: 'tx_exp_full',
        type: 'Expense',
        amount: 20000.0,
        category: 'Shopping',
        notes: 'Major purchase',
        date: now,
        time: '12:00',
        createdAt: now,
      ));

      final dashData = dashboardRepo.getDashboardData(currentMonthStr);
      expect(dashData['remainingBudget'], equals(0.0));
    });

    test('TEST 6: Over-budget spending beyond ₹20,000 yields negative remaining budget (-₹2,000)', () async {
      await moneyRepo.saveMonthlyBudget(currentMonthStr, 20000.0);
      await moneyRepo.saveTransaction(Transaction(
        id: 'tx_exp_over',
        type: 'Expense',
        amount: 22000.0,
        category: 'Shopping',
        notes: 'Over budget purchase',
        date: now,
        time: '12:00',
        createdAt: now,
      ));

      final dashData = dashboardRepo.getDashboardData(currentMonthStr);
      expect(dashData['remainingBudget'], equals(-2000.0));
    });

    test('TEST 7: Donut breakdown with Budget=20k, Income=50k, Expense=18k results in 90% budget used & ₹2k remaining', () async {
      await moneyRepo.saveMonthlyBudget(currentMonthStr, 20000.0);
      await moneyRepo.saveTransaction(Transaction(
        id: 'tx_large_income',
        type: 'Income',
        amount: 50000.0,
        category: 'Bonus',
        notes: 'Annual Bonus',
        date: now,
        time: '12:00',
        createdAt: now,
      ));
      await moneyRepo.saveTransaction(Transaction(
        id: 'tx_exp_18k',
        type: 'Expense',
        amount: 18000.0,
        category: 'Rent',
        notes: 'Monthly rent',
        date: now,
        time: '12:00',
        createdAt: now,
      ));

      final budget = moneyRepo.getMonthlyBudget(currentMonthStr);
      expect(budget, equals(20000.0));

      final dashData = dashboardRepo.getDashboardData(currentMonthStr);
      expect(dashData['remainingBudget'], equals(2000.0));
      expect(dashData['todayIncome'], equals(50000.0));
      expect(dashData['todayExpenses'], equals(18000.0));
      expect(dashData['monthlySavings'], equals(32000.0)); // Income - Expense = 50,000 - 18,000
    });
  });
}
