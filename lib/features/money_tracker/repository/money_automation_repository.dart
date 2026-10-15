import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/money_tracker/models/money_automation_state.dart';

/// LOCAL-ONLY ARCHITECTURE RULE:
/// Money Automation preferences must NEVER sync with Firebase, Firestore, or any remote sync queue.
/// - NO Firestore collections
/// - NO sync queues
/// - NO remote cloud listeners
/// All preferences remain strictly local on the device and scoped to the user's Firebase UID.
class MoneyAutomationRepository {
  static const String boxName = HiveService.moneyAutomationPreferencesBoxName;

  static const String prefEnabledKey = 'automatic_spending_tracking_enabled';
  static const String prefPromptMonthKey = 'automation_prompt_month';
  static const String prefPromptCountKey = 'automation_prompt_count';
  static const String prefInfoDialogAcceptedKey = 'automation_info_dialog_accepted';

  final Box? _box;
  final Map<String, dynamic> _inMemoryStore = {};
  final bool inMemoryOnly;

  MoneyAutomationRepository({Box? box, this.inMemoryOnly = false}) : _box = box;

  String _scopedKey(String? userId, String key) {
    final effectiveUid = (userId != null && userId.isNotEmpty) ? userId : 'anonymous';
    return '${effectiveUid}_$key';
  }

  Box? _getBox(String? userId) {
    if (inMemoryOnly) return null;
    if (_box != null && _box.isOpen) return _box;

    try {
      if (HiveService().isInitialized) {
        return HiveService().getUserBox(boxName, userId);
      }
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box(boxName);
      }
    } catch (e) {
      debugPrint('MoneyAutomationRepository: box access warning: $e');
    }
    return null;
  }

  /// Loads the persisted automation state for [userId].
  MoneyAutomationState loadState(String? userId) {
    try {
      final box = _getBox(userId);
      if (box != null && box.isOpen) {
        final enabled = box.get(_scopedKey(userId, prefEnabledKey), defaultValue: false) as bool;
        final month = box.get(_scopedKey(userId, prefPromptMonthKey), defaultValue: '') as String;
        final count = (box.get(_scopedKey(userId, prefPromptCountKey), defaultValue: 0) as num).toInt();
        final accepted = box.get(_scopedKey(userId, prefInfoDialogAcceptedKey), defaultValue: false) as bool;

        return MoneyAutomationState(
          isEnabled: enabled,
          promptMonth: month,
          promptCount: count,
          hasAcceptedInfoDialog: accepted,
          isDismissedForSession: false,
        );
      } else {
        final enabled = (_inMemoryStore[_scopedKey(userId, prefEnabledKey)] ?? false) as bool;
        final month = (_inMemoryStore[_scopedKey(userId, prefPromptMonthKey)] ?? '') as String;
        final count = ((_inMemoryStore[_scopedKey(userId, prefPromptCountKey)] ?? 0) as num).toInt();
        final accepted = (_inMemoryStore[_scopedKey(userId, prefInfoDialogAcceptedKey)] ?? false) as bool;

        return MoneyAutomationState(
          isEnabled: enabled,
          promptMonth: month,
          promptCount: count,
          hasAcceptedInfoDialog: accepted,
          isDismissedForSession: false,
        );
      }
    } catch (e) {
      debugPrint('MoneyAutomationRepository: failed to load state ($e), using defaults.');
      return const MoneyAutomationState();
    }
  }

  /// Saves the user's opt-in choice.
  Future<void> setAutomationEnabled(String? userId, bool enabled) async {
    final box = _getBox(userId);
    final key = _scopedKey(userId, prefEnabledKey);
    if (box != null && box.isOpen) {
      await box.put(key, enabled);
    } else {
      _inMemoryStore[key] = enabled;
    }
  }

  /// Records that the user accepted the information dialog.
  Future<void> setInfoDialogAccepted(String? userId, bool accepted) async {
    final box = _getBox(userId);
    final key = _scopedKey(userId, prefInfoDialogAcceptedKey);
    if (box != null && box.isOpen) {
      await box.put(key, accepted);
    } else {
      _inMemoryStore[key] = accepted;
    }
  }

  /// Records an actual appearance of the prompt in the given [currentMonth].
  ///
  /// If the recorded month does not match [currentMonth], the counter is reset to 1
  /// and the month is updated. If it matches, the count increments by 1.
  Future<void> recordPromptAppearance(String? userId, String currentMonth) async {
    final box = _getBox(userId);
    final monthKey = _scopedKey(userId, prefPromptMonthKey);
    final countKey = _scopedKey(userId, prefPromptCountKey);

    String storedMonth = '';
    int storedCount = 0;

    if (box != null && box.isOpen) {
      storedMonth = box.get(monthKey, defaultValue: '') as String;
      storedCount = (box.get(countKey, defaultValue: 0) as num).toInt();
    } else {
      storedMonth = (_inMemoryStore[monthKey] ?? '') as String;
      storedCount = ((_inMemoryStore[countKey] ?? 0) as num).toInt();
    }

    final int newCount = (storedMonth == currentMonth) ? storedCount + 1 : 1;

    if (box != null && box.isOpen) {
      await box.put(monthKey, currentMonth);
      await box.put(countKey, newCount);
    } else {
      _inMemoryStore[monthKey] = currentMonth;
      _inMemoryStore[countKey] = newCount;
    }
  }

  /// Resets prompt history for [userId] (used when testing or on explicit request).
  Future<void> resetPromptHistory(String? userId) async {
    final box = _getBox(userId);
    final monthKey = _scopedKey(userId, prefPromptMonthKey);
    final countKey = _scopedKey(userId, prefPromptCountKey);

    if (box != null && box.isOpen) {
      await box.delete(monthKey);
      await box.delete(countKey);
    } else {
      _inMemoryStore.remove(monthKey);
      _inMemoryStore.remove(countKey);
    }
  }

  /// Clears all preferences for [userId].
  Future<void> clearAll(String? userId) async {
    final box = _getBox(userId);
    for (final k in [
      prefEnabledKey,
      prefPromptMonthKey,
      prefPromptCountKey,
      prefInfoDialogAcceptedKey,
    ]) {
      final key = _scopedKey(userId, k);
      if (box != null && box.isOpen) {
        await box.delete(key);
      } else {
        _inMemoryStore.remove(key);
      }
    }
  }
}
