import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // Box names
  static const String tasksBoxName = 'tasks_box';
  static const String tasksSyncQueueBoxName = 'tasks_sync_queue_box';
  static const String habitsBoxName = 'habits_box';
  static const String habitEntriesBoxName = 'habit_entries_box';
  static const String habitsSyncQueueBoxName = 'habits_sync_queue_box';
  static const String moneyBoxName = 'money_box';
  static const String moneySyncQueueBoxName = 'money_sync_queue_box';
  static const String settingsBoxName = 'settings_box';

  Future<void> init() async {
    if (_initialized) return;

    try {
      // Initialize Hive for Flutter
      await Hive.initFlutter();

      // Register Adapters
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(HabitAdapter());
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HabitEntryAdapter());
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(TransactionAdapter());

      // Open caching boxes
      await Hive.openBox<Task>(tasksBoxName);
      await Hive.openBox(tasksSyncQueueBoxName);
      await Hive.openBox<Habit>(habitsBoxName);
      await Hive.openBox<HabitEntry>(habitEntriesBoxName);
      await Hive.openBox(habitsSyncQueueBoxName);
      await Hive.openBox<Transaction>(moneyBoxName);
      await Hive.openBox(moneySyncQueueBoxName);
      await Hive.openBox(settingsBoxName);

      _initialized = true;
      debugPrint('HiveService: successfully initialized and boxes opened.');
    } catch (e) {
      debugPrint('HiveService initialization failed: $e');
    }
  }

  // Generic getter to read a box
  Box<T> getBox<T>(String boxName) {
    if (!_initialized || !Hive.isBoxOpen(boxName)) {
      throw StateError('HiveService has not been initialized or box $boxName is not open.');
    }
    return Hive.box<T>(boxName);
  }

  /// Helper to generate a user-scoped Hive box name.
  ///
  /// If [userId] is null or empty, returns the legacy default [baseBoxName].
  /// Otherwise, returns "{baseBoxName}_{userId}".
  static String getUserBoxName(String baseBoxName, String? userId) {
    if (userId == null || userId.isEmpty) {
      return baseBoxName;
    }
    return '${baseBoxName}_$userId';
  }

  /// Opens a user-scoped Hive box dynamically if not already open.
  Future<Box<T>> openUserBox<T>(String baseBoxName, String? userId) async {
    final scopedName = getUserBoxName(baseBoxName, userId);
    if (!Hive.isBoxOpen(scopedName)) {
      return await Hive.openBox<T>(scopedName);
    }
    return Hive.box<T>(scopedName);
  }

  /// Retrieves a user-scoped Hive box if open, falling back to legacy default box.
  Box<T> getUserBox<T>(String baseBoxName, String? userId) {
    final scopedName = getUserBoxName(baseBoxName, userId);
    if (!_initialized || !Hive.isBoxOpen(scopedName)) {
      // Fallback to base box if open, or throw error
      if (Hive.isBoxOpen(baseBoxName)) {
        return Hive.box<T>(baseBoxName);
      }
      throw StateError('HiveService: box $scopedName is not open.');
    }
    return Hive.box<T>(scopedName);
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
