import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:arc/core/notifications/notification_models.dart';
import 'package:arc/core/notifications/notification_policy.dart';
import 'package:arc/core/notifications/notification_service.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';

abstract class IFeedbackAcknowledgementService {
  Future<void> processFeedbackList({
    required String userId,
    required List<FeedbackModel> feedbackList,
  });

  bool isAcknowledgedLocally(String userId, String feedbackId);
}

class FeedbackAcknowledgementService implements IFeedbackAcknowledgementService {
  final LocalNotificationGateway _gateway;
  final Box? _boxOverride;
  final Duration recentGraceWindow;
  final int maxRecentFirstRunNotifications;
  final DateTime Function()? _nowOverride;

  FeedbackAcknowledgementService({
    LocalNotificationGateway? gateway,
    Box? boxOverride,
    this.recentGraceWindow = const Duration(hours: 24),
    this.maxRecentFirstRunNotifications = 2,
    DateTime Function()? nowOverride,
  })  : _gateway = gateway ?? FlutterLocalNotificationGateway(),
        _boxOverride = boxOverride,
        _nowOverride = nowOverride;

  Box get _box {
    if (_boxOverride != null) return _boxOverride;
    return HiveService().getBox(HiveService.feedbackAcknowledgementsBoxName);
  }

  DateTime get _now => _nowOverride != null ? _nowOverride() : DateTime.now();

  /// Formats the unique per-user, per-feedback acknowledgement key
  static String formatAckKey(String userId, String feedbackId) {
    return 'feedback_ack_${userId}_$feedbackId';
  }

  /// First-run initial seed key per user
  static String formatSeedKey(String userId) {
    return 'feedback_ack_initial_seed_$userId';
  }

  @override
  bool isAcknowledgedLocally(String userId, String feedbackId) {
    try {
      final key = formatAckKey(userId, feedbackId);
      return _box.containsKey(key);
    } catch (_) {
      return false;
    }
  }

  /// Category-specific notification copy matching Phase 4 & 5 requirements exactly
  static (String title, String message) getNotificationContent(String category) {
    return switch (category) {
      FeedbackCategory.bugReport => (
          'Thank You!',
          'Thanks for reporting the bug! Your feedback has been reviewed.',
        ),
      FeedbackCategory.featureRequest => (
          'Thank You!',
          'Thanks for your suggestion! We appreciate your ideas for improving Arc.',
        ),
      FeedbackCategory.generalFeedback => (
          'Thank You!',
          'Thanks for sharing your feedback! Your input means a lot to us.',
        ),
      FeedbackCategory.appRating => (
          'Thank You!',
          'Thanks for rating Arc! We appreciate your support.',
        ),
      _ => (
          'Thank You!',
          'Thanks for your feedback! Your input means a lot to us.',
        ),
    };
  }

  @override
  Future<void> processFeedbackList({
    required String userId,
    required List<FeedbackModel> feedbackList,
  }) async {
    if (userId.isEmpty) return;

    final box = _box;
    final seedKey = formatSeedKey(userId);
    final isFirstRunForUser = !box.containsKey(seedKey);

    if (isFirstRunForUser) {
      // First-run reconciliation strategy:
      // 1. Separate historical tickets (> 24 hours old) from recent acknowledgements (<= 24 hours old).
      // 2. Historical tickets are silently marked as seeded in Hive to prevent notification floods upon app install/login.
      // 3. Recent tickets (acknowledged within recentGraceWindow) are NOT silently discarded:
      //    up to maxRecentFirstRunNotifications (default 2) are displayed to the user so recent acknowledgements
      //    are properly delivered, and then recorded in Hive.
      final now = _now;
      final recentToNotify = <FeedbackModel>[];

      for (final item in feedbackList) {
        if (item.status != FeedbackStatus.acknowledged) continue;

        final ackKey = formatAckKey(userId, item.feedbackId);
        final ackTime = item.acknowledgedAt;
        final isRecent = ackTime != null && now.difference(ackTime).abs() <= recentGraceWindow;

        if (isRecent && recentToNotify.length < maxRecentFirstRunNotifications) {
          recentToNotify.add(item);
        } else {
          // Historical or beyond cap: seed directly into Hive
          await box.put(ackKey, now.toIso8601String());
        }
      }

      // Record first-run seed key
      await box.put(seedKey, now.toIso8601String());

      // Deliver recent notifications (if any)
      for (final item in recentToNotify) {
        await _dispatchAcknowledgementNotification(userId, item);
      }

      debugPrint(
        'FeedbackAcknowledgementService: First-run reconciliation completed for user $userId '
        '(${recentToNotify.length} recent delivered, remainder seeded).',
      );
      return;
    }

    if (feedbackList.isEmpty) return;

    // Active session / resume behavior:
    // Identify newly acknowledged tickets that have not yet triggered a local notification.
    for (final item in feedbackList) {
      if (item.status != FeedbackStatus.acknowledged) continue;

      final ackKey = formatAckKey(userId, item.feedbackId);
      if (box.containsKey(ackKey)) {
        // Already notified; skip duplicate
        continue;
      }

      await _dispatchAcknowledgementNotification(userId, item);
    }
  }

  Future<void> _dispatchAcknowledgementNotification(
    String userId,
    FeedbackModel item,
  ) async {
    final ackKey = formatAckKey(userId, item.feedbackId);

    // Generate category-specific thank you copy
    final (title, body) = getNotificationContent(item.category);

    // Deterministic 31-bit positive notification ID scoped to feedback range
    final notificationId = NotificationPolicy().getFeedbackNotificationId(item.feedbackId);

    final spec = ArcNotificationSpec(
      id: notificationId,
      type: ArcNotificationType.feedbackAcknowledged,
      channel: ArcNotificationChannel.feedback,
      entityId: item.feedbackId,
      title: title,
      body: body,
      scheduledAt: _now,
      recurrence: ArcNotificationRecurrence.none,
      fingerprint: ackKey,
    );

    try {
      await _gateway.show(spec);
      // Persist deduplication record immediately upon successful gateway dispatch
      await _box.put(ackKey, _now.toIso8601String());
      debugPrint(
        'FeedbackAcknowledgementService: Dispatched thank-you notification for ${item.feedbackId} ($title).',
      );
    } catch (err, stack) {
      debugPrint('FeedbackAcknowledgementService error dispatching notification: $err\n$stack');
    }
  }
}
