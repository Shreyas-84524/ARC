import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/models/monthly_summary_model.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/money_tracker/screens/money_screen.dart';
import 'package:arc/features/money_tracker/widgets/transaction_details_sheet.dart';
import 'package:arc/features/money_tracker/widgets/transaction_editor_sheet.dart';
import 'package:arc/providers/global_providers.dart';

class InMemoryMoneyRepository implements MoneyRepository {
  double _budget = 10000.0;
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
  final testDate = DateTime.now();

  Widget buildTestWidget({List<Transaction>? initialTransactions}) {
    final repo = InMemoryMoneyRepository();
    if (initialTransactions != null) {
      for (final tx in initialTransactions) {
        repo.saveTransaction(tx);
      }
    }

    return ProviderScope(
      overrides: [
        moneyRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const MoneyScreen(),
      ),
    );
  }

  testWidgets('Existing transaction opens view-only details sheet without edit fields', (WidgetTester tester) async {
    final tx = Transaction(
      id: 'tx_view_only_1',
      amount: 450.0,
      type: 'Expense',
      category: 'Food',
      date: testDate,
      time: '12:30',
      notes: 'Lunch at Cafe',
      createdAt: testDate,
    );

    await tester.pumpWidget(buildTestWidget(initialTransactions: [tx]));
    await tester.pumpAndSettle();

    // Verify Food transaction tile is visible
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('-₹450.00'), findsOneWidget);

    // Tap transaction tile
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    // 1. Verify TransactionDetailsSheet opens
    expect(find.byType(TransactionDetailsSheet), findsOneWidget);
    expect(find.text('Expense Recorded'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TransactionDetailsSheet),
        matching: find.text('Lunch at Cafe'),
      ),
      findsOneWidget,
    );

    // 2. Verify NO editable text fields or dropdowns exist in details view
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Save Changes'), findsNothing);

    // 3. Verify Delete Transaction button is present in details view
    expect(find.text('Delete Transaction'), findsOneWidget);
  });

  testWidgets('Delete transaction from details sheet triggers confirmation modal and removes transaction', (WidgetTester tester) async {
    final tx = Transaction(
      id: 'tx_delete_1',
      amount: 1200.0,
      type: 'Expense',
      category: 'Shopping',
      date: testDate,
      time: '15:00',
      notes: 'New Shoes',
      createdAt: testDate,
    );

    await tester.pumpWidget(buildTestWidget(initialTransactions: [tx]));
    await tester.pumpAndSettle();

    // Tap tile to view details
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();

    // Tap Delete Transaction button inside details sheet
    await tester.tap(find.text('Delete Transaction'));
    await tester.pumpAndSettle();

    // Verify Delete confirmation dialog pops up
    expect(find.text('Delete Transaction'), findsNWidgets(2)); // Title in dialog + details button
    expect(find.textContaining('Are you sure you want to delete this expense of ₹1,200.00?'), findsOneWidget);

    // Tap Delete inside confirmation dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    // Verify transaction is deleted from UI
    expect(find.text('Shopping'), findsNothing);
  });

  testWidgets('TransactionEditorSheet title and button strictly show Add Transaction', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap FAB ("+") to add transaction
    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();

    // Verify sheet is TransactionEditorSheet in Add mode
    expect(find.byType(TransactionEditorSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TransactionEditorSheet),
        matching: find.text('Add Transaction'),
      ),
      findsNWidgets(2),
    ); // Title & Button
    expect(find.text('Edit Transaction'), findsNothing);
    expect(find.text('Save Changes'), findsNothing);
  });
}
