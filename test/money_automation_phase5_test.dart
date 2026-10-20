import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/money_tracker/models/money_automation_listener_status.dart';
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

class ControllablePlatformBridge implements MoneyAutomationPlatformBridge {
  bool permissionGranted = true;
  bool isEnabledInNative = false;
  final StreamController<MoneyAutomationRawEvent> _controller =
      StreamController<MoneyAutomationRawEvent>.broadcast();

  @override
  bool get isPlatformSupported => true;

  @override
  Future<bool> checkPermission() async => permissionGranted;

  @override
  Future<String> requestPermission() async => permissionGranted ? 'granted' : 'denied';

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> setListenerEnabled(bool enabled) async {
    isEnabledInNative = enabled;
  }

  @override
  Stream<MoneyAutomationRawEvent> get eventStream => _controller.stream;

  void emit(MoneyAutomationRawEvent event) {
    if (isEnabledInNative) {
      _controller.add(event);
    }
  }

  void dispose() {
    _controller.close();
  }
}

class InMemoryMoneyRepository implements MoneyRepository {
  final List<Transaction> _transactions = [];
  bool shouldFailOnSave = false;
  final String _userId;

  InMemoryMoneyRepository({String userId = 'test_user_phase5'}) : _userId = userId;

  @override
  String? get userId => _userId;

  @override
  double getMonthlyBudget(String yearMonth) => 15000.0;

  @override
  Future<void> saveMonthlyBudget(String yearMonth, double amount) async {}

  @override
  List<Transaction> getTransactions() => List.unmodifiable(_transactions);

  @override
  Future<void> saveTransaction(Transaction tx) async {
    if (shouldFailOnSave) {
      throw Exception('Persistent database failure');
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late ControllablePlatformBridge bridge;
  late MoneyAutomationListenerService listenerService;
  late MoneyAutomationRepository autoRepo;
  late InMemoryMoneyRepository moneyRepo;
  late MoneyTransactionParser parser;
  late MoneyDeduplicationService dedupService;
  late MoneyAutomationNotifier notifier;

  MoneyAutomationRawEvent makeDebitEvent({
    String body = 'HDFC Bank: Rs 850.00 debited from a/c **1122 on 15-10-26 to Zomato. UPI Ref: 987654321098. Avl bal: Rs 14000.00',
    String sender = 'HDFCBK',
  }) {
    return MoneyAutomationRawEvent(
      sender: sender,
      body: body,
      timestamp: DateTime(2026, 10, 15, 12, 0),
      sourceType: 'sms',
    );
  }

  setUp(() {
    MoneyDeduplicationService.resetInMemoryStorage();
    bridge = ControllablePlatformBridge();
    listenerService = MoneyAutomationListenerService(bridge: bridge);
    autoRepo = MoneyAutomationRepository(inMemoryOnly: true);
    moneyRepo = InMemoryMoneyRepository();
    parser = MoneyTransactionParser();
    dedupService = MoneyDeduplicationService(inMemoryOnly: true);
    dedupService.initForUser('test_user_phase5');

    notifier = MoneyAutomationNotifier(
      autoRepo,
      'test_user_phase5',
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
    bridge.dispose();
    dedupService.clear();
  });

  // 1. Permission revoked and restored
  test('1. Permission revocation transitions to permissionRequired; restoration returns to ready', () async {
    await notifier.enableAutomation();
    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.ready);
    expect(bridge.isEnabledInNative, isTrue);

    // Simulate system settings revocation
    bridge.permissionGranted = false;
    await notifier.checkListenerHealth();
    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.permissionRequired);

    // Simulate user restoring permission in settings and app resuming
    bridge.permissionGranted = true;
    notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.ready);
  });

  // 2. Automation OFF blocks processing
  test('2. Automation OFF blocks processing and drops incoming events immediately', () async {
    // Feature is OFF by default
    expect(notifier.state.isEnabled, isFalse);
    expect(bridge.isEnabledInNative, isFalse);

    bridge.emit(makeDebitEvent());
    await Future<void>.delayed(Duration.zero);

    expect(moneyRepo.getTransactions(), isEmpty);
  });

  // 3. Duplicate after restart still rejected
  test('3. Duplicate candidate after simulated process restart is still rejected', () async {
    await notifier.enableAutomation();

    final event = makeDebitEvent();
    bridge.emit(event);
    await Future<void>.delayed(Duration.zero);

    expect(moneyRepo.getTransactions().length, 1);

    // Simulate process restart: reload state with existing deduplication set
    final restartedDedupService = MoneyDeduplicationService(inMemoryOnly: true);

    final restartedNotifier = MoneyAutomationNotifier(
      autoRepo,
      'test_user_phase5',
      listenerService: listenerService,
      parser: parser,
      deduplicationService: restartedDedupService,
      moneyRepository: moneyRepo,
    );
    addTearDown(() {
      if (restartedNotifier.mounted) restartedNotifier.dispose();
    });
    await restartedNotifier.enableAutomation();

    // Replay same event after restart
    bridge.emit(event);
    await Future<void>.delayed(Duration.zero);

    // Total transactions must still be exactly 1
    expect(moneyRepo.getTransactions().length, 1);
  });

