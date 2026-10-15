import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/money_tracker/models/money_automation_raw_event.dart';
import 'package:arc/features/money_tracker/models/monthly_summary_model.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/providers/money_automation_provider.dart';
import 'package:arc/features/money_tracker/repository/money_automation_repository.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/money_tracker/screens/money_screen.dart';
import 'package:arc/features/money_tracker/services/money_automation_listener_service.dart';
import 'package:arc/features/money_tracker/services/money_automation_platform_bridge.dart';
import 'package:arc/features/money_tracker/services/money_deduplication_service.dart';
import 'package:arc/features/money_tracker/services/money_transaction_parser.dart';
import 'package:arc/providers/global_providers.dart';

class FakeMoneyAutomationPlatformBridge implements MoneyAutomationPlatformBridge {
  @override
  bool isPlatformSupported = true;

  bool hasPermission = true;
  String requestPermissionResponse = 'granted';
  bool isListenerEnabled = false;

  final StreamController<MoneyAutomationRawEvent> _streamController =
      StreamController<MoneyAutomationRawEvent>.broadcast();

  @override
  Future<bool> checkPermission() async => hasPermission;

  @override
  Future<String> requestPermission() async => requestPermissionResponse;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> setListenerEnabled(bool enabled) async {
    isListenerEnabled = enabled;
  }

  @override
  Stream<MoneyAutomationRawEvent> get eventStream => _streamController.stream;

  void emitRawEvent(MoneyAutomationRawEvent event) {
    _streamController.add(event);
  }

  void dispose() {
    _streamController.close();
  }
}

class InMemoryMoneyRepository implements MoneyRepository {
  double _budget = 10000.0;
  final List<Transaction> _transactions = [];
  bool shouldFailOnSave = false;

  @override
  String? get userId => 'test_user_phase4';

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
    if (shouldFailOnSave) {
      throw Exception('Database write failure');
    }
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
  late FakeMoneyAutomationPlatformBridge fakeBridge;
  late MoneyAutomationListenerService listenerService;
  late MoneyAutomationRepository autoRepo;
  late InMemoryMoneyRepository moneyRepo;
  late MoneyTransactionParser parser;
  late MoneyDeduplicationService dedupService;
  late MoneyAutomationNotifier notifier;

  MoneyAutomationRawEvent makeEvent(String body, {String sender = 'HDFCBK'}) {
    return MoneyAutomationRawEvent(
      sender: sender,
      body: body,
      timestamp: DateTime(2026, 10, 15, 14, 30),
      sourceType: 'sms',
    );
  }

  setUp(() {
    fakeBridge = FakeMoneyAutomationPlatformBridge();
    listenerService = MoneyAutomationListenerService(bridge: fakeBridge);
    autoRepo = MoneyAutomationRepository(inMemoryOnly: true);
    moneyRepo = InMemoryMoneyRepository();
    parser = MoneyTransactionParser();
    dedupService = MoneyDeduplicationService();
    dedupService.initForUser('test_user_phase4');

    notifier = MoneyAutomationNotifier(
      autoRepo,
      'test_user_phase4',
      listenerService: listenerService,
      parser: parser,
      deduplicationService: dedupService,
      moneyRepository: moneyRepo,
    );
  });

  tearDown(() {
    if (notifier.mounted) {
      notifier.dispose();
    }
    fakeBridge.dispose();
    dedupService.clear();
  });

  // 1. Accepted candidate creates an Expense in Money Manager
  test('1. Accepted confirmed debit candidate automatically creates an Expense in Money Manager', () async {
    await notifier.enableAutomation();

    final event = makeEvent(
      'HDFC Bank: Rs 450.00 debited from a/c **1234 on 15-10-26 to Swiggy. UPI Ref: 123456789012. Avl bal: Rs 15400.00',
    );
    fakeBridge.emitRawEvent(event);
    await Future<void>.delayed(Duration.zero);

    final transactions = moneyRepo.getTransactions();
    expect(transactions.length, 1);

    final tx = transactions.first;
    expect(tx.type, 'Expense');
    expect(tx.source, 'sms_auto');
  });

  // 2. Created expense category is Uncategorized
  test('2. Created automatic expense starts strictly as Uncategorized', () async {
    await notifier.enableAutomation();

    final event = makeEvent(
      'Rs 600.00 debited from a/c **4321 to Uber on 15-10-26. Ref 998877. Avl Bal Rs 8000.',
    );
    fakeBridge.emitRawEvent(event);
    await Future<void>.delayed(Duration.zero);

    final tx = moneyRepo.getTransactions().first;
    expect(tx.category, 'Uncategorized');
  });

  // 3. Amount, date, and description are preserved
  test('3. Candidate amount, date, and sanitized description are preserved', () async {
    await notifier.enableAutomation();

    final event = makeEvent(
      'Rs 1,250.75 spent at Amazon on 15-10-26 using card ending 9999. Txn ID: 554433. Bal: Rs 10000.',
    );
    fakeBridge.emitRawEvent(event);
    await Future<void>.delayed(Duration.zero);

    final tx = moneyRepo.getTransactions().first;
    expect(tx.amount, 1250.75);
    expect(tx.notes, 'Paid to Amazon');
    expect(tx.date.year, 2026);
    expect(tx.automationFingerprint, isNotNull);
  });

