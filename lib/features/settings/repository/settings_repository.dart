import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:hive/hive.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/settings/models/settings_model.dart';

class SettingsRepository {
  final String? _userId;
  final Box _settingsBox;
  final fs.FirebaseFirestore? _firestore;

  static const String settingsHiveKey = 'app_settings';

  SettingsRepository({String? userId, fs.FirebaseFirestore? firestore})
      : _userId = userId,
        _settingsBox = HiveService().getUserBox(HiveService.settingsBoxName, userId),
        _firestore = firestore;

  fs.FirebaseFirestore get _db => _firestore ?? fs.FirebaseFirestore.instance;

  String? get userId => _userId;

  fs.DocumentReference<Map<String, dynamic>> _settingsDocRef() {
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      return _db.collection('users').doc(uid).collection('settings').doc('profile');
    }
    return _db.collection('settings').doc('global');
  }

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
      await _settingsDocRef().set(map);
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
      await _settingsDocRef().set(settings.toMap());
      await _settingsBox.delete('settings_sync_queued');
    } catch (e) {
      debugPrint('SettingsRepository syncPending failed: $e');
    }
  }
}
