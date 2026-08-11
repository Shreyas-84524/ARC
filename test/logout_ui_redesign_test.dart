import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/features/settings/screens/settings_screen.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/settings/models/settings_model.dart';
import 'package:arc/features/settings/repository/settings_repository.dart';
import 'package:arc/providers/global_providers.dart';

class MockTaskRepo implements TaskRepository {
  @override
  String? get userId => null;
  @override
  List<Task> getTasks() => [];
  @override
  Future<void> saveTask(Task task) async {}
  @override
  Future<void> deleteTask(String id) async {}
  @override
  Future<void> syncPending() async {}
  @override
  Future<int> performEndOfDayCleanup({String? overrideDateStr}) async => 0;
}

class MockHabitRepo implements HabitRepository {
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
  Future<void> syncPending() async {}
}

class MockMoneyRepo implements MoneyRepository {
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
  Future<void> saveMonthlySummary(summary) async {}
  @override
  Future<void> syncPending() async {}
}

class MockSettingsRepo implements SettingsRepository {
  @override
  String? get userId => null;
  @override
  SettingsModel getSettings() => SettingsModel.defaultSettings();
  @override
  Future<void> saveSettings(SettingsModel settings) async {}
  @override
  Future<void> syncPending() async {}
}

void main() {
  Widget buildTestWidget() {
    final mockSettingsRepo = MockSettingsRepo();
    return ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(MockTaskRepo()),
        habitRepositoryProvider.overrideWithValue(MockHabitRepo()),
        moneyRepositoryProvider.overrideWithValue(MockMoneyRepo()),
        settingsRepositoryProvider.overrideWithValue(mockSettingsRepo),
        appSettingsProvider.overrideWith((ref) => SettingsNotifier(mockSettingsRepo)),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen displays redesigned Logout card at end of settings', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Scroll to bottom to bring Logout card into view
    final logoutTileFinder = find.text('Log Out');
    await tester.scrollUntilVisible(logoutTileFinder, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(logoutTileFinder, findsOneWidget);
    expect(find.text('Sign out of account and sync session'), findsOneWidget);
    expect(find.byIcon(LucideIcons.logOut), findsWidgets);
  });

  testWidgets('Tapping Logout card opens redesigned Confirmation Dialog with title "Log out?"', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final logoutTileFinder = find.text('Log Out');
    await tester.scrollUntilVisible(logoutTileFinder, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    await tester.tap(logoutTileFinder);
    await tester.pumpAndSettle();

    // Dialog title
    expect(find.text('Log out?'), findsOneWidget);
    // Dialog explanation
    expect(find.text('Are you sure you want to log out of your account?'), findsOneWidget);
    // Buttons
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Log Out'), findsNWidgets(2)); // Card + Dialog primary button
  });

  testWidgets('Tapping Cancel in confirmation dialog closes dialog without logging out', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final logoutTileFinder = find.text('Log Out');
    await tester.scrollUntilVisible(logoutTileFinder, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(find.text('Log Out'), findsOneWidget);

    await tester.tap(logoutTileFinder);
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Dialog closed
    expect(find.text('Log out?'), findsNothing);
    // SettingsScreen still visible
    expect(find.text('Settings & Profile'), findsOneWidget);
  });
}
