import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/habit_tracker/screens/habits_screen.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/models/monthly_summary_model.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/settings/models/settings_model.dart';
import 'package:arc/features/settings/repository/settings_repository.dart';
import 'package:arc/providers/global_providers.dart';

class TestTaskRepository implements TaskRepository {
  @override
  String? get userId => null;
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

class TestHabitRepository implements HabitRepository {
  @override
  String? get userId => null;
  final List<Habit> _habits = [];
  final List<HabitEntry> _entries = [];

  void seedHabit(Habit habit) {
    _habits.add(habit);
  }

  void seedEntry(HabitEntry entry) {
    _entries.add(entry);
  }

  @override
  List<Habit> getHabits() => _habits;

  @override
  List<HabitEntry> getEntries() => _entries;

  @override
  Future<void> saveHabit(Habit habit) async {
    _habits.removeWhere((h) => h.id == habit.id);
    _habits.add(habit);
  }

  @override
  Future<void> deleteHabit(String id) async {
    _habits.removeWhere((h) => h.id == id);
    _entries.removeWhere((e) => e.habitId == id);
  }

  @override
  Future<void> toggleEntry(String habitId, String dateStr, bool completed) async {
    final entryId = '${habitId}_$dateStr';
    _entries.removeWhere((e) => e.id == entryId);
    if (completed) {
      _entries.add(HabitEntry(id: entryId, habitId: habitId, dateStr: dateStr, completed: true));
    }
  }

  @override
  Future<bool> syncPending() async => true;
}

class TestMoneyRepository implements MoneyRepository {
  @override
  String? get userId => null;
  @override
  List<Transaction> getTransactions() => [];
  @override
  double getMonthlyBudget(String yearMonth) => 0.0;
  @override
  Future<void> saveMonthlyBudget(String yearMonth, double amount) async {}
  @override
  Future<void> saveTransaction(Transaction tx) async {}
  @override
  Future<void> deleteTransaction(String id) async {}
  @override
  Future<void> saveMonthlySummary(MonthlySummary summary) async {}
  @override
  Future<bool> syncPending() async => true;
}

class TestSettingsRepository implements SettingsRepository {
  @override
  String? get userId => null;
  @override
  SettingsModel getSettings() => SettingsModel.defaultSettings();
  @override
  Future<void> saveSettings(SettingsModel settings) async {}
  @override
  Future<bool> syncPending() async => true;
}

void main() {
  group('Individual Goal Performance Tests', () {
    testWidgets('Displays empty state when no habits exist', (tester) async {
      final testHabitRepo = TestHabitRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(TestTaskRepository()),
            habitRepositoryProvider.overrideWithValue(testHabitRepo),
            moneyRepositoryProvider.overrideWithValue(TestMoneyRepository()),
            settingsRepositoryProvider.overrideWithValue(TestSettingsRepository()),
          ],
          child: const MaterialApp(
            home: HabitsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Analytics tab
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();

      expect(find.text('Individual Goal Performance'), findsOneWidget);
      expect(find.text('No habits created yet'), findsOneWidget);
    });

    testWidgets('Displays individual habit analytics card with Weekly filter by default', (tester) async {
      final testHabitRepo = TestHabitRepository();

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

      final habit = Habit(
        id: 'h1',
        name: 'Daily Exercise',
        category: 'Health',
        colorValue: 0xff4caf50,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
      );

      testHabitRepo.seedHabit(habit);
      testHabitRepo.seedEntry(HabitEntry(id: 'h1_$todayStr', habitId: 'h1', dateStr: todayStr, completed: true));
      testHabitRepo.seedEntry(HabitEntry(id: 'h1_$yesterdayStr', habitId: 'h1', dateStr: yesterdayStr, completed: true));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(TestTaskRepository()),
            habitRepositoryProvider.overrideWithValue(testHabitRepo),
            moneyRepositoryProvider.overrideWithValue(TestMoneyRepository()),
            settingsRepositoryProvider.overrideWithValue(TestSettingsRepository()),
          ],
          child: const MaterialApp(
            home: HabitsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Analytics tab
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();

      // Scroll down to Individual Goal Performance
      final individualHeader = find.text('Individual Goal Performance');
      await tester.scrollUntilVisible(
        individualHeader,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(individualHeader, findsOneWidget);
      expect(find.text('Daily Exercise'), findsOneWidget);

      // Check Weekly completed count: 2 out of 7 days
      expect(find.text('2 / 7'), findsOneWidget);
      // 2 / 7 = 29%
      expect(find.text('29%'), findsOneWidget);
    });

    testWidgets('Switching to Monthly filter recalculates metrics correctly', (tester) async {
      final testHabitRepo = TestHabitRepository();

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

      final habit = Habit(
        id: 'h1',
        name: 'Reading',
        category: 'Personal',
        colorValue: 0xff2196f3,
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now,
      );

      testHabitRepo.seedHabit(habit);
      testHabitRepo.seedEntry(HabitEntry(id: 'h1_$todayStr', habitId: 'h1', dateStr: todayStr, completed: true));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(TestTaskRepository()),
            habitRepositoryProvider.overrideWithValue(testHabitRepo),
            moneyRepositoryProvider.overrideWithValue(TestMoneyRepository()),
            settingsRepositoryProvider.overrideWithValue(TestSettingsRepository()),
          ],
          child: const MaterialApp(
            home: HabitsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Analytics tab
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();

      // Scroll down to Individual Goal Performance header
      final individualHeader = find.text('Individual Goal Performance');
      await tester.scrollUntilVisible(
        individualHeader,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('1 / 7'), findsOneWidget);

      // Target the second DropdownButton on screen
      final dropdowns = find.byType(DropdownButton<String>);
      expect(dropdowns, findsNWidgets(2));
      final filterDropdown = dropdowns.at(1);

      await tester.ensureVisible(filterDropdown);
      await tester.pumpAndSettle();

      await tester.tap(filterDropdown);
      await tester.pumpAndSettle();

      // Select 'Monthly' option
      final monthlyOption = find.text('Monthly').last;
      await tester.tap(monthlyOption);
      await tester.pumpAndSettle();

      // Monthly completed: 1 / daysInMonth
      expect(find.text('1 / $daysInMonth'), findsOneWidget);
    });
  });
}
