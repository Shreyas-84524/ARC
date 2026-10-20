import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/features/money_tracker/widgets/automatic_spending_prompt_card.dart';
import 'package:arc/features/money_tracker/widgets/automatic_spending_info_dialog.dart';
import 'package:arc/features/money_tracker/widgets/money_tracker_settings_sheet.dart';
import 'package:arc/features/money_tracker/providers/money_automation_provider.dart';
import 'package:arc/features/money_tracker/repository/money_automation_repository.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/features/money_tracker/screens/money_screen.dart';
import 'package:arc/features/settings/screens/settings_screen.dart';
import 'package:arc/providers/global_providers.dart';
import 'package:arc/core/services/hive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HiveService().setInitializedForTesting(true);
  });

  group('AutomaticSpendingPromptCard Widget Tests', () {
    testWidgets('Renders header and Yes / No action buttons', (tester) async {
      bool yesTapped = false;
      bool noTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AutomaticSpendingPromptCard(
              onYes: () => yesTapped = true,
              onNo: () => noTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Automate tracking of spendings?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);

      await tester.tap(find.text('No'));
      await tester.pump();
      expect(noTapped, isTrue);

      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(yesTapped, isTrue);
    });
  });

  group('AutomaticSpendingInfoDialog Widget Tests', () {
    testWidgets('Renders 3 informational points and Cancel/Enable actions', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => const AutomaticSpendingInfoDialog(),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Automatic Spending Tracking'), findsOneWidget);
      expect(find.text('Only confirmed spending is added'), findsOneWidget);
      expect(
        find.textContaining('ARC will only try to detect confirmed debit/spending transactions.'),
        findsOneWidget,
      );
      expect(find.text('Your transaction data stays local'), findsOneWidget);
      expect(
        find.textContaining('Transaction SMS/notification processing will happen on your device.'),
        findsOneWidget,
      );
      expect(find.text('You remain in control'), findsOneWidget);
      expect(
        find.textContaining('Automatic spending tracking can be disabled at any time'),
        findsOneWidget,
      );

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Enable'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      // Open again and tap Enable
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('MoneyTrackerSettingsSheet Widget Tests', () {
    testWidgets('Toggles automatic spending tracking on and off', (tester) async {
      final repo = MoneyAutomationRepository(inMemoryOnly: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moneyAutomationRepositoryProvider.overrideWithValue(repo),
            userContextProvider.overrideWith((ref) => FakeUserContextNotifier(
                  const UserContext(userId: 'test_user'),
                )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MoneyTrackerSettingsSheet(),
            ),
          ),
        ),
      );

      expect(find.text('Money Tracker Settings'), findsOneWidget);
      expect(find.text('Automatic Spending Tracking'), findsOneWidget);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final initialSwitch = tester.widget<Switch>(switchFinder);
      expect(initialSwitch.value, isFalse);

      // Tapping switch to enable opens the info dialog
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AutomaticSpendingInfoDialog), findsOneWidget);

      // Confirm in dialog
      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();

      final updatedSwitch = tester.widget<Switch>(switchFinder);
      expect(updatedSwitch.value, isTrue);

      // Tapping again disables directly
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final disabledSwitch = tester.widget<Switch>(switchFinder);
      expect(disabledSwitch.value, isFalse);
    });
  });

  group('MoneyScreen Automation Prompt Integration Tests', () {
    testWidgets('Prompt is hidden when monthly budget is 0.0 (not configured)', (tester) async {
      final repo = MoneyAutomationRepository(inMemoryOnly: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moneyAutomationRepositoryProvider.overrideWithValue(repo),
            monthlyBudgetProvider.overrideWith((ref) => FakeMonthlyBudgetNotifier(0.0)),
            moneyProvider.overrideWith((ref) => FakeMoneyNotifier()),
            currentMonthProvider.overrideWithValue('2026-10'),
            userContextProvider.overrideWith((ref) => FakeUserContextNotifier(
                  const UserContext(userId: 'test_user'),
                )),
          ],
          child: const MaterialApp(
            home: MoneyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Configure monthly budget banner is shown instead
      expect(find.text('Configure Monthly Budget'), findsOneWidget);
      expect(find.byType(AutomaticSpendingPromptCard), findsNothing);

      // Prompt was not recorded
      final state = repo.loadState('test_user');
      expect(state.promptCount, equals(0));
    });

    testWidgets('Prompt is shown when monthly budget is configured and count < 2', (tester) async {
      final repo = MoneyAutomationRepository(inMemoryOnly: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moneyAutomationRepositoryProvider.overrideWithValue(repo),
            monthlyBudgetProvider.overrideWith((ref) => FakeMonthlyBudgetNotifier(5000.0)),
            moneyProvider.overrideWith((ref) => FakeMoneyNotifier()),
            currentMonthProvider.overrideWithValue('2026-10'),
            userContextProvider.overrideWith((ref) => FakeUserContextNotifier(
                  const UserContext(userId: 'test_user'),
                )),
          ],
          child: const MaterialApp(
            home: MoneyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AutomaticSpendingPromptCard), findsOneWidget);
      expect(find.text('Automate tracking of spendings?'), findsOneWidget);

      // Verify the appearance was recorded
      final state = repo.loadState('test_user');
      expect(state.promptCount, equals(1));
      expect(state.promptMonth, equals('2026-10'));
    });

    testWidgets('Tapping No dismisses the prompt for the session without enabling', (tester) async {
      final repo = MoneyAutomationRepository(inMemoryOnly: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moneyAutomationRepositoryProvider.overrideWithValue(repo),
            monthlyBudgetProvider.overrideWith((ref) => FakeMonthlyBudgetNotifier(5000.0)),
            moneyProvider.overrideWith((ref) => FakeMoneyNotifier()),
            currentMonthProvider.overrideWithValue('2026-10'),
            userContextProvider.overrideWith((ref) => FakeUserContextNotifier(
                  const UserContext(userId: 'test_user'),
                )),
          ],
          child: const MaterialApp(
            home: MoneyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AutomaticSpendingPromptCard), findsOneWidget);

      // Tap No
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(find.byType(AutomaticSpendingPromptCard), findsNothing);

      // Automation remains disabled
      final state = repo.loadState('test_user');
      expect(state.isEnabled, isFalse);
    });

    testWidgets('Tapping Yes shows info dialog; Cancel keeps disabled', (tester) async {
      final repo = MoneyAutomationRepository(inMemoryOnly: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moneyAutomationRepositoryProvider.overrideWithValue(repo),
            monthlyBudgetProvider.overrideWith((ref) => FakeMonthlyBudgetNotifier(5000.0)),
            moneyProvider.overrideWith((ref) => FakeMoneyNotifier()),
            currentMonthProvider.overrideWithValue('2026-10'),
            userContextProvider.overrideWith((ref) => FakeUserContextNotifier(
                  const UserContext(userId: 'test_user'),
                )),
          ],
          child: const MaterialApp(
            home: MoneyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Yes
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(find.byType(AutomaticSpendingInfoDialog), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AutomaticSpendingInfoDialog), findsNothing);

      // Remains disabled
      final state = repo.loadState('test_user');
      expect(state.isEnabled, isFalse);
    });

    testWidgets('Tapping Yes and Enable persists opt-in and hides prompt', (tester) async {
      final repo = MoneyAutomationRepository(inMemoryOnly: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moneyAutomationRepositoryProvider.overrideWithValue(repo),
            monthlyBudgetProvider.overrideWith((ref) => FakeMonthlyBudgetNotifier(5000.0)),
            moneyProvider.overrideWith((ref) => FakeMoneyNotifier()),
            currentMonthProvider.overrideWithValue('2026-10'),
            userContextProvider.overrideWith((ref) => FakeUserContextNotifier(
                  const UserContext(userId: 'test_user'),
                )),
          ],
          child: const MaterialApp(
            home: MoneyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Yes
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      // Tap Enable
      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();

      // Prompt card is gone
      expect(find.byType(AutomaticSpendingPromptCard), findsNothing);

      // Repository has enabled = true
      final state = repo.loadState('test_user');
      expect(state.isEnabled, isTrue);
      expect(state.hasAcceptedInfoDialog, isTrue);
    });

    testWidgets('Prompt is not shown on third visit in the same month (max 2 rule)', (tester) async {
      final repo = MoneyAutomationRepository(inMemoryOnly: true);
      // Pre-seed 2 appearances in current month
      await repo.recordPromptAppearance('test_user', '2026-10');
      await repo.recordPromptAppearance('test_user', '2026-10');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moneyAutomationRepositoryProvider.overrideWithValue(repo),
            monthlyBudgetProvider.overrideWith((ref) => FakeMonthlyBudgetNotifier(5000.0)),
            moneyProvider.overrideWith((ref) => FakeMoneyNotifier()),
            currentMonthProvider.overrideWithValue('2026-10'),
            userContextProvider.overrideWith((ref) => FakeUserContextNotifier(
                  const UserContext(userId: 'test_user'),
                )),
          ],
          child: const MaterialApp(
            home: MoneyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AutomaticSpendingPromptCard), findsNothing);
    });
  });

  group('SettingsScreen Money Tracker Section Tests', () {
    testWidgets('Renders Money Tracker section and controls Automatic Spending Tracking toggle', (tester) async {
      final repo = MoneyAutomationRepository(inMemoryOnly: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moneyAutomationRepositoryProvider.overrideWithValue(repo),
            userContextProvider.overrideWith((ref) => FakeUserContextNotifier(
                  const UserContext(userId: 'test_user'),
                )),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final switchFinder = find.widgetWithText(SwitchListTile, 'Automatic Spending Tracking');

      // Scroll until SwitchListTile is fully visible
      await tester.scrollUntilVisible(
        switchFinder,
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Money Tracker'), findsOneWidget);
      expect(find.text('Automatic Spending Tracking'), findsOneWidget);

      expect(switchFinder, findsOneWidget);
      final initialTile = tester.widget<SwitchListTile>(switchFinder);
      expect(initialTile.value, isFalse);

      // Tap the switch
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AutomaticSpendingInfoDialog), findsOneWidget);

      // Confirm enable in dialog
      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();

      final enabledTile = tester.widget<SwitchListTile>(switchFinder);
      expect(enabledTile.value, isTrue);

      final state = repo.loadState('test_user');
      expect(state.isEnabled, isTrue);

      // Tap again to disable
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final disabledTile = tester.widget<SwitchListTile>(switchFinder);
      expect(disabledTile.value, isFalse);
      expect(repo.loadState('test_user').isEnabled, isFalse);
    });
  });
}

class FakeUserContextNotifier extends UserContextNotifier {
  FakeUserContextNotifier(UserContext initial) {
    state = initial;
  }
}

class FakeMonthlyBudgetNotifier extends StateNotifier<double> implements MonthlyBudgetNotifier {
  FakeMonthlyBudgetNotifier(super.state);

  @override
  Future<void> setBudget(double amount) async {
    state = amount;
  }

  @override
  void refresh() {}
}

class FakeMoneyNotifier extends StateNotifier<List<Transaction>> implements MoneyNotifier {
  FakeMoneyNotifier() : super([]);

  @override
  Future<void> addTransaction(Transaction tx) async {
    state = [...state, tx];
  }

  @override
  Future<void> deleteTransaction(String id) async {
    state = state.where((tx) => tx.id != id).toList();
  }

  @override
  void refresh() {}

  @override
  Future<void> syncTransactions() async {}

  @override
  Future<void> updateTransaction(Transaction tx) async {
    state = state.map((t) => t.id == tx.id ? tx : t).toList();
  }
}
