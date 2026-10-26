import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:arc/core/notifications/notification_models.dart';
import 'package:arc/core/notifications/notification_service.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/services/feedback_acknowledgement_service.dart';

class MockNotificationGateway implements LocalNotificationGateway {
  final List<ArcNotificationSpec> shownNotifications = [];
  final List<ArcNotificationSpec> scheduledNotifications = [];
  bool initialized = true;

  @override
  bool get isInitialized => initialized;

  @override
  String get timezoneName => 'UTC';

  @override
  Stream<ArcNotificationPayload> get notificationTaps => const Stream.empty();

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<ArcNotificationPermissionState> permissionState() async =>
      ArcNotificationPermissionState.granted;

  @override
  Future<ArcNotificationPermissionState> requestPermission() async =>
      ArcNotificationPermissionState.granted;

  @override
  Future<List<ArcPendingNotification>> pendingNotifications() async => const [];

  @override
  Future<void> schedule(ArcNotificationSpec spec) async {
    scheduledNotifications.add(spec);
  }

  @override
  Future<void> show(ArcNotificationSpec spec) async {
    shownNotifications.add(spec);
  }

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> dispose() async {}
}

class InMemoryBox implements Box {
  final Map<dynamic, dynamic> _store = {};

  @override
  Iterable get keys => _store.keys;

  @override
  Iterable get values => _store.values;

  @override
  int get length => _store.length;

  @override
  bool get isEmpty => _store.isEmpty;

  @override
  bool get isNotEmpty => _store.isNotEmpty;

  @override
  bool get isOpen => true;

  @override
  String get name => 'mock_box';

  @override
  String? get path => null;

  @override
  bool get lazy => false;

  @override
  dynamic get(key, {defaultValue}) => _store.containsKey(key) ? _store[key] : defaultValue;

  @override
  dynamic getAt(int index) => _store.values.elementAt(index);

  @override
  Future<void> put(key, value) async {
    _store[key] = value;
  }

  @override
  Future<void> putAt(int index, value) async {
    final k = _store.keys.elementAt(index);
    _store[k] = value;
  }

  @override
  Future<void> putAll(Map entries) async {
    _store.addAll(entries);
  }

  @override
  Future<void> delete(key) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAt(int index) async {
    final k = _store.keys.elementAt(index);
    _store.remove(k);
  }

  @override
  Future<void> deleteAll(Iterable keys) async {
    for (final k in keys) {
      _store.remove(k);
    }
  }

  @override
  Future<int> clear() async {
    final count = _store.length;
    _store.clear();
    return count;
  }

  @override
  bool containsKey(key) => _store.containsKey(key);

  @override
  Map toMap() => Map.unmodifiable(_store);

  @override
  Future<void> compact() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteFromDisk() async {}

  @override
  Future<void> flush() async {}

  @override
  dynamic keyAt(int index) => _store.keys.elementAt(index);

  @override
  Iterable valuesBetween({dynamic startKey, dynamic endKey}) => const [];

  @override
  Future<int> add(value) async {
    final key = _store.length;
    _store[key] = value;
    return key;
  }

