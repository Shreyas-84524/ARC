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
      Hive.registerAdapter(TaskAdapter());
      Hive.registerAdapter(HabitAdapter());
      Hive.registerAdapter(HabitEntryAdapter());
      Hive.registerAdapter(TransactionAdapter());

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
