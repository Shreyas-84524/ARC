import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/models/monthly_summary_model.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/settings/models/settings_model.dart';
import 'package:arc/features/settings/repository/settings_repository.dart';
import 'package:arc/features/dashboard/screens/dashboard_screen.dart';
import 'package:arc/features/task_manager/screens/tasks_screen.dart';
import 'package:arc/features/habit_tracker/screens/habits_screen.dart';
import 'package:arc/features/money_tracker/screens/money_screen.dart';
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

class TestMoneyRepository implements MoneyRepository {
  @override
  String? get userId => null;
  @override
  List<Transaction> getTransactions() => [];
  @override
  double getMonthlyBudget(String yearMonth) => 50000.0;
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
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<Size> deviceSizes = const [
    Size(320, 568), // Small Phone (iPhone SE 1st gen / Small Android)
    Size(390, 844), // Standard Phone (iPhone 13 / Pixel 6)
    Size(412, 915), // Tall Phone (Pixel 7 Pro)
    Size(600, 960), // Wide Phone / Small Tablet
  ];

  List<Override> getOverrides() {
    return [
      taskRepositoryProvider.overrideWithValue(TestTaskRepository()),
      habitRepositoryProvider.overrideWithValue(TestHabitRepository()),
      moneyRepositoryProvider.overrideWithValue(TestMoneyRepository()),
      settingsRepositoryProvider.overrideWithValue(TestSettingsRepository()),
    ];
  }

  group('Responsive UI Viewport & Overflow Tests', () {
    for (final size in deviceSizes) {
      testWidgets('DashboardScreen renders without overflow on ${size.width}x${size.height}',
          (WidgetTester tester) async {
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: getOverrides(),
            child: const MaterialApp(
              home: DashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('TasksScreen renders without overflow on ${size.width}x${size.height}',
          (WidgetTester tester) async {
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: getOverrides(),
            child: const MaterialApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TasksScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('HabitsScreen renders without overflow on ${size.width}x${size.height}',
          (WidgetTester tester) async {
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: getOverrides(),
            child: const MaterialApp(
              home: HabitsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HabitsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('MoneyScreen renders without overflow on ${size.width}x${size.height}',
          (WidgetTester tester) async {
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: getOverrides(),
            child: const MaterialApp(
              home: MoneyScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MoneyScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
