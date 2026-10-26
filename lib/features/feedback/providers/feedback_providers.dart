import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/repository/feedback_repository.dart';
import 'package:arc/features/feedback/services/feedback_remote_data_source.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';

import 'package:arc/features/feedback/services/feedback_acknowledgement_service.dart';

export 'package:arc/features/feedback/services/feedback_draft_service.dart';
export 'package:arc/features/feedback/services/feedback_acknowledgement_service.dart';
export 'package:arc/features/feedback/screens/bug_report_screen.dart';
export 'package:arc/features/feedback/screens/feature_request_screen.dart';
export 'package:arc/features/feedback/screens/general_feedback_screen.dart';
export 'package:arc/features/feedback/screens/rate_arc_screen.dart';
export 'package:arc/features/feedback/utils/feedback_serializers.dart';

/// Provider for the feedback acknowledgement and local notification service.
final feedbackAcknowledgementServiceProvider =
    Provider<IFeedbackAcknowledgementService>((ref) {
  return FeedbackAcknowledgementService();
});

/// Provider for the remote Firestore data source.
final feedbackRemoteDataSourceProvider =
    Provider<IFeedbackRemoteDataSource>((ref) {
  return FeedbackRemoteDataSource();
});

/// Provider for the feedback repository.
final feedbackRepositoryProvider = Provider<IFeedbackRepository>((ref) {
  final remoteDataSource = ref.watch(feedbackRemoteDataSourceProvider);
  return FeedbackRepository(remoteDataSource: remoteDataSource);
});

/// Future provider fetching the currently logged-in user's feedback list.
final currentUserFeedbackProvider =
    FutureProvider<List<FeedbackModel>>((ref) async {
  final userContext = ref.watch(userContextProvider);
  final repository = ref.watch(feedbackRepositoryProvider);

  if (userContext.isInitializing) {
    // Keep in pending state while auth initializes
    final completer = Completer<List<FeedbackModel>>();
    ref.onDispose(() {
      if (!completer.isCompleted) {
        completer.complete([]);
      }
    });
    return completer.future;
  }

  final uid = userContext.userId ?? repository.currentUserId;
  if (uid == null || uid.isEmpty) {
    return const [];
  }

  return repository.getCurrentUserFeedback(userId: uid);
});

/// Stream provider for live real-time updates of the current user's feedback.
final currentUserFeedbackStreamProvider =
    StreamProvider<List<FeedbackModel>>((ref) {
  final userContext = ref.watch(userContextProvider);
  final repository = ref.watch(feedbackRepositoryProvider);

  if (userContext.isInitializing) {
    // Maintain AsyncLoading state until auth resolves
    final controller = StreamController<List<FeedbackModel>>();
    ref.onDispose(() => controller.close());
    return controller.stream;
  }

  final uid = userContext.userId ?? repository.currentUserId;
  if (uid == null || uid.isEmpty) {
    return Stream.value(const []);
  }

  return repository.watchCurrentUserFeedback(userId: uid);
});

/// Future provider fetching the details and status of a specific feedback item.
final feedbackStatusProvider =
    FutureProvider.family<FeedbackModel?, String>((ref, feedbackId) async {
  final repository = ref.watch(feedbackRepositoryProvider);
  return repository.getFeedbackStatus(feedbackId);
});

/// Stream provider listening to real-time status updates of a specific feedback item.
final feedbackStatusStreamProvider =
    StreamProvider.family<FeedbackModel?, String>((ref, feedbackId) {
  final repository = ref.watch(feedbackRepositoryProvider);
  return repository.watchFeedbackStatus(feedbackId);
});

/// Filter parameters for administrative feedback queries.
@immutable
class AdminFeedbackFilter {
  final String? status;
  final String? category;
  final int limit;

  const AdminFeedbackFilter({
    this.status,
    this.category,
    this.limit = 50,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminFeedbackFilter &&
        other.status == status &&
        other.category == category &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(status, category, limit);

  @override
  String toString() =>
      'AdminFeedbackFilter(status: $status, category: $category, limit: $limit)';
}

/// Future provider allowing administrators to query feedback submissions.
final adminFeedbackListProvider =
    FutureProvider.family<List<FeedbackModel>, AdminFeedbackFilter>(
  (ref, filter) async {
    final repository = ref.watch(feedbackRepositoryProvider);
    return repository.getFeedbackForAdmin(
      status: filter.status,
      category: filter.category,
      limit: filter.limit,
    );
  },
);