  // 4. Category prompt is shown on UI for Uncategorized transactions
  testWidgets('4. Category prompt is shown on UI for Uncategorized transactions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tx = Transaction(
      id: 'auto_tx_1',
      amount: 450.0,
      type: 'Expense',
      category: 'Uncategorized',
      date: DateTime.now(),
      time: '14:30',
      notes: 'Paid to Swiggy',
      createdAt: DateTime.now(),
      source: 'sms_auto',
    );
    await moneyRepo.saveTransaction(tx);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          moneyRepositoryProvider.overrideWithValue(moneyRepo),
          moneyAutomationProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MoneyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Uncategorized'), findsOneWidget);
    expect(find.text('Add category to this transaction?'), findsOneWidget);
  });

  // 5. Assigning category updates transaction and removes prompt
  testWidgets('5. Selecting a category updates the transaction and immediately removes the prompt', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tx = Transaction(
      id: 'auto_tx_2',
      amount: 450.0,
      type: 'Expense',
      category: 'Uncategorized',
      date: DateTime.now(),
      time: '14:30',
      notes: 'Paid to Swiggy',
      createdAt: DateTime.now(),
      source: 'sms_auto',
    );
    await moneyRepo.saveTransaction(tx);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          moneyRepositoryProvider.overrideWithValue(moneyRepo),
          moneyAutomationProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MoneyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap prompt
    await tester.tap(find.text('Add category to this transaction?'));
    await tester.pumpAndSettle();

    // Verify modal appeared with categories
    expect(find.text('Select Category'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);

    // Pick 'Food'
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    // Verify category changed to Food and prompt is gone
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Add category to this transaction?'), findsNothing);
    expect(moneyRepo.getTransactions().first.category, 'Food');
  });

  // 6. Duplicate candidate does not create a second transaction
  test('6. Duplicate incoming SMS does not create a second expense', () async {
    await notifier.enableAutomation();

    final event = makeEvent(
      'HDFC Bank: Rs 500.00 debited from a/c **1234 to Store. Ref 445566. Avl bal Rs 9000.',
    );

    // First arrival
    fakeBridge.emitRawEvent(event);
    await Future<void>.delayed(Duration.zero);
    expect(moneyRepo.getTransactions().length, 1);

    // Duplicate arrival (redelivery / replay)
    fakeBridge.emitRawEvent(event);
    await Future<void>.delayed(Duration.zero);
    expect(moneyRepo.getTransactions().length, 1); // Still 1!
  });

  // 7. Automation OFF prevents transaction creation
  test('7. Automation OFF prevents auto-creation of transactions', () async {
    // Keep automation disabled
    expect(notifier.state.isEnabled, isFalse);

    final event = makeEvent(
      'Rs 500.00 debited from a/c **1234 to Store. Ref 112233. Avl bal Rs 9000.',
    );
    fakeBridge.emitRawEvent(event);
    await Future<void>.delayed(Duration.zero);

    expect(moneyRepo.getTransactions(), isEmpty);
  });

  // 8. Logout / user switch halts cross-user writes
  test('8. Logout clears active listener and halts auto-creation', () async {
    await notifier.enableAutomation();

    // User logs out
    await notifier.onLogout();

    final event = makeEvent(
      'Rs 500.00 debited from a/c **1234 to Store. Ref 889900. Avl bal Rs 9000.',
    );
    fakeBridge.emitRawEvent(event);
    await Future<void>.delayed(Duration.zero);

    expect(moneyRepo.getTransactions(), isEmpty);
  });

  // 9. Failed write does not permanently consume fingerprint
  test('9. Failed repository write does not finalize fingerprint, allowing subsequent retry', () async {
    await notifier.enableAutomation();

    final event = makeEvent(
      'Rs 500.00 debited from a/c **1234 to Cafe. Ref 778899. Avl bal Rs 9000.',
    );

    // Simulate database write failure
    moneyRepo.shouldFailOnSave = true;
    fakeBridge.emitRawEvent(event);
    await Future<void>.delayed(Duration.zero);

    expect(moneyRepo.getTransactions(), isEmpty);

    // Verify fingerprint was NOT finalized as processed
    final parsed = parser.parse(event);
    expect(dedupService.isDuplicate(parsed.fingerprint, referenceId: parsed.referenceId), isFalse);

    // Now database is healthy again
    moneyRepo.shouldFailOnSave = false;
    fakeBridge.emitRawEvent(event);
    await Future<void>.delayed(Duration.zero);

    // Successfully creates the transaction on retry!
    expect(moneyRepo.getTransactions().length, 1);
    expect(dedupService.isDuplicate(parsed.fingerprint, referenceId: parsed.referenceId), isTrue);
  });

  // 10. Raw SMS body is never stored in Transaction
  test('10. Created Transaction does not store raw SMS body or sensitive bank account details', () async {
    await notifier.enableAutomation();

    final event = makeEvent(
      'HDFC Bank: Rs 800.00 debited from a/c **9876 on 15-10-26 to Reliance Digital. Secret OTP 1122. Avl bal: Rs 10000.00',
    );
    fakeBridge.emitRawEvent(event);
    await Future<void>.delayed(Duration.zero);

    // Note: If text contains "Secret OTP", Phase 3 rejects it as OTP!
    // Let's use a confirmed debit text with sensitive card number:
    final cleanDebit = makeEvent(
      'Rs 800.00 debited from a/c **9876 to Reliance Fresh 9876543210. Ref 112233. Avl bal: Rs 10000.00',
    );
    fakeBridge.emitRawEvent(cleanDebit);
    await Future<void>.delayed(Duration.zero);

    final tx = moneyRepo.getTransactions().first;
    expect(tx.notes.contains('Avl bal'), isFalse);
    expect(tx.notes.contains('9876543210'), isFalse);
    expect(tx.notes.contains('XXXX3210'), isTrue);
  });
}
