import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/money_tracker/models/money_automation_raw_event.dart';
import 'package:arc/features/money_tracker/models/money_transaction_classification.dart';
import 'package:arc/features/money_tracker/models/parsed_money_transaction.dart';
import 'package:arc/features/money_tracker/providers/money_automation_provider.dart';
import 'package:arc/features/money_tracker/repository/money_automation_repository.dart';
import 'package:arc/features/money_tracker/services/money_automation_listener_service.dart';
import 'package:arc/features/money_tracker/services/money_automation_platform_bridge.dart';
import 'package:arc/features/money_tracker/services/money_deduplication_service.dart';
import 'package:arc/features/money_tracker/services/money_transaction_parser.dart';

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

void main() {
  late MoneyTransactionParser parser;
  late MoneyDeduplicationService dedupService;

  setUp(() {
    parser = MoneyTransactionParser();
    dedupService = MoneyDeduplicationService();
    dedupService.initForUser('test_user_phase3');
  });

  tearDown(() {
    dedupService.clear();
  });

  MoneyAutomationRawEvent makeEvent(String body, {String sender = 'HDFCBK'}) {
    return MoneyAutomationRawEvent(
      sender: sender,
      body: body,
      timestamp: DateTime(2026, 10, 15, 14, 30),
      sourceType: 'sms',
    );
  }

  // 1. Confirmed debit accepted
  test('1. Confirmed debit accepted with high confidence', () {
    final event = makeEvent(
      'HDFC Bank: Rs 450.00 debited from a/c **1234 on 12-10-26 to Swiggy. UPI Ref: 123456789012. Avl bal: Rs 15400.00',
    );
    final result = parser.parse(event);

    expect(result.classification, MoneyTransactionClassification.confirmedDebit);
    expect(result.confidence, MoneyTransactionConfidence.high);
    expect(result.amount, 450.0);
    expect(result.currency, 'INR');
    expect(result.referenceId, '123456789012');
    expect(result.accountMask, 'XXXX1234');
    expect(result.merchantOrDescription, 'Swiggy');
    expect(result.isConfirmedDebit, isTrue);
  });

  // 2. OTP rejected
  test('2. OTP message strictly rejected regardless of amount/debit language', () {
    final event = makeEvent(
      '123456 is your OTP for transaction of Rs 500.00 at Swiggy on your card ending 1234. Do not share this OTP with anyone.',
    );
    final result = parser.parse(event);

    expect(result.classification, MoneyTransactionClassification.otp);
    expect(result.confidence, MoneyTransactionConfidence.high);
    expect(result.isConfirmedDebit, isFalse);
    expect(result.amount, 0.0);
  });

  // 3. Credit rejected
  test('3. Credit / incoming money message strictly rejected', () {
    final event = makeEvent(
      'Your a/c **1234 is credited with INR 5,000.00 on 12-10-26 by transfer from John Doe. Ref: 987654. Avl bal INR 20,400.00.',
    );
    final result = parser.parse(event);

    expect(result.classification, MoneyTransactionClassification.credit);
    expect(result.confidence, MoneyTransactionConfidence.high);
    expect(result.isConfirmedDebit, isFalse);
  });

  // 4. Failed / declined transaction rejected
  test('4. Failed, declined, or reversed transaction rejected', () {
    final event = makeEvent(
      'Transaction of Rs 1,500.00 on card ending 1234 at Flipkart failed due to technical error. If debited, amount will be refunded.',
    );
    final result = parser.parse(event);

    expect(result.classification, MoneyTransactionClassification.failed);
    expect(result.confidence, MoneyTransactionConfidence.high);
    expect(result.isConfirmedDebit, isFalse);
  });

  // 5. Balance alert rejected
  test('5. Balance enquiry or alert rejected without debit', () {
    final event = makeEvent(
      'Dear Customer, available balance in your A/c ending 1234 is INR 4,520.00 as on 15-10-26. Call 1800xxx for mini statement.',
    );
    final result = parser.parse(event);

    expect(result.classification, MoneyTransactionClassification.balanceAlert);
    expect(result.confidence, MoneyTransactionConfidence.high);
    expect(result.isConfirmedDebit, isFalse);
  });

  // 6. Amount extraction works accurately without confusing balance or account
  test('6. Amount extraction accurately extracts transaction amount and ignores balance', () {
    final event = makeEvent(
      'Your A/C ending 4321 is debited by INR 1,250.75 on 14/10/26 transfer to Amazon Pay. Ref No 9876543210. Bal: INR 55,000.00',
    );
    final result = parser.parse(event);

    expect(result.amount, 1250.75);
    expect(result.accountMask, 'XXXX4321');
    expect(result.referenceId, '9876543210');
    expect(result.classification, MoneyTransactionClassification.confirmedDebit);
  });

  // 7. Duplicate fingerprint rejected
  test('7. Deduplication service rejects duplicate fingerprint', () async {
    const fingerprint = 'fae7829a98210381029381092381203981209381203981209381209381209381';

    expect(dedupService.isDuplicate(fingerprint), isFalse);

    await dedupService.recordProcessed(fingerprint);

    expect(dedupService.isDuplicate(fingerprint), isTrue);
  });

  // 8. Same reference ID rejected as duplicate
  test('8. Same reference ID rejected as duplicate across different fingerprints', () async {
    const refId = 'UPI429018239012';
    const fingerprint1 = 'fp_1111111111111111111111111111111111111111111111111111111111111111';
    const fingerprint2 = 'fp_2222222222222222222222222222222222222222222222222222222222222222';

    await dedupService.recordProcessed(fingerprint1, referenceId: refId);

    // Second event has a different fingerprint but identical bank reference ID
    expect(dedupService.isDuplicate(fingerprint2, referenceId: refId), isTrue);
  });

  // 9. Malformed SMS does not crash
  test('9. Malformed SMS or empty string safely produces unknown without exception', () {
    final emptyEvent = makeEvent('');
    final emptyResult = parser.parse(emptyEvent);
    expect(emptyResult.classification, MoneyTransactionClassification.unknown);
    expect(emptyResult.confidence, MoneyTransactionConfidence.low);

    final garbageEvent = makeEvent('~!@#\$%^&*()_+{}|:"<>?[]\\;\',./`');
    final garbageResult = parser.parse(garbageEvent);
    expect(garbageResult.classification, MoneyTransactionClassification.unknown);
    expect(garbageResult.confidence, MoneyTransactionConfidence.low);
  });

  // 10. Unknown / non-transactional SMS rejected
  test('10. Non-transactional conversational SMS rejected', () {
    final event = makeEvent(
      'Hey, are we still meeting for lunch today at 1 PM?',
      sender: '+919876543210',
    );
    final result = parser.parse(event);

    expect(result.classification, MoneyTransactionClassification.unknown);
    expect(result.confidence, MoneyTransactionConfidence.low);
    expect(result.isConfirmedDebit, isFalse);
  });

  // 11. Raw content not persisted in ParsedMoneyTransaction
  test('11. Parsed model does not store raw SMS body and toString is sanitized', () {
    final event = makeEvent(
      'HDFC Bank: Rs 500 debited from a/c **9999 to Swiggy. Ref 112233. Secret PIN 9988.',
    );
    final result = parser.parse(event);

    // Verify toString does NOT leak secret text or raw body
    final str = result.toString();
    expect(str.contains('Secret PIN'), isFalse);
    expect(str.contains('9988'), isFalse);
    expect(str.contains('rawBody'), isFalse);
  });

  // 12. Sensitive identifier masking
  test('12. Sensitive financial identifiers in description are masked', () {
    final event = makeEvent(
      'Paid Rs 300 to Store 987654321098 from A/c ending 9876. Ref 55555.',
    );
    final result = parser.parse(event);

    expect(result.accountMask, 'XXXX9876');
    expect(result.merchantOrDescription?.contains('987654321098'), isFalse);
    expect(result.merchantOrDescription?.contains('XXXX1098'), isTrue);
  });

  // 13. ATM cash withdrawal accepted as confirmedDebit
  test('13. ATM cash withdrawal recognized as confirmedDebit outgoing spending', () {
    final event = makeEvent(
      'Rs 2,000.00 withdrawn at SBI ATM from A/c XX4321 on 12-10-26. Txn# 48921. Available Bal: Rs 8,000.00',
    );
    final result = parser.parse(event);

    expect(result.classification, MoneyTransactionClassification.confirmedDebit);
    expect(result.confidence, MoneyTransactionConfidence.high);
    expect(result.amount, 2000.0);
    expect(result.accountMask, 'XXXX4321');
    expect(result.referenceId, '48921');
    expect(result.isConfirmedDebit, isTrue);
  });

  // 14. Full pipeline integration via MoneyAutomationNotifier
  test('14. Full pipeline integration: confirmed debit arrives on acceptedCandidateStream, duplicate and OTP are rejected', () async {
    final fakeBridge = FakeMoneyAutomationPlatformBridge();
    final listenerService = MoneyAutomationListenerService(bridge: fakeBridge);
    final repo = MoneyAutomationRepository(inMemoryOnly: true);

    final notifier = MoneyAutomationNotifier(
      repo,
      'user_pipeline_test',
      listenerService: listenerService,
      parser: parser,
      deduplicationService: dedupService,
    );

    // Enable automation
    await notifier.enableAutomation();

    final candidates = <ParsedMoneyTransaction>[];
    final sub = notifier.acceptedCandidateStream.listen((c) => candidates.add(c));

    // 1. Emit confirmed debit
    final debitEvent = makeEvent(
      'Rs 650.00 debited from a/c **1111 on 15-10-26 to Zomato. Ref 998877. Avl bal Rs 5000.',
    );
    fakeBridge.emitRawEvent(debitEvent);
    await Future<void>.delayed(Duration.zero);

    expect(candidates.length, 1);
    expect(candidates.first.amount, 650.0);
    expect(candidates.first.merchantOrDescription, 'Zomato');

    // 2. Emit duplicate of same transaction (same Ref) -> must be dropped
    fakeBridge.emitRawEvent(debitEvent);
    await Future<void>.delayed(Duration.zero);

    expect(candidates.length, 1); // Still 1, duplicate rejected!

    // 3. Emit OTP -> must be dropped
    final otpEvent = makeEvent(
      '987654 is your OTP for transaction of Rs 650.00. Do not share.',
    );
    fakeBridge.emitRawEvent(otpEvent);
    await Future<void>.delayed(Duration.zero);

    expect(candidates.length, 1); // Still 1, OTP rejected!

    await sub.cancel();
    notifier.dispose();
    fakeBridge.dispose();
  });
}
