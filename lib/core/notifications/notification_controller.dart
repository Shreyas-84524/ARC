import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arc/core/notifications/notification_models.dart';
import 'package:arc/core/notifications/notification_policy.dart';
import 'package:arc/core/notifications/notification_service.dart';

final notificationControllerProvider = StateNotifierProvider<
    NotificationController, NotificationHealth>((ref) {
  // StateNotifierProvider owns and disposes the notifier exactly once.
  return NotificationController();
});

class NotificationController extends StateNotifier<NotificationHealth> {
  final LocalNotificationGateway _gateway;
  final NotificationPolicy _policy;

  StreamSubscription<ArcNotificationPayload>? _tapSubscription;
  NotificationSnapshot? _queuedSnapshot;
  String? _queuedReason;
  bool _running = false;

  NotificationController({
    LocalNotificationGateway? gateway,
    NotificationPolicy? policy,
  })  : _gateway = gateway ?? FlutterLocalNotificationGateway(),
        _policy = policy ?? NotificationPolicy(),
        super(const NotificationHealth());

  Future<void> initialize() async {
    if (state.initialized) return;
    try {
      _tapSubscription ??= _gateway.notificationTaps.listen(
        (payload) => state = state.copyWith(navigationIntent: payload),
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('ARC_NOTIFICATIONS tap_stream_failed: $error');
          state = state.copyWith(lastError: error.toString());
        },
      );
      await _gateway.initialize();
      final permission = await _gateway.permissionState();
      state = state.copyWith(
        initialized: true,
        permission: permission,
        timezone: _gateway.timezoneName,
        clearError: true,
      );
      debugPrint(
        'ARC_NOTIFICATIONS initialized timezone=${_gateway.timezoneName} permission=${permission.name}',
      );
    } catch (error, stackTrace) {
      debugPrint('ARC_NOTIFICATIONS initialization_failed: $error\n$stackTrace');
      state = state.copyWith(
        initialized: false,
        permission: ArcNotificationPermissionState.error,
        lastError: error.toString(),
      );
    }
  }

  Future<ArcNotificationPermissionState> requestPermissionFromUserAction() async {
    if (!state.initialized) await initialize();
    final permission = await _gateway.requestPermission();
    state = state.copyWith(permission: permission);
    final snapshot = _queuedSnapshot;
    if (permission == ArcNotificationPermissionState.granted &&
        snapshot != null) {
      await reconcile(snapshot, reason: 'permission_granted');
    }
    return permission;
  }

  Future<void> refreshPermissionState() async {
    if (!state.initialized) await initialize();
    if (!state.initialized) return;
    final permission = await _gateway.permissionState();
    state = state.copyWith(permission: permission);
  }

  Future<void> reconcile(
    NotificationSnapshot snapshot, {
    required String reason,
  }) async {
    _queuedSnapshot = snapshot;
    _queuedReason = reason;
    if (_running) return;

    _running = true;
    try {
      while (_queuedSnapshot != null) {
        final nextSnapshot = _queuedSnapshot!;
        final nextReason = _queuedReason ?? 'unspecified';
        _queuedSnapshot = null;
        _queuedReason = null;
        await _reconcileOnce(nextSnapshot, nextReason);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _reconcileOnce(
    NotificationSnapshot snapshot,
    String reason,
  ) async {
    if (!state.initialized) await initialize();
    if (!state.initialized) return;

    state = state.copyWith(reconciling: true, lastReason: reason);
    try {
      final permission = await _gateway.permissionState();
      final desired = _policy.build(snapshot);
      final pending = await _gateway.pendingNotifications();

      var cancelled = 0;
      var scheduled = 0;
      var unchanged = 0;

      final desiredById = <int, ArcNotificationSpec>{
        for (final spec in desired) spec.id: spec,
      };
      final pendingById = <int, ArcPendingNotification>{
        for (final request in pending) request.id: request,
      };

      // If permission or the master switch is disabled, clear ARC schedules.
      final schedulingAllowed =
          permission == ArcNotificationPermissionState.granted &&
              snapshot.userId != null &&
              snapshot.userId!.isNotEmpty &&
              snapshot.settings.masterNotificationsEnabled;

      for (final request in pending) {
        final payload = ArcNotificationPayload.tryParse(request.payload);
        if (payload == null) continue;
        final expected = schedulingAllowed ? desiredById[request.id] : null;
        if (expected == null || payload.fingerprint != expected.fingerprint) {
          await _gateway.cancel(request.id);
          cancelled++;
        }
      }

      if (schedulingAllowed) {
        for (final spec in desired) {
          final existing = pendingById[spec.id];
          final existingPayload =
              ArcNotificationPayload.tryParse(existing?.payload);
          if (existingPayload?.fingerprint == spec.fingerprint) {
            unchanged++;
            continue;
          }
          await _gateway.schedule(spec);
          scheduled++;
        }
      }

      final refreshedPending = await _gateway.pendingNotifications();
      state = state.copyWith(
        initialized: true,
        reconciling: false,
        permission: permission,
        timezone: _gateway.timezoneName,
        lastReconciledAt: DateTime.now(),
        lastReason: reason,
        desiredCount: schedulingAllowed ? desired.length : 0,
        pendingCount: refreshedPending.length,
        scheduledCount: scheduled,
        cancelledCount: cancelled,
        unchangedCount: unchanged,
        desiredNotifications: schedulingAllowed ? desired : const [],
        clearError: true,
      );
      debugPrint(
        'ARC_NOTIFICATIONS reconciled reason=$reason desired=${desired.length} pending=${refreshedPending.length} scheduled=$scheduled cancelled=$cancelled unchanged=$unchanged',
      );
    } catch (error, stackTrace) {
      debugPrint('ARC_NOTIFICATIONS reconciliation_failed: $error\n$stackTrace');
      state = state.copyWith(
        reconciling: false,
        lastReconciledAt: DateTime.now(),
        lastReason: reason,
        lastError: error.toString(),
      );
    }
  }

  Future<void> handleLogout() async {
    if (!state.initialized) await initialize();
    try {
      await _gateway.cancelAll();
      state = state.copyWith(
        desiredCount: 0,
        pendingCount: 0,
        scheduledCount: 0,
        cancelledCount: 0,
        unchangedCount: 0,
        desiredNotifications: const [],
        lastReconciledAt: DateTime.now(),
        lastReason: 'logout',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(lastError: error.toString());
    }
  }

  void clearNavigationIntent() {
    state = state.copyWith(clearNavigationIntent: true);
  }

  @override
  void dispose() {
    unawaited(_tapSubscription?.cancel());
    unawaited(_gateway.dispose());
    super.dispose();
  }
}
