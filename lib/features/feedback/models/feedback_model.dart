import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Supported categories for Project Arc user feedback.
class FeedbackCategory {
  static const String bugReport = 'bug_report';
  static const String featureRequest = 'feature_request';
  static const String generalFeedback = 'general_feedback';
  static const String appRating = 'app_rating';

  static const List<String> all = [
    bugReport,
    featureRequest,
    generalFeedback,
    appRating,
  ];

  static bool isValid(String category) => all.contains(category);
}

/// Lifecycle status for feedback submissions.
class FeedbackStatus {
  static const String submitted = 'submitted';
  static const String emailed = 'emailed';
  static const String reviewed = 'reviewed';
  static const String acknowledged = 'acknowledged';

  static const List<String> all = [
    submitted,
    emailed,
    reviewed,
    acknowledged,
  ];

  static bool isValid(String status) => all.contains(status);
}

/// Immutable data model representing a feedback document in Cloud Firestore.
/// Path: `feedback/{feedbackId}`
@immutable
class FeedbackModel {
  final String feedbackId;
  final String userId;
  final String category;
  final String module;
  final String message;
  final int? rating;
  final String? contactEmail;
  final String appVersion;
  final DateTime createdAt;
  final String status;
  final DateTime? emailedAt;
  final DateTime? reviewedAt;
  final DateTime? acknowledgedAt;
  final bool notificationDelivered;

  const FeedbackModel({
    required this.feedbackId,
    required this.userId,
    required this.category,
    required this.module,
    required this.message,
    this.rating,
    this.contactEmail,
    required this.appVersion,
    required this.createdAt,
    this.status = FeedbackStatus.submitted,
    this.emailedAt,
    this.reviewedAt,
    this.acknowledgedAt,
    this.notificationDelivered = false,
  });

  /// Serializes the model into a Firestore map suitable for newly submitted feedback documents.
  /// Uses [FieldValue.serverTimestamp()] for the `createdAt` field on write.
  Map<String, dynamic> toFirestoreForCreate() {
    return {
      'feedbackId': feedbackId,
      'userId': userId,
      'category': category,
      'module': module,
      'message': message,
      'rating': rating,
      'contactEmail': contactEmail,
      'appVersion': appVersion,
      'createdAt': FieldValue.serverTimestamp(),
      'status': FeedbackStatus.submitted,
      'emailedAt': null,
      'reviewedAt': null,
      'acknowledgedAt': null,
      'notificationDelivered': false,
    };
  }

  /// Serializes the model into a standard Map with Timestamp objects.
  Map<String, dynamic> toFirestore() {
    return {
      'feedbackId': feedbackId,
      'userId': userId,
      'category': category,
      'module': module,
      'message': message,
      'rating': rating,
      'contactEmail': contactEmail,
      'appVersion': appVersion,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'emailedAt': emailedAt != null ? Timestamp.fromDate(emailedAt!) : null,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'acknowledgedAt':
          acknowledgedAt != null ? Timestamp.fromDate(acknowledgedAt!) : null,
      'notificationDelivered': notificationDelivered,
    };
  }

  /// Deserializes a Firestore DocumentSnapshot into a [FeedbackModel].
  factory FeedbackModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Cannot create FeedbackModel from empty document snapshot');
    }
    return FeedbackModel.fromMap(data, snapshot.id);
  }

  /// Deserializes a Map into a [FeedbackModel].
  factory FeedbackModel.fromMap(
    Map<String, dynamic> map, [
    String? documentId,
  ]) {
    final id = (map['feedbackId'] as String?) ?? documentId ?? '';
    final uid = (map['userId'] as String?) ?? '';
    final category = (map['category'] as String?) ?? FeedbackCategory.generalFeedback;
    final module = (map['module'] as String?) ?? 'general';
    final message = (map['message'] as String?) ?? '';
    final rating = (map['rating'] as num?)?.toInt();
    final contactEmail = map['contactEmail'] as String?;
    final appVersion = (map['appVersion'] as String?) ?? '1.3.5';
    final status = (map['status'] as String?) ?? FeedbackStatus.submitted;
    final notificationDelivered = (map['notificationDelivered'] as bool?) ?? false;

    final createdAt = _parseDateTime(map['createdAt']);
    final emailedAt = _parseNullableDateTime(map['emailedAt']);
    final reviewedAt = _parseNullableDateTime(map['reviewedAt']);
    final acknowledgedAt = _parseNullableDateTime(map['acknowledgedAt']);

    return FeedbackModel(
      feedbackId: id,
      userId: uid,
      category: category,
      module: module,
      message: message,
      rating: rating,
      contactEmail: contactEmail,
      appVersion: appVersion,
      createdAt: createdAt,
      status: status,
      emailedAt: emailedAt,
      reviewedAt: reviewedAt,
      acknowledgedAt: acknowledgedAt,
      notificationDelivered: notificationDelivered,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  FeedbackModel copyWith({
    String? feedbackId,
    String? userId,
    String? category,
    String? module,
    String? message,
    int? rating,
    String? contactEmail,
    String? appVersion,
    DateTime? createdAt,
    String? status,
    DateTime? emailedAt,
    DateTime? reviewedAt,
    DateTime? acknowledgedAt,
    bool? notificationDelivered,
  }) {
    return FeedbackModel(
      feedbackId: feedbackId ?? this.feedbackId,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      module: module ?? this.module,
      message: message ?? this.message,
      rating: rating ?? this.rating,
      contactEmail: contactEmail ?? this.contactEmail,
      appVersion: appVersion ?? this.appVersion,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      emailedAt: emailedAt ?? this.emailedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      notificationDelivered:
          notificationDelivered ?? this.notificationDelivered,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedbackModel &&
        other.feedbackId == feedbackId &&
        other.userId == userId &&
        other.category == category &&
        other.module == module &&
        other.message == message &&
        other.rating == rating &&
        other.contactEmail == contactEmail &&
        other.appVersion == appVersion &&
        other.createdAt == createdAt &&
        other.status == status &&
        other.emailedAt == emailedAt &&
        other.reviewedAt == reviewedAt &&
        other.acknowledgedAt == acknowledgedAt &&
        other.notificationDelivered == notificationDelivered;
  }

  @override
  int get hashCode => Object.hash(
        feedbackId,
        userId,
        category,
        module,
        message,
        rating,
        contactEmail,
        appVersion,
        createdAt,
        status,
        emailedAt,
        reviewedAt,
        acknowledgedAt,
        notificationDelivered,
      );

  @override
  String toString() {
    return 'FeedbackModel(feedbackId: $feedbackId, userId: $userId, category: $category, module: $module, status: $status, rating: $rating, appVersion: $appVersion, createdAt: $createdAt)';
  }
}
