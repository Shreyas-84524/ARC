import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  testWidgets('SettingsScreen UI modifications: email removed, username centered, diagnostics section removed', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. Verify username is visible
    expect(find.text('Shreyas'), findsOneWidget);

    // 2. Verify email address is completely removed
    expect(find.text('shreyas@arc.app'), findsNothing);

    // 3. Verify Change Password option is present
    expect(find.text('Change Password'), findsOneWidget);

    // 4. Verify Data & Storage Diagnostics section is completely removed
    expect(find.text('Data & Storage Diagnostics'), findsNothing);
    expect(find.text('Cloud Firestore Synchronization'), findsNothing);
    expect(find.text('Background queue active • Project Arc'), findsNothing);
    expect(find.text('Hive Storage Engine'), findsNothing);
    expect(find.text('User Isolated Hive Boxes Operational'), findsNothing);
    expect(find.text('Sync Now'), findsNothing);
    expect(find.text('Online'), findsNothing);

    // 5. Verify Logout option is present
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Log Out'), findsOneWidget);
  });
}