  // 4. Deleting auto-added transaction does not recreate it
  test('4. Manually deleted auto-added transaction is not recreated upon redelivery', () async {
    await notifier.enableAutomation();

    final event = makeDebitEvent();
    bridge.emit(event);
    await Future<void>.delayed(Duration.zero);

    expect(moneyRepo.getTransactions().length, 1);
    final txId = moneyRepo.getTransactions().first.id;

    // User deletes the transaction
    await moneyRepo.deleteTransaction(txId);
    expect(moneyRepo.getTransactions(), isEmpty);

    // Redeliver or replay same event
    bridge.emit(event);
    await Future<void>.delayed(Duration.zero);

    // Transaction is not recreated; deletion is respected
    expect(moneyRepo.getTransactions(), isEmpty);
  });

  // 5. User switch isolation
  test('5. User switch ensures User A cache is purged and User B is fully isolated', () async {
    await notifier.enableAutomation();
    bridge.emit(makeDebitEvent());
    await Future<void>.delayed(Duration.zero);
    expect(moneyRepo.getTransactions().length, 1);

    // User A logs out
    await notifier.onLogout();
    expect(notifier.state.isEnabled, isFalse);
    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.disabled);
    expect(bridge.isEnabledInNative, isFalse);
    expect(dedupService.processedFingerprints, isEmpty);

    // User B arrives with separate repository
    final userBRepo = InMemoryMoneyRepository(userId: 'user_b');
    final userBAutoRepo = MoneyAutomationRepository(inMemoryOnly: true);
    final userBDedupService = MoneyDeduplicationService(inMemoryOnly: true);
    userBDedupService.initForUser('user_b');

    final userBNotifier = MoneyAutomationNotifier(
      userBAutoRepo,
      'user_b',
      listenerService: listenerService,
      parser: parser,
      deduplicationService: userBDedupService,
      moneyRepository: userBRepo,
    );
    addTearDown(() {
      if (userBNotifier.mounted) userBNotifier.dispose();
    });

    // User B starts with feature disabled
    expect(userBNotifier.state.isEnabled, isFalse);
    bridge.emit(makeDebitEvent());
    await Future<void>.delayed(Duration.zero);
    expect(userBRepo.getTransactions(), isEmpty);
  });

  // 6. Save failure allows retry
  test('6. Save failure does not lock deduplication fingerprint, allowing subsequent retry', () async {
    await notifier.enableAutomation();

    // Trigger failure on save
    moneyRepo.shouldFailOnSave = true;
    final event = makeDebitEvent();
    bridge.emit(event);
    await Future<void>.delayed(Duration.zero);

    // Save failed, no transaction created, fingerprint was not locked
    expect(moneyRepo.getTransactions(), isEmpty);
    expect(dedupService.processedFingerprints, isEmpty);

    // Restore save ability and retry
    moneyRepo.shouldFailOnSave = false;
    bridge.emit(event);
    await Future<void>.delayed(Duration.zero);

    expect(moneyRepo.getTransactions().length, 1);
    expect(dedupService.processedFingerprints.length, 1);
  });

  // 7. Raw SMS not persisted
  test('7. Raw SMS text is never stored in transaction notes or model fields', () async {
    await notifier.enableAutomation();

    const rawSms = 'HDFC Bank: Rs 1,499.00 debited from a/c **4455 on 15-10-26 to Blinkit. UPI Ref: 112233445566. Avl bal: Rs 5000.00. Secret promo code: SAVE50.';
    bridge.emit(makeDebitEvent(body: rawSms));
    await Future<void>.delayed(Duration.zero);

    final tx = moneyRepo.getTransactions().first;
    expect(tx.notes, 'Paid to Blinkit');
    expect(tx.notes.contains('Secret promo code'), isFalse);
    expect(tx.notes.contains('4455'), isFalse);
    expect(tx.source, 'sms_auto');
  });

  // 8. Category prompt disappears after category assignment
  testWidgets('8. Category prompt appears only for automatic uncategorized transactions and disappears upon assignment', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Manual transaction with Uncategorized should NOT show the prompt
    final manualTx = Transaction(
      id: 'manual_tx',
      amount: 300.0,
      type: 'Expense',
      category: 'Uncategorized',
      date: DateTime.now(),
      time: '12:00',
      notes: 'Manual cash',
      createdAt: DateTime.now(),
      source: 'manual',
    );

    // 2. Auto transaction with Uncategorized SHOULD show the prompt
    final autoTx = Transaction(
      id: 'auto_tx',
      amount: 850.0,
      type: 'Expense',
      category: 'Uncategorized',
      date: DateTime.now(),
      time: '12:30',
      notes: 'Paid to Zomato',
      createdAt: DateTime.now(),
      source: 'sms_auto',
    );

    await moneyRepo.saveTransaction(manualTx);
    await moneyRepo.saveTransaction(autoTx);

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

    // Exactly one prompt should be found (for autoTx, not manualTx)
    expect(find.text('Add category to this transaction?'), findsOneWidget);

    // Tap prompt and assign category
    await tester.tap(find.text('Add category to this transaction?'));
    await tester.pumpAndSettle();

    expect(find.text('Select Category'), findsOneWidget);
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    // Prompt is now permanently gone
    expect(find.text('Add category to this transaction?'), findsNothing);
    final updatedAutoTx = moneyRepo.getTransactions().firstWhere((t) => t.id == 'auto_tx');
    expect(updatedAutoTx.category, 'Food');
    expect(updatedAutoTx.source, 'sms_auto');
  });
}
