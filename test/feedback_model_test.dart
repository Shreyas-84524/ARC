import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';

void main() {
  group('FeedbackModel & Enums Unit Tests', () {
    test('FeedbackCategory validation rules', () {
      expect(FeedbackCategory.isValid('bug_report'), isTrue);
      expect(FeedbackCategory.isValid('feature_request'), isTrue);
      expect(FeedbackCategory.isValid('general_feedback'), isTrue);
      expect(FeedbackCategory.isValid('app_rating'), isTrue);

      expect(FeedbackCategory.isValid('malicious_category'), isFalse);
      expect(FeedbackCategory.isValid(''), isFalse);
      expect(FeedbackCategory.isValid('BUG_REPORT'), isFalse);
    });

    test('FeedbackStatus validation rules', () {
      expect(FeedbackStatus.isValid('submitted'), isTrue);
      expect(FeedbackStatus.isValid('emailed'), isTrue);
      expect(FeedbackStatus.isValid('reviewed'), isTrue);
      expect(FeedbackStatus.isValid('acknowledged'), isTrue);

      expect(FeedbackStatus.isValid('unknown'), isFalse);
      expect(FeedbackStatus.isValid('deleted'), isFalse);
      expect(FeedbackStatus.isValid(''), isFalse);
    });

    test('FeedbackModel default values and immutability', () {
      final now = DateTime.now();
      final model = FeedbackModel(
        feedbackId: 'fb-123',
        userId: 'user-456',
        category: FeedbackCategory.bugReport,
        module: 'task_manager',
        message: 'Task checkbox failed to sync',
        appVersion: '1.3.5',
        createdAt: now,
      );

      expect(model.status, equals(FeedbackStatus.submitted));
      expect(model.notificationDelivered, isFalse);
      expect(model.emailedAt, isNull);
      expect(model.reviewedAt, isNull);
      expect(model.acknowledgedAt, isNull);
      expect(model.rating, isNull);
      expect(model.contactEmail, isNull);
    });

    test('toFirestoreForCreate prepares server-side timestamp and initial defaults', () {
      final now = DateTime.now();
      final model = FeedbackModel(
        feedbackId: 'fb-001',
        userId: 'user-001',
        category: FeedbackCategory.featureRequest,
        module: 'habit_tracker',
        message: 'Add weekly streak graph',
        rating: 5,
        contactEmail: 'user@arc.app',
        appVersion: '1.3.5',
        createdAt: now,
      );

      final map = model.toFirestoreForCreate();

      expect(map['feedbackId'], equals('fb-001'));
      expect(map['userId'], equals('user-001'));
      expect(map['category'], equals(FeedbackCategory.featureRequest));
      expect(map['module'], equals('habit_tracker'));
      expect(map['message'], equals('Add weekly streak graph'));
      expect(map['rating'], equals(5));
      expect(map['contactEmail'], equals('user@arc.app'));
      expect(map['appVersion'], equals('1.3.5'));
      expect(map['status'], equals(FeedbackStatus.submitted));
      expect(map['emailedAt'], isNull);
      expect(map['reviewedAt'], isNull);
      expect(map['acknowledgedAt'], isNull);
      expect(map['notificationDelivered'], isFalse);
      expect(map['createdAt'], isA<FieldValue>());
    });

    test('toFirestore and fromMap serialization round trip', () {
      final now = DateTime(2026, 10, 25, 14, 30);
      final model = FeedbackModel(
        feedbackId: 'fb-roundtrip',
        userId: 'user-roundtrip',
        category: FeedbackCategory.appRating,
        module: 'money_tracker',
        message: 'Loving the quick add button',
        rating: 5,
        contactEmail: 'tester@arc.app',
        appVersion: '1.3.5',
        createdAt: now,
        status: FeedbackStatus.reviewed,
        emailedAt: now.add(const Duration(minutes: 5)),
        reviewedAt: now.add(const Duration(minutes: 10)),
        acknowledgedAt: now.add(const Duration(minutes: 15)),
        notificationDelivered: true,
      );

      final firestoreMap = model.toFirestore();
      expect(firestoreMap['createdAt'], isA<Timestamp>());
      expect(firestoreMap['reviewedAt'], isA<Timestamp>());

      final reconstructed = FeedbackModel.fromMap(firestoreMap, 'fb-roundtrip');

      expect(reconstructed.feedbackId, equals(model.feedbackId));
      expect(reconstructed.userId, equals(model.userId));
      expect(reconstructed.category, equals(model.category));
      expect(reconstructed.module, equals(model.module));
      expect(reconstructed.message, equals(model.message));
      expect(reconstructed.rating, equals(model.rating));
      expect(reconstructed.contactEmail, equals(model.contactEmail));
      expect(reconstructed.appVersion, equals(model.appVersion));
      expect(reconstructed.status, equals(model.status));
      expect(reconstructed.notificationDelivered, equals(model.notificationDelivered));
      expect(reconstructed.createdAt.millisecondsSinceEpoch,
          equals(now.millisecondsSinceEpoch));
      expect(reconstructed.reviewedAt?.millisecondsSinceEpoch,
          equals(now.add(const Duration(minutes: 10)).millisecondsSinceEpoch));
    });

    test('copyWith updates specified fields only', () {
      final now = DateTime.now();
      final model = FeedbackModel(
        feedbackId: 'fb-orig',
        userId: 'user-orig',
        category: FeedbackCategory.generalFeedback,
        module: 'general',
        message: 'Initial message',
        appVersion: '1.3.5',
        createdAt: now,
      );

      final updated = model.copyWith(
        status: FeedbackStatus.acknowledged,
        notificationDelivered: true,
      );

      expect(updated.feedbackId, equals('fb-orig'));
      expect(updated.message, equals('Initial message'));
      expect(updated.status, equals(FeedbackStatus.acknowledged));
      expect(updated.notificationDelivered, isTrue);
    });
  });
}
