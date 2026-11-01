import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/money_tracker/models/money_automation_raw_event.dart';
import 'package:arc/features/money_tracker/models/money_automation_listener_status.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/providers/money_automation_provider.dart';
import 'package:arc/features/money_tracker/repository/money_automation_repository.dart';
import 'package:arc/features/money_tracker/services/money_automation_listener_service.dart';
import 'package:arc/features/money_tracker/services/money_deduplication_service.dart';
import 'package:arc/features/money_tracker/services/money_transaction_parser.dart';

import 'money_automation_phase4_test.dart'
    show FakeMoneyAutomationPlatformBridge, InMemoryMoneyRepository;

class DelayedMoneyRepository extends InMemoryMoneyRepository {
  final saveGate = Completer<void>();

  @override
  Future<void> saveTransaction(Transaction tx) async {
    await saveGate.future;
    await super.saveTransaction(tx);
  }
}

MoneyAutomationRawEvent event(String body) => MoneyAutomationRawEvent(
  sender: 'BANK',
  body: body,
  timestamp: DateTime(2026, 10, 28, 12),
  sourceType: 'sms',
);

void main() {
  test('Separate equal purchases without references retain distinct identities', () {
    final parser = MoneyTransactionParser();
    final first = event('Rs 500 debited to Shop on 28-10-2026');
    final later = MoneyAutomationRawEvent(
      sender: first.sender, body: first.body,
      timestamp: first.timestamp.add(const Duration(hours: 1)), sourceType: 'sms',
    );
    expect(parser.parse(first).fingerprint, isNot(parser.parse(later).fingerprint));
    expect(parser.parse(first).fingerprint, parser.parse(first).fingerprint);
  });
  test('Debit can equal the remaining balance', () {
    final result = MoneyTransactionParser().parse(
      event('Rs 500 debited from A/c XX1234. Avl Bal Rs 500.'),
    );
    expect(result.isConfirmedDebit, isTrue);
    expect(result.amount, 500);
  });

  test('UPI prose is not a reference and does not hide a later reference', () {
    final parser = MoneyTransactionParser();
    expect(parser.parse(event('UPI payment of Rs 500 to Shop')).referenceId, isNull);
    expect(parser.parse(event('UPI payment of Rs 500 to Shop Ref 123456789')).referenceId,
        '123456789');
  });

  test('Overlapping deliveries create only one expense', () async {
    final bridge = FakeMoneyAutomationPlatformBridge();
    final repository = DelayedMoneyRepository();
    final notifier = MoneyAutomationNotifier(
      MoneyAutomationRepository(inMemoryOnly: true), 'overlap_test',
      listenerService: MoneyAutomationListenerService(bridge: bridge),
      moneyRepository: repository,
    );
    addTearDown(() { notifier.dispose(); bridge.dispose(); });
    await notifier.enableAutomation();
    final debit = event('Rs 500 debited from A/c XX1234. Ref 123456789');
    bridge.emitRawEvent(debit);
    bridge.emitRawEvent(debit);
    await Future<void>.delayed(Duration.zero);
    repository.saveGate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(repository.getTransactions(), hasLength(1));
  });

  test('Unavailable repository never marks a transaction as processed', () async {
    final bridge = FakeMoneyAutomationPlatformBridge();
    final dedup = MoneyDeduplicationService();
    final notifier = MoneyAutomationNotifier(
      MoneyAutomationRepository(inMemoryOnly: true), 'missing_repository',
      listenerService: MoneyAutomationListenerService(bridge: bridge),
      deduplicationService: dedup,
    );
    addTearDown(() { notifier.dispose(); bridge.dispose(); });
    await notifier.enableAutomation();
    bridge.emitRawEvent(event('Rs 500 debited from A/c XX1234. Ref 123456789'));
    await Future<void>.delayed(Duration.zero);
    expect(dedup.processedFingerprints, isEmpty);
    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.error);
  });
}
