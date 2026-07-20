import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // Box names
  static const String tasksBoxName = 'tasks_box';
  static const String habitsBoxName = 'habits_box';
  static const String moneyBoxName = 'money_box';
  static const String settingsBoxName = 'settings_box';

  Future<void> init() async {
    if (_initialized) return;

    try {
      // Initialize Hive for Flutter
      await Hive.initFlutter();

      // Open caching boxes
      await Hive.openBox(tasksBoxName);
      await Hive.openBox(habitsBoxName);
      await Hive.openBox(moneyBoxName);
      await Hive.openBox(settingsBoxName);

      _initialized = true;
      debugPrint('HiveService: successfully initialized and boxes opened.');
    } catch (e) {
      debugPrint('HiveService initialization failed: $e');
    }
  }

  // Generic getter to read a box
  Box getBox(String boxName) {
    if (!_initialized) {
      throw StateError('HiveService has not been initialized. Call init() first.');
    }
    return Hive.box(boxName);
  }

  // Helper methods to read/write settings cache
  Future<void> cacheSetting(String key, dynamic value) async {
    final box = getBox(settingsBoxName);
    await box.put(key, value);
  }

  dynamic getCachedSetting(String key, {dynamic defaultValue}) {
    final box = getBox(settingsBoxName);
    return box.get(key, defaultValue: defaultValue);
  }
}
