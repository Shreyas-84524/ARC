import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:hive/hive.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/settings/models/settings_model.dart';

class SettingsRepository {
  final String? _userId;
  final Box? _settingsBox;
  final fs.FirebaseFirestore? _firestore;

  static const String settingsHiveKey = 'app_settings';

  SettingsRepository({String? userId, fs.FirebaseFirestore? firestore, Box? settingsBox})
      : _userId = userId,
        _settingsBox = settingsBox ?? _safeGetBox(userId),
        _firestore = firestore;

  static Box? _safeGetBox(String? userId) {
    try {
      return HiveService().getUserBox(HiveService.settingsBoxName, userId);
    } catch (e) {
      debugPrint('SettingsRepository: Hive box not available: $e');
      return null;
    }
  }

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
      if (_settingsBox != null) {
        final data = _settingsBox.get(settingsHiveKey);
        if (data != null && data is Map) {
          return SettingsModel.fromMap(Map<String, dynamic>.from(data));
        }
      }
    } catch (e) {
      debugPrint('SettingsRepository getSettings warning: $e');
    }
    return SettingsModel.defaultSettings();
  }

  Future<void> saveSettings(SettingsModel settings) async {
    final map = settings.toMap();
    if (_settingsBox != null) {
      await _settingsBox.put(settingsHiveKey, map);
    }

    try {
      await _settingsDocRef().set(map);
      if (_settingsBox != null) {
        await _settingsBox.delete('settings_sync_queued');
      }
    } catch (e) {
      debugPrint('SettingsRepository sync queued: $e');
      if (_settingsBox != null) {
        await _settingsBox.put('settings_sync_queued', true);
      }
    }
  }

  Future<bool> syncPending() async {
    if (_settingsBox == null) return true;
    final bool isQueued =
        _settingsBox.get('settings_sync_queued', defaultValue: false) as bool;
    if (!isQueued) return true;

    try {
      final docPath = _settingsDocRef().path;
      debugPrint('[SettingsRepository.syncPending] Attempting settings set on path: $docPath for UID: $_userId');
      final settings = getSettings();
      await _settingsDocRef().set(settings.toMap()).timeout(const Duration(seconds: 8));
      await _settingsBox.delete('settings_sync_queued');
      debugPrint('[SettingsRepository.syncPending] SUCCESS: settings sync completed.');
      return true;
    } catch (e) {
      debugPrint('[SettingsRepository.syncPending] FAILURE: settings sync failed: $e');
      return false;
    }
  }
}
