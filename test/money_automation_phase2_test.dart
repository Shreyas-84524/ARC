import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/money_tracker/models/money_automation_listener_status.dart';
import 'package:arc/features/money_tracker/models/money_automation_raw_event.dart';
import 'package:arc/features/money_tracker/repository/money_automation_repository.dart';
import 'package:arc/features/money_tracker/services/money_automation_listener_service.dart';
import 'package:arc/features/money_tracker/services/money_automation_platform_bridge.dart';
import 'package:arc/features/money_tracker/providers/money_automation_provider.dart';

/// Test double simulating Android platform SMS bridge behavior.
class FakeMoneyAutomationPlatformBridge implements MoneyAutomationPlatformBridge {
  @override
  bool isPlatformSupported = true;

  bool hasPermission = true;
  String requestPermissionResponse = 'granted';
  bool isListenerEnabled = false;
  int openAppSettingsCount = 0;

  final StreamController<MoneyAutomationRawEvent> _streamController =
      StreamController<MoneyAutomationRawEvent>.broadcast();

  @override
  Future<bool> checkPermission() async => hasPermission;

  @override
  Future<String> requestPermission() async => requestPermissionResponse;

  @override
  Future<void> openAppSettings() async {
    openAppSettingsCount++;
  }

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
  late MoneyAutomationRepository repo;
  late FakeMoneyAutomationPlatformBridge fakeBridge;
  late MoneyAutomationListenerService listenerService;

  setUp(() {
    repo = MoneyAutomationRepository(inMemoryOnly: true);
    fakeBridge = FakeMoneyAutomationPlatformBridge();
    listenerService = MoneyAutomationListenerService(bridge: fakeBridge);
  });

  tearDown(() {
    fakeBridge.dispose();
    listenerService.dispose();
  });

