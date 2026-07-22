import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:hive/hive.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/settings/models/settings_model.dart';

class SettingsRepository {
  final Box _settingsBox = HiveService().getBox(HiveService.settingsBoxName);
  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;

  static const String settingsHiveKey = 'app_settings';

  SettingsModel getSettings() {
    try {
      final data = _settingsBox.get(settingsHiveKey);
      if (data != null && data is Map) {
        return SettingsModel.fromMap(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint('SettingsRepository getSettings warning: $e');
    }
    return SettingsModel.defaultSettings();
  }

  Future<void> saveSettings(SettingsModel settings) async {
    final map = settings.toMap();
    await _settingsBox.put(settingsHiveKey, map);

    try {
      await _firestore.collection('settings').doc('global').set(map);
      await _settingsBox.delete('settings_sync_queued');
    } catch (e) {
      debugPrint('SettingsRepository sync queued: $e');
      await _settingsBox.put('settings_sync_queued', true);
    }
  }

  Future<void> syncPending() async {
    final bool isQueued =
        _settingsBox.get('settings_sync_queued', defaultValue: false) as bool;
    if (!isQueued) return;

    try {
      final settings = getSettings();
      await _firestore.collection('settings').doc('global').set(settings.toMap());
      await _settingsBox.delete('settings_sync_queued');
    } catch (e) {
      debugPrint('SettingsRepository syncPending failed: $e');
    }
  }
}
