import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';

abstract class IFeedbackRemoteDataSource {
  /// Submits a new feedback document to Firestore collection `feedback/{feedbackId}`.
  Future<void> submitFeedback(FeedbackModel feedback);

  /// Retrieves feedback submitted by a specific user identified by [userId].
  Future<List<FeedbackModel>> getUserFeedback(String userId);

  /// Emits real-time updates of feedback submitted by a specific user.
  Stream<List<FeedbackModel>> watchUserFeedback(String userId);

  /// Retrieves a single feedback document by [feedbackId].
  Future<FeedbackModel?> getFeedbackById(String feedbackId);

  /// Emits real-time updates for a single feedback document by [feedbackId].
  Stream<FeedbackModel?> watchFeedbackById(String feedbackId);

  /// Retrieves all feedback submissions across users for authorized administrators.
  Future<List<FeedbackModel>> getFeedbackForAdmin({
    String? status,
    String? category,
    int limit = 50,
  });

  /// Allows administrators to update review/acknowledgement fields on a feedback document.
  Future<void> updateFeedbackAdminStatus({
    required String feedbackId,
    required String status,
    DateTime? reviewedAt,
    DateTime? acknowledgedAt,
  });
}

class FeedbackRemoteDataSource implements IFeedbackRemoteDataSource {
  final FirebaseFirestore _firestore;

  FeedbackRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('feedback');

  @override
  Future<void> submitFeedback(FeedbackModel feedback) async {
    await _collection
        .doc(feedback.feedbackId)
        .set(feedback.toFirestoreForCreate());
    // Verify server write acknowledgement so offline writes or rejected writes fail explicitly
    await _collection
        .doc(feedback.feedbackId)
        .get(const GetOptions(source: Source.server));
  }

  @override
  Future<List<FeedbackModel>> getUserFeedback(String userId) async {
    final querySnapshot = await _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => FeedbackModel.fromFirestore(doc))
        .toList();
  }

  @override
  Stream<List<FeedbackModel>> watchUserFeedback(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeedbackModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<FeedbackModel?> getFeedbackById(String feedbackId) async {
    final docSnapshot = await _collection.doc(feedbackId).get();
    if (!docSnapshot.exists || docSnapshot.data() == null) {
      return null;
    }
    return FeedbackModel.fromFirestore(docSnapshot);
  }

  @override
  Stream<FeedbackModel?> watchFeedbackById(String feedbackId) {
    return _collection.doc(feedbackId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return FeedbackModel.fromFirestore(snapshot);
    });
  }

  @override
  Future<List<FeedbackModel>> getFeedbackForAdmin({
    String? status,
    String? category,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> query = _collection;

    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    query = query.orderBy('createdAt', descending: true).limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => FeedbackModel.fromFirestore(doc))
        .toList();
  }

  @override
  Future<void> updateFeedbackAdminStatus({
    required String feedbackId,
    required String status,
    DateTime? reviewedAt,
    DateTime? acknowledgedAt,
  }) async {
    final Map<String, dynamic> updates = {
      'status': status,
    };

    if (reviewedAt != null) {
      updates['reviewedAt'] = Timestamp.fromDate(reviewedAt);
    }
    if (acknowledgedAt != null) {
      updates['acknowledgedAt'] = Timestamp.fromDate(acknowledgedAt);
    }

    await _collection.doc(feedbackId).update(updates);
  }
}
