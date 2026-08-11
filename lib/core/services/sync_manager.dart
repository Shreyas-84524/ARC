import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/core/services/sync_service.dart';

enum SyncStatus { idle, syncing, success, failed }

class SyncManager {
  final String? _userId;

  static const String lastSuccessfulFullSyncKey = 'last_successful_full_sync';
  static const String recentSyncTimestampsKey = 'recent_successful_sync_timestamps';
  static const String syncStatusKey = 'sync_status';
  static const String syncLastErrorKey = 'sync_last_error';

  SyncManager({String? userId}) : _userId = userId;

  String? get userId => _userId;

  Box _getSettingsBox() {
    return HiveService().getUserBox(HiveService.settingsBoxName, _userId);
  }

  /// Checks if a full sync is allowed under the 12-hour minimum interval rule
  /// and the maximum 2 automatic full syncs per 24 hours rolling limit.
  bool canFullSync({DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final uid = _userId ?? 'default';
    final box = _getSettingsBox();

    // 1. Check 12-hour minimum interval
    final lastSyncIso = box.get('${lastSuccessfulFullSyncKey}_$uid') as String?;
    if (lastSyncIso != null) {
      try {
        final lastSync = DateTime.parse(lastSyncIso);
        final elapsed = currentTime.difference(lastSync);
        if (elapsed < const Duration(hours: 12)) {
          debugPrint('SyncManager: Full sync blocked. Minimum 12-hour interval has not elapsed (elapsed: ${elapsed.inHours}h ${elapsed.inMinutes % 60}m).');
          return false;
        }
      } catch (e) {
        debugPrint('SyncManager warning parsing last sync date: $e');
      }
    }

    // 2. Check rolling 24-hour window (max 2 full syncs)
    final recentSyncsList = _getRecentSuccessfulSyncs(now: currentTime);
    if (recentSyncsList.length >= 2) {
      debugPrint('SyncManager: Full sync blocked. Maximum 2 full syncs per rolling 24-hour window reached (${recentSyncsList.length} syncs in last 24h).');
      return false;
    }

    return true;
  }

  /// Executes full sync if permitted, or flushes pending change queues if blocked.
  Future<void> performFullSync({
    required SyncService syncService,
    VoidCallback? onRefreshState,
    bool forceManual = false,
    DateTime? customTime,
  }) async {
    if (_userId == null || _userId.isEmpty) {
      debugPrint('SyncManager: Full sync skipped for unauthenticated user.');
      return;
    }

    final currentTime = customTime ?? DateTime.now();
    final isFirstRunEmpty = syncService.isFirstInstallAndEmpty();

    if (!isFirstRunEmpty && !forceManual && !canFullSync(now: currentTime)) {
      debugPrint('SyncManager: Full sync blocked by cooldown policy. Flushing pending local changes only...');
      await flushPendingChanges(syncService);
      return;
    }

    _setStatus(SyncStatus.syncing);

    try {
      debugPrint('SyncManager: Starting full bidirectional Hive <-> Firestore sync for UID: $_userId...');
      await syncService.pullInitialDataFromFirestore(onRefreshState: onRefreshState);

      // Record successful full sync ONLY after pullInitialDataFromFirestore succeeds
      await recordSuccessfulSync(timestamp: currentTime);
      _setStatus(SyncStatus.success);
      _clearError();
      debugPrint('SyncManager: Full sync completed successfully.');
    } catch (e) {
      debugPrint('SyncManager error during full sync: $e');
      handleSyncFailure(e);
      rethrow;
    }
  }

  /// Flushes pending change queues (tasks, habits, money, settings).
  /// Pending change uploads are NOT full syncs and do not update or check 12h cooldown.
  Future<void> flushPendingChanges(SyncService syncService) async {
    try {
      await syncService.syncAllPending();
    } catch (e) {
      debugPrint('SyncManager notice during pending flush: $e');
    }
  }

  DateTime? getLastSuccessfulSync() {
    final uid = _userId ?? 'default';
    final box = _getSettingsBox();
    final iso = box.get('${lastSuccessfulFullSyncKey}_$uid') as String?;
    if (iso != null) {
      try {
        return DateTime.parse(iso);
      } catch (_) {}
    }
    return null;
  }

  List<DateTime> getRecentSuccessfulSyncs({DateTime? now}) {
    return _getRecentSuccessfulSyncs(now: now);
  }

  List<DateTime> _getRecentSuccessfulSyncs({DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final uid = _userId ?? 'default';
    final box = _getSettingsBox();
    final rawList = box.get('${recentSyncTimestampsKey}_$uid', defaultValue: <dynamic>[]);
    final List<DateTime> result = [];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is String) {
          try {
            final dt = DateTime.parse(item);
            if (currentTime.difference(dt) <= const Duration(hours: 24)) {
              result.add(dt);
            }
          } catch (_) {}
        }
      }
    }
    return result;
  }

  SyncStatus getSyncStatus() {
    final uid = _userId ?? 'default';
    final box = _getSettingsBox();
    final statusStr = box.get('${syncStatusKey}_$uid', defaultValue: 'idle') as String;
    switch (statusStr) {
      case 'syncing':
        return SyncStatus.syncing;
      case 'success':
        return SyncStatus.success;
      case 'failed':
        return SyncStatus.failed;
      default:
        return SyncStatus.idle;
    }
  }

  String? getLastError() {
    final uid = _userId ?? 'default';
    final box = _getSettingsBox();
    return box.get('${syncLastErrorKey}_$uid') as String?;
  }

  Future<void> recordSuccessfulSync({DateTime? timestamp}) async {
    final ts = timestamp ?? DateTime.now();
    final uid = _userId ?? 'default';
    final box = _getSettingsBox();
    final isoStr = ts.toIso8601String();

    await box.put('${lastSuccessfulFullSyncKey}_$uid', isoStr);

    final recent = _getRecentSuccessfulSyncs(now: ts);
    final updatedList = List<DateTime>.from(recent)..add(ts);

    final stringList = updatedList.map((t) => t.toIso8601String()).toList();
    await box.put('${recentSyncTimestampsKey}_$uid', stringList);
  }

  void handleSyncFailure(Object error) {
    _setStatus(SyncStatus.failed);
    final uid = _userId ?? 'default';
    final box = _getSettingsBox();
    box.put('${syncLastErrorKey}_$uid', error.toString());
  }

  void _setStatus(SyncStatus status) {
    final uid = _userId ?? 'default';
    final box = _getSettingsBox();
    box.put('${syncStatusKey}_$uid', status.name);
  }

  void _clearError() {
    final uid = _userId ?? 'default';
    final box = _getSettingsBox();
    box.delete('${syncLastErrorKey}_$uid');
  }
}