  // 1. Automation OFF -> listener does not process events
  test('1. Automation OFF -> listener does not process incoming events', () async {
    final notifier = MoneyAutomationNotifier(
      repo,
      'user_123',
      listenerService: listenerService,
    );

    expect(notifier.state.isEnabled, isFalse);
    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.disabled);
    expect(fakeBridge.isListenerEnabled, isFalse);

    final receivedEvents = <MoneyAutomationRawEvent>[];
    final sub = notifier.eventStream.listen(receivedEvents.add);

    // Emit event from fake bridge
    fakeBridge.emitRawEvent(
      MoneyAutomationRawEvent(
        sender: 'HDFCBK',
        body: 'Rs 500 debited from A/C',
        timestamp: DateTime.now(),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 50));

    // Because automation is OFF, no events should be forwarded into ARC
    expect(receivedEvents, isEmpty);
    await sub.cancel();
    notifier.dispose();
  });

  // 2. Automation ON + permission -> listener becomes ready
  test('2. Automation ON + permission -> listener becomes ready and receives events', () async {
    fakeBridge.hasPermission = true;
    fakeBridge.requestPermissionResponse = 'granted';

    final notifier = MoneyAutomationNotifier(
      repo,
      'user_123',
      listenerService: listenerService,
    );

    final success = await notifier.enableAutomation();

    expect(success, isTrue);
    expect(notifier.state.isEnabled, isTrue);
    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.ready);
    expect(fakeBridge.isListenerEnabled, isTrue);

    final receivedEvents = <MoneyAutomationRawEvent>[];
    final sub = notifier.eventStream.listen(receivedEvents.add);

    fakeBridge.emitRawEvent(
      MoneyAutomationRawEvent(
        sender: 'SBIINB',
        body: 'INR 1,200 spent on Card',
        timestamp: DateTime.now(),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 50));

    expect(receivedEvents.length, 1);
    expect(receivedEvents.first.sender, 'SBIINB');

    await sub.cancel();
    notifier.dispose();
  });

  // 3. Permission denied -> correct state
  test('3. Permission denied -> enters permissionRequired state', () async {
    fakeBridge.hasPermission = false;
    fakeBridge.requestPermissionResponse = 'denied';

    final notifier = MoneyAutomationNotifier(
      repo,
      'user_123',
      listenerService: listenerService,
    );

    final success = await notifier.enableAutomation();

    expect(success, isFalse);
    expect(notifier.state.isEnabled, isTrue); // Opt-in requested
    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.permissionRequired);
    expect(fakeBridge.isListenerEnabled, isFalse);

    notifier.dispose();
  });

  // 4. Permission revoked -> listener state updates to permissionRequired
  test('4. Permission revoked -> health check transitions state to permissionRequired', () async {
    fakeBridge.hasPermission = true;
    fakeBridge.requestPermissionResponse = 'granted';

    final notifier = MoneyAutomationNotifier(
      repo,
      'user_123',
      listenerService: listenerService,
    );

    await notifier.enableAutomation();
    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.ready);

    // Simulate user revoking permission in Android system settings
    fakeBridge.hasPermission = false;

    // ARC health check runs (e.g. on screen resume)
    await notifier.checkListenerHealth();

    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.permissionRequired);

    notifier.dispose();
  });

  // 5. Logout -> listener processing stops and resets
  test('5. Logout -> listener processing stops and listener status resets to disabled', () async {
    fakeBridge.hasPermission = true;
    fakeBridge.requestPermissionResponse = 'granted';

    final notifier = MoneyAutomationNotifier(
      repo,
      'user_123',
      listenerService: listenerService,
    );

    await notifier.enableAutomation();
    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.ready);
    expect(fakeBridge.isListenerEnabled, isTrue);

    // User logs out
    await notifier.onLogout();

    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.disabled);
    expect(fakeBridge.isListenerEnabled, isFalse);

    notifier.dispose();
  });

  // 6. User switching respects separate preferences
  test('6. User switching respects separate preferences and listener statuses', () async {
    fakeBridge.hasPermission = true;
    fakeBridge.requestPermissionResponse = 'granted';

    // User A enables automation
    final notifierUserA = MoneyAutomationNotifier(
      repo,
      'user_A',
      listenerService: listenerService,
    );
    await notifierUserA.enableAutomation();
    expect(notifierUserA.state.isEnabled, isTrue);
    expect(notifierUserA.state.listenerStatus, MoneyAutomationListenerStatus.ready);
    notifierUserA.dispose();
    await listenerService.stopListening();

    // User B logs in (has not enabled automation)
    final notifierUserB = MoneyAutomationNotifier(
      repo,
      'user_B',
      listenerService: listenerService,
    );
    await Future<void>.delayed(Duration.zero);
    expect(notifierUserB.state.isEnabled, isFalse);
    expect(notifierUserB.state.listenerStatus, MoneyAutomationListenerStatus.disabled);
    expect(fakeBridge.isListenerEnabled, isFalse);
    notifierUserB.dispose();

    // User A logs back in
    final notifierUserAReturns = MoneyAutomationNotifier(
      repo,
      'user_A',
      listenerService: listenerService,
    );
    await notifierUserAReturns.checkListenerHealth();
    expect(notifierUserAReturns.state.isEnabled, isTrue);
    expect(notifierUserAReturns.state.listenerStatus, MoneyAutomationListenerStatus.ready);
    expect(fakeBridge.isListenerEnabled, isTrue);
    notifierUserAReturns.dispose();
  });

  // 7. Unsupported platform handled safely
  test('7. Unsupported platform handled safely (returns unavailable without crashing)', () async {
    fakeBridge.isPlatformSupported = false;

    final notifier = MoneyAutomationNotifier(
      repo,
      'user_web',
      listenerService: listenerService,
    );

    final success = await notifier.enableAutomation();

    expect(success, isFalse);
    expect(notifier.state.listenerStatus, MoneyAutomationListenerStatus.unavailable);
    expect(fakeBridge.isListenerEnabled, isFalse);

    notifier.dispose();
  });

  // 8. Raw event is transient and not persisted
  test('8. Raw event model is transient: sanitized toString and never persisted', () {
    final event = MoneyAutomationRawEvent(
      sender: 'HDFCBK',
      body: 'Dear Customer, INR 450.00 debited from A/C **1234 on 15-OCT. Info: CAFE.',
      timestamp: DateTime(2026, 10, 15, 12, 0),
    );

    // Verify toString does NOT leak full body, amount, or personal info
    final stringRep = event.toString();
    expect(stringRep.contains('450.00'), isFalse);
    expect(stringRep.contains('1234'), isFalse);
    expect(stringRep.contains('CAFE'), isFalse);
    expect(stringRep.contains('length: ${event.body.length}'), isTrue);

    // Verify repository does NOT store any event bodies
    final state = repo.loadState('user_123');
    expect(state.isEnabled, isFalse);
  });
}
