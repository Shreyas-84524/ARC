import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/repository/feedback_repository.dart';
import 'package:arc/features/feedback/services/feedback_remote_data_source.dart';
import 'helpers/mock_firebase_auth.dart';

class FakeFeedbackRemoteDataSource implements IFeedbackRemoteDataSource {
  final List<FeedbackModel> stored = [];

  @override
  Future<void> submitFeedback(FeedbackModel feedback) async {
    stored.add(feedback);
  }

  @override
  Future<List<FeedbackModel>> getUserFeedback(String userId) async {
    return stored.where((f) => f.userId == userId).toList();
  }

  @override
  Stream<List<FeedbackModel>> watchUserFeedback(String userId) {
    return Stream.value(stored.where((f) => f.userId == userId).toList());
  }

  @override
  Future<FeedbackModel?> getFeedbackById(String feedbackId) async {
    try {
      return stored.firstWhere((f) => f.feedbackId == feedbackId);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<FeedbackModel?> watchFeedbackById(String feedbackId) {
    try {
      return Stream.value(stored.firstWhere((f) => f.feedbackId == feedbackId));
    } catch (_) {
      return Stream.value(null);
    }
  }

  @override
  Future<List<FeedbackModel>> getFeedbackForAdmin({
    String? status,
    String? category,
    int limit = 50,
  }) async {
    Iterable<FeedbackModel> list = stored;
    if (status != null && status.isNotEmpty) {
      list = list.where((f) => f.status == status);
    }
    if (category != null && category.isNotEmpty) {
      list = list.where((f) => f.category == category);
    }
    return list.take(limit).toList();
  }

  @override
  Future<void> updateFeedbackAdminStatus({
    required String feedbackId,
    required String status,
    DateTime? reviewedAt,
    DateTime? acknowledgedAt,
  }) async {
    final index = stored.indexWhere((f) => f.feedbackId == feedbackId);
    if (index != -1) {
      stored[index] = stored[index].copyWith(
        status: status,
        reviewedAt: reviewedAt,
        acknowledgedAt: acknowledgedAt,
      );
    }
  }
}

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFeedbackRemoteDataSource fakeDataSource;
  late FeedbackRepository repository;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    fakeDataSource = FakeFeedbackRemoteDataSource();
    repository = FeedbackRepository(
      remoteDataSource: fakeDataSource,
      firebaseAuth: mockAuth,
    );
  });

  group('FeedbackRepository Tests', () {
    test('Unauthenticated user cannot submit feedback', () async {
      expect(
        () => repository.submitFeedback(
          category: FeedbackCategory.bugReport,
          module: 'tasks',
          message: 'Error creating task',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Authenticated user submits feedback successfully with correct UID', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'user@arc.app',
        password: 'password123',
      );

      final result = await repository.submitFeedback(
        category: FeedbackCategory.bugReport,
        module: 'habit_tracker',
        message: 'Habit streak does not update properly',
        rating: 4,
        appVersion: '1.3.5',
      );

      expect(result.feedbackId, isNotEmpty);
      expect(result.userId, equals('uid_user'));
      expect(result.category, equals(FeedbackCategory.bugReport));
      expect(result.module, equals('habit_tracker'));
      expect(result.message, equals('Habit streak does not update properly'));
      expect(result.rating, equals(4));
      expect(result.status, equals(FeedbackStatus.submitted));
      expect(result.notificationDelivered, isFalse);

      expect(fakeDataSource.stored.length, equals(1));
      expect(fakeDataSource.stored.first.feedbackId, equals(result.feedbackId));
    });

    test('Rejects empty or whitespace-only messages', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'user2@arc.app',
        password: 'password123',
      );

      expect(
        () => repository.submitFeedback(
          category: FeedbackCategory.bugReport,
          module: 'tasks',
          message: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Rejects oversized message exceeding 5000 characters', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'user3@arc.app',
        password: 'password123',
      );

      final longMessage = 'A' * 5001;

      expect(
        () => repository.submitFeedback(
          category: FeedbackCategory.bugReport,
          module: 'tasks',
          message: longMessage,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Rejects invalid categories', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'user4@arc.app',
        password: 'password123',
      );

      expect(
        () => repository.submitFeedback(
          category: 'invalid_category_xyz',
          module: 'tasks',
          message: 'Valid message',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Rejects invalid ratings outside 1..5', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'user5@arc.app',
        password: 'password123',
      );

      expect(
        () => repository.submitFeedback(
          category: FeedbackCategory.appRating,
          module: 'app',
          message: 'Rating 0 should fail',
          rating: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => repository.submitFeedback(
          category: FeedbackCategory.appRating,
          module: 'app',
          message: 'Rating 6 should fail',
          rating: 6,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getCurrentUserFeedback retrieves only current user submissions', () async {
      // User 1
      await mockAuth.createUserWithEmailAndPassword(
        email: 'alice@arc.app',
        password: 'password123',
      );
      await repository.submitFeedback(
        category: FeedbackCategory.featureRequest,
        module: 'money',
        message: 'Alice feature request',
      );

      // User 2
      await mockAuth.createUserWithEmailAndPassword(
        email: 'bob@arc.app',
        password: 'password123',
      );
      await repository.submitFeedback(
        category: FeedbackCategory.bugReport,
        module: 'tasks',
        message: 'Bob bug report',
      );

      // Bob's feedback query
      final bobList = await repository.getCurrentUserFeedback();
      expect(bobList.length, equals(1));
      expect(bobList.first.userId, equals('uid_bob'));
      expect(bobList.first.message, equals('Bob bug report'));

      // Switch back to Alice
      await mockAuth.signInWithEmailAndPassword(
        email: 'alice@arc.app',
        password: 'password123',
      );
      final aliceList = await repository.getCurrentUserFeedback();
      expect(aliceList.length, equals(1));
      expect(aliceList.first.userId, equals('uid_alice'));
      expect(aliceList.first.message, equals('Alice feature request'));
    });

    test('Unauthenticated user gets empty list from getCurrentUserFeedback', () async {
      await mockAuth.signOut();
      final list = await repository.getCurrentUserFeedback();
      expect(list, isEmpty);
    });

    test('Admin status update changes status, reviewedAt and acknowledgedAt', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'submitter@arc.app',
        password: 'password123',
      );
      final feedback = await repository.submitFeedback(
        category: FeedbackCategory.bugReport,
        module: 'sync',
        message: 'Sync stalled',
      );

      final reviewTime = DateTime.now();
      final ackTime = DateTime.now().add(const Duration(minutes: 5));

      await repository.updateFeedbackAdminStatus(
        feedbackId: feedback.feedbackId,
        status: FeedbackStatus.acknowledged,
        reviewedAt: reviewTime,
        acknowledgedAt: ackTime,
      );

      final updated = await repository.getFeedbackStatus(feedback.feedbackId);
      expect(updated, isNotNull);
      expect(updated!.status, equals(FeedbackStatus.acknowledged));
      expect(updated.reviewedAt, equals(reviewTime));
      expect(updated.acknowledgedAt, equals(ackTime));
    });

    test('Admin status update throws on invalid status', () async {
      expect(
        () => repository.updateFeedbackAdminStatus(
          feedbackId: 'fb-test',
          status: 'invalid_status_xyz',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
