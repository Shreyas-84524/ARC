import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/settings/models/settings_model.dart';
import 'package:arc/features/task_manager/models/task_model.dart';

enum ArcNotificationType {
  taskReminder,
  taskDeadline,
  habitReminder,
  habitPending,
  habitEveningCheckIn,
  moneyDaily,
}

enum ArcNotificationChannel { tasks, habits, money }

enum ArcNotificationRecurrence { none, daily }

enum ArcNotificationPermissionState {
  unknown,
  granted,
  denied,
  unsupported,
  error,
}

@immutable
class ArcNotificationPayload {
  static const int currentVersion = 2;

  final ArcNotificationType type;
  final String entityId;
  final String fingerprint;

  const ArcNotificationPayload({
    required this.type,
    required this.entityId,
    required this.fingerprint,
  });

  String get destination {
    switch (type) {
      case ArcNotificationType.taskReminder:
      case ArcNotificationType.taskDeadline:
        return '/tasks';
      case ArcNotificationType.habitReminder:
      case ArcNotificationType.habitPending:
      case ArcNotificationType.habitEveningCheckIn:
        return '/habits';
      case ArcNotificationType.moneyDaily:
        return '/money';
    }
  }

  String toJson() => jsonEncode({
        'app': 'arc',
        'version': currentVersion,
        'type': type.name,
        'id': entityId,
        'fingerprint': fingerprint,
      });

  static ArcNotificationPayload? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final typeName = decoded['type']?.toString();
      final entityId = decoded['id']?.toString();
      final fingerprint = decoded['fingerprint']?.toString();
      if (typeName == null || entityId == null) return null;

      ArcNotificationType? type;
      for (final candidate in ArcNotificationType.values) {
        if (candidate.name == typeName) {
          type = candidate;
          break;
        }
      }

      // Backward-compatible parsing for payloads scheduled by the old layer.
      type ??= switch (typeName) {
        'task' => ArcNotificationType.taskDeadline,
        'habit' => ArcNotificationType.habitReminder,
        'money' => ArcNotificationType.moneyDaily,
        _ => null,
      };
      if (type == null) return null;

      return ArcNotificationPayload(
        type: type,
        entityId: entityId,
        fingerprint: fingerprint ?? 'legacy',
      );
    } catch (_) {
      return null;
    }
  }
}

@immutable
class ArcNotificationSpec {
  final int id;
  final ArcNotificationType type;
  final ArcNotificationChannel channel;
  final String entityId;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final ArcNotificationRecurrence recurrence;
  final String fingerprint;

  const ArcNotificationSpec({
    required this.id,
    required this.type,
    required this.channel,
    required this.entityId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.recurrence,
    required this.fingerprint,
  });

  String get payload => ArcNotificationPayload(
        type: type,
        entityId: entityId,
        fingerprint: fingerprint,
      ).toJson();

}

@immutable
class ArcPendingNotification {
  final int id;
  final String? payload;

  const ArcPendingNotification({required this.id, this.payload});
}

@immutable
class NotificationSnapshot {
  final String? userId;
  final SettingsModel settings;
  final List<Task> tasks;
  final List<Habit> habits;
  final List<HabitEntry> habitEntries;
  final List<Transaction> transactions;
  final DateTime now;

  const NotificationSnapshot({
    required this.userId,
    required this.settings,
    required this.tasks,
    required this.habits,
    required this.habitEntries,
    required this.transactions,
    required this.now,
  });
}

@immutable
class NotificationHealth {
  final bool initialized;
  final bool reconciling;
  final ArcNotificationPermissionState permission;
  final String timezone;
  final DateTime? lastReconciledAt;
  final String? lastReason;
  final int desiredCount;
  final int pendingCount;
  final int scheduledCount;
  final int cancelledCount;
  final int unchangedCount;
  final String? lastError;
  final List<ArcNotificationSpec> desiredNotifications;
  final ArcNotificationPayload? navigationIntent;

  const NotificationHealth({
    this.initialized = false,
    this.reconciling = false,
    this.permission = ArcNotificationPermissionState.unknown,
    this.timezone = 'Unknown',
    this.lastReconciledAt,
    this.lastReason,
    this.desiredCount = 0,
    this.pendingCount = 0,
    this.scheduledCount = 0,
    this.cancelledCount = 0,
    this.unchangedCount = 0,
    this.lastError,
    this.desiredNotifications = const [],
    this.navigationIntent,
  });

  NotificationHealth copyWith({
    bool? initialized,
    bool? reconciling,
    ArcNotificationPermissionState? permission,
    String? timezone,
    DateTime? lastReconciledAt,
    String? lastReason,
    int? desiredCount,
    int? pendingCount,
    int? scheduledCount,
    int? cancelledCount,
    int? unchangedCount,
    String? lastError,
    bool clearError = false,
    List<ArcNotificationSpec>? desiredNotifications,
    ArcNotificationPayload? navigationIntent,
    bool clearNavigationIntent = false,
  }) {
    return NotificationHealth(
      initialized: initialized ?? this.initialized,
      reconciling: reconciling ?? this.reconciling,
      permission: permission ?? this.permission,
      timezone: timezone ?? this.timezone,
      lastReconciledAt: lastReconciledAt ?? this.lastReconciledAt,
      lastReason: lastReason ?? this.lastReason,
      desiredCount: desiredCount ?? this.desiredCount,
      pendingCount: pendingCount ?? this.pendingCount,
      scheduledCount: scheduledCount ?? this.scheduledCount,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      unchangedCount: unchangedCount ?? this.unchangedCount,
      lastError: clearError ? null : (lastError ?? this.lastError),
      desiredNotifications:
          desiredNotifications ?? this.desiredNotifications,
      navigationIntent: clearNavigationIntent
          ? null
          : (navigationIntent ?? this.navigationIntent),
    );
  }
}
