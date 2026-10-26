import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:uuid/uuid.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/services/feedback_remote_data_source.dart';

abstract class IFeedbackRepository {
  /// Current authenticated Firebase UID, or null if unauthenticated.
  String? get currentUserId;

  /// Submits feedback for the currently authenticated user.
  /// Validates category, message, rating, and attaches current Firebase UID.
  Future<FeedbackModel> submitFeedback({
    required String category,
    required String module,
    required String message,
    int? rating,
    String? contactEmail,
    String? appVersion,
    String? feedbackId,
  });

  /// Retrieves list of feedback documents submitted by the currently authenticated user.
  Future<List<FeedbackModel>> getCurrentUserFeedback({String? userId});

  /// Real-time stream of the current user's feedback.
  Stream<List<FeedbackModel>> watchCurrentUserFeedback({String? userId});

  /// Reads feedback status and details for a given [feedbackId].
  Future<FeedbackModel?> getFeedbackStatus(String feedbackId);

  /// Streams real-time updates for a single feedback item.
  Stream<FeedbackModel?> watchFeedbackStatus(String feedbackId);

  /// Retrieves all feedback submissions for authorized administrators.
  Future<List<FeedbackModel>> getFeedbackForAdmin({
    String? status,
    String? category,
    int limit = 50,
  });

  /// Allows authorized administrators to update feedback review/acknowledgement status.
  Future<void> updateFeedbackAdminStatus({
    required String feedbackId,
    required String status,
    DateTime? reviewedAt,
    DateTime? acknowledgedAt,
  });
}

class FeedbackRepository implements IFeedbackRepository {
  final IFeedbackRemoteDataSource _remoteDataSource;
  final auth.FirebaseAuth _firebaseAuth;
  final Uuid _uuid;

  FeedbackRepository({
    IFeedbackRemoteDataSource? remoteDataSource,
    auth.FirebaseAuth? firebaseAuth,
    Uuid? uuid,
  })  : _remoteDataSource = remoteDataSource ?? FeedbackRemoteDataSource(),
        _firebaseAuth = firebaseAuth ?? auth.FirebaseAuth.instance,
        _uuid = uuid ?? const Uuid();

  /// Current authenticated Firebase UID.
  @override
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  @override
  Future<FeedbackModel> submitFeedback({
    required String category,
    required String module,
    required String message,
    int? rating,
    String? contactEmail,
    String? appVersion,
    String? feedbackId,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.uid.isEmpty) {
      throw StateError(
        'Authentication required: User must be signed in to submit feedback.',
      );
    }

    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw ArgumentError('Feedback message cannot be empty.');
    }
    if (trimmedMessage.length > 5000) {
      throw ArgumentError(
        'Feedback message exceeds maximum permitted length of 5000 characters.',
      );
    }

    if (!FeedbackCategory.isValid(category)) {
      throw ArgumentError(
        'Invalid feedback category "$category". Must be one of: ${FeedbackCategory.all.join(', ')}',
      );
    }

    if (rating != null && (rating < 1 || rating > 5)) {
      throw ArgumentError('Rating must be an integer between 1 and 5.');
    }

    final resolvedId = feedbackId ?? _uuid.v4();
    final resolvedVersion = (appVersion != null && appVersion.isNotEmpty)
        ? appVersion
        : '1.3.5';

    final feedback = FeedbackModel(
      feedbackId: resolvedId,
      userId: user.uid,
      category: category,
      module: module.trim().isNotEmpty ? module.trim() : 'general',
      message: trimmedMessage,
      rating: rating,
      contactEmail: (contactEmail != null && contactEmail.trim().isNotEmpty)
          ? contactEmail.trim()
          : (user.email != null && user.email!.isNotEmpty ? user.email : null),
      appVersion: resolvedVersion,
      createdAt: DateTime.now(),
      status: FeedbackStatus.submitted,
      notificationDelivered: false,
    );

    await _remoteDataSource.submitFeedback(feedback);
    return feedback;
  }

  @override
  Future<List<FeedbackModel>> getCurrentUserFeedback({String? userId}) async {
    final uid = (userId != null && userId.isNotEmpty) ? userId : currentUserId;
    if (uid == null || uid.isEmpty) {
      return const [];
    }
    return _remoteDataSource.getUserFeedback(uid);
  }

  @override
  Stream<List<FeedbackModel>> watchCurrentUserFeedback({String? userId}) {
    final uid = (userId != null && userId.isNotEmpty) ? userId : currentUserId;
    if (uid == null || uid.isEmpty) {
      return Stream.value(const []);
    }
    return _remoteDataSource.watchUserFeedback(uid);
  }

  @override
  Future<FeedbackModel?> getFeedbackStatus(String feedbackId) async {
    return _remoteDataSource.getFeedbackById(feedbackId);
  }

  @override
  Stream<FeedbackModel?> watchFeedbackStatus(String feedbackId) {
    return _remoteDataSource.watchFeedbackById(feedbackId);
  }

  @override
  Future<List<FeedbackModel>> getFeedbackForAdmin({
    String? status,
    String? category,
    int limit = 50,
  }) async {
    return _remoteDataSource.getFeedbackForAdmin(
      status: status,
      category: category,
      limit: limit,
    );
  }

  @override
  Future<void> updateFeedbackAdminStatus({
    required String feedbackId,
    required String status,
    DateTime? reviewedAt,
    DateTime? acknowledgedAt,
  }) async {
    if (!FeedbackStatus.isValid(status)) {
      throw ArgumentError(
        'Invalid status "$status". Must be one of: ${FeedbackStatus.all.join(', ')}',
      );
    }
    return _remoteDataSource.updateFeedbackAdminStatus(
      feedbackId: feedbackId,
      status: status,
      reviewedAt: reviewedAt,
      acknowledgedAt: acknowledgedAt,
    );
  }
}