  @override
  Future<Iterable<int>> addAll(Iterable values) async {
    final keys = <int>[];
    for (final v in values) {
      keys.add(await add(v));
    }
    return keys;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('FeedbackAcknowledgementService Tests', () {
    late MockNotificationGateway gateway;
    late InMemoryBox mockBox;
    late FeedbackAcknowledgementService service;

    setUp(() {
      gateway = MockNotificationGateway();
      mockBox = InMemoryBox();
      service = FeedbackAcknowledgementService(
        gateway: gateway,
        boxOverride: mockBox,
      );
    });

    FeedbackModel makeFeedback({
      required String id,
      required String category,
      String status = FeedbackStatus.acknowledged,
      DateTime? acknowledgedAt,
    }) {
      return FeedbackModel(
        feedbackId: id,
        userId: 'test_user_1',
        category: category,
        module: 'tasks',
        message: 'Sample test narrative',
        appVersion: '1.3.5',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        status: status,
        acknowledgedAt: acknowledgedAt ?? DateTime.now(),
        notificationDelivered: false,
      );
    }

    test('All 4 categories produce exact required notification messages', () {
      final (bugTitle, bugMsg) =
          FeedbackAcknowledgementService.getNotificationContent(FeedbackCategory.bugReport);
      expect(bugTitle, 'Thank You!');
      expect(bugMsg, 'Thanks for reporting the bug! Your feedback has been reviewed.');

      final (featTitle, featMsg) =
          FeedbackAcknowledgementService.getNotificationContent(FeedbackCategory.featureRequest);
      expect(featTitle, 'Thank You!');
      expect(featMsg, 'Thanks for your suggestion! We appreciate your ideas for improving Arc.');

      final (genTitle, genMsg) =
          FeedbackAcknowledgementService.getNotificationContent(FeedbackCategory.generalFeedback);
      expect(genTitle, 'Thank You!');
      expect(genMsg, 'Thanks for sharing your feedback! Your input means a lot to us.');

      final (rateTitle, rateMsg) =
          FeedbackAcknowledgementService.getNotificationContent(FeedbackCategory.appRating);
      expect(rateTitle, 'Thank You!');
      expect(rateMsg, 'Thanks for rating Arc! We appreciate your support.');
    });

    test('First-run behavior seeds historical acknowledgements without firing notifications', () async {
      final historicalItems = [
        makeFeedback(
          id: 'hist-1',
          category: FeedbackCategory.bugReport,
          acknowledgedAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
        makeFeedback(
          id: 'hist-2',
          category: FeedbackCategory.featureRequest,
          acknowledgedAt: DateTime.now().subtract(const Duration(days: 14)),
        ),
      ];

      await service.processFeedbackList(
        userId: 'test_user_1',
        feedbackList: historicalItems,
      );

      // Verify zero notifications fired on historical first run seed
      expect(gateway.shownNotifications, isEmpty);

      // Verify both items were marked in the box
      expect(service.isAcknowledgedLocally('test_user_1', 'hist-1'), isTrue);
      expect(service.isAcknowledgedLocally('test_user_1', 'hist-2'), isTrue);
    });

    test('First-run reconciliation delivers recent acknowledgements within 24h while seeding older ones', () async {
      final mixedItems = [
        makeFeedback(
          id: 'old-1',
          category: FeedbackCategory.bugReport,
          acknowledgedAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        makeFeedback(
          id: 'recent-1',
          category: FeedbackCategory.featureRequest,
          acknowledgedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ];

      await service.processFeedbackList(
        userId: 'test_user_1',
        feedbackList: mixedItems,
      );

      // Only the recent item triggers a notification (recent acknowledgements not silently lost)
      expect(gateway.shownNotifications.length, 1);
      expect(gateway.shownNotifications.first.entityId, 'recent-1');
      expect(gateway.shownNotifications.first.body, contains('Thanks for your suggestion!'));

      // Both items are now recorded in the deduplication box
      expect(service.isAcknowledgedLocally('test_user_1', 'old-1'), isTrue);
      expect(service.isAcknowledgedLocally('test_user_1', 'recent-1'), isTrue);
    });

    test('Active acknowledgement triggers local notification and records in Hive', () async {
      // 1. Initial run with unacknowledged ticket
      final submittedItem = makeFeedback(
        id: 'live-1',
        category: FeedbackCategory.bugReport,
        status: FeedbackStatus.submitted,
      );

      await service.processFeedbackList(
        userId: 'test_user_1',
        feedbackList: [submittedItem],
      );

      expect(gateway.shownNotifications, isEmpty);

      // 2. Next update: status transitions to acknowledged
      final acknowledgedItem = makeFeedback(
        id: 'live-1',
        category: FeedbackCategory.bugReport,
        status: FeedbackStatus.acknowledged,
      );

      await service.processFeedbackList(
        userId: 'test_user_1',
        feedbackList: [acknowledgedItem],
      );

      expect(gateway.shownNotifications.length, 1);
      final notification = gateway.shownNotifications.first;
      expect(notification.title, 'Thank You!');
      expect(notification.body, 'Thanks for reporting the bug! Your feedback has been reviewed.');
      expect(notification.type, ArcNotificationType.feedbackAcknowledged);
      expect(notification.channel, ArcNotificationChannel.feedback);
      expect(notification.entityId, 'live-1');

      // Key must be in Hive
      expect(service.isAcknowledgedLocally('test_user_1', 'live-1'), isTrue);
    });

    test('Deduplication prevents duplicate notification on repeated stream emissions', () async {
      // Seed first run
      await service.processFeedbackList(
        userId: 'test_user_1',
        feedbackList: [],
      );

      final ackItem = makeFeedback(
        id: 'live-2',
        category: FeedbackCategory.featureRequest,
        status: FeedbackStatus.acknowledged,
      );

      // First emission: notification displayed
      await service.processFeedbackList(
        userId: 'test_user_1',
        feedbackList: [ackItem],
      );
      expect(gateway.shownNotifications.length, 1);

      // Second emission (e.g. stream reconnected or refreshed): no second notification
      await service.processFeedbackList(
        userId: 'test_user_1',
        feedbackList: [ackItem],
      );
      expect(gateway.shownNotifications.length, 1);
    });

    test('Deduplication survives service restart (simulating app restart with persisted box)', () async {
      // Seed first run
      await service.processFeedbackList(userId: 'test_user_1', feedbackList: []);

      final ackItem = makeFeedback(
        id: 'live-3',
        category: FeedbackCategory.appRating,
        status: FeedbackStatus.acknowledged,
      );

      await service.processFeedbackList(userId: 'test_user_1', feedbackList: [ackItem]);
      expect(gateway.shownNotifications.length, 1);

      // Simulate app restart: new service instance sharing the same box
      final restartedService = FeedbackAcknowledgementService(
        gateway: gateway,
        boxOverride: mockBox,
      );

      await restartedService.processFeedbackList(userId: 'test_user_1', feedbackList: [ackItem]);
      // Count remains 1
      expect(gateway.shownNotifications.length, 1);
    });

    test('User account switching preserves notification isolation', () async {
      // User A initial run & active ack
      await service.processFeedbackList(userId: 'user_A', feedbackList: []);
      final ackItemA = makeFeedback(id: 'shared-id', category: FeedbackCategory.generalFeedback);
      await service.processFeedbackList(userId: 'user_A', feedbackList: [ackItemA]);
      expect(gateway.shownNotifications.length, 1);

      // Switch to User B: initial seed for User B
      await service.processFeedbackList(userId: 'user_B', feedbackList: []);

      // User B receives an acknowledgement for their ticket
      final ackItemB = makeFeedback(id: 'shared-id', category: FeedbackCategory.featureRequest);
      await service.processFeedbackList(userId: 'user_B', feedbackList: [ackItemB]);

      // User B gets their own notification because keys are scoped per user
      expect(gateway.shownNotifications.length, 2);
      expect(gateway.shownNotifications[1].body, contains('Thanks for your suggestion!'));
    });
  });
}
