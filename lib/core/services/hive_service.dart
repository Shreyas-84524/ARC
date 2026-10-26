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

  @visibleForTesting
  void setInitializedForTesting(bool value) {
    _initialized = value;
  }

  // Box names
  static const String tasksBoxName = 'tasks_box';
  static const String tasksSyncQueueBoxName = 'tasks_sync_queue_box';
  static const String habitsBoxName = 'habits_box';
  static const String habitEntriesBoxName = 'habit_entries_box';
  static const String habitsSyncQueueBoxName = 'habits_sync_queue_box';
  static const String moneyBoxName = 'money_box';
  static const String moneySyncQueueBoxName = 'money_sync_queue_box';
  static const String settingsBoxName = 'settings_box';
  // Local-only Secret Notes namespaces (NEVER synced with cloud/Firebase)
  static const String secretNotesSecurityBoxName = 'secret_notes_security';
  static const String secretNotesPreferencesBoxName = 'secret_notes_preferences';
  static const String secretNotesDataBoxName = 'secret_notes_data';
  // Local-only Money Automation preferences (NEVER synced with cloud/Firebase)
  static const String moneyAutomationPreferencesBoxName = 'money_automation_preferences';
  // Local-only Feedback Acknowledgement deduplication box
  static const String feedbackAcknowledgementsBoxName = 'feedback_acknowledgements_box';

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
      await Hive.openBox(secretNotesSecurityBoxName);
      await Hive.openBox(secretNotesPreferencesBoxName);
      await Hive.openBox(secretNotesDataBoxName);
      await Hive.openBox(moneyAutomationPreferencesBoxName);
      await Hive.openBox(feedbackAcknowledgementsBoxName);

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

  /// Opens all user-scoped Hive boxes for [userId].
  /// If user-scoped box is empty and legacy base box has records,
  /// copies legacy local records into the user-scoped box.
  Future<void> ensureUserBoxesOpened(String? userId) async {
    if (!_initialized) return;
    if (userId == null || userId.isEmpty) return;

    await _openAndMigrateUserBox<Task>(tasksBoxName, userId);
    await _openAndMigrateUntypedBox(tasksSyncQueueBoxName, userId);
    await _openAndMigrateUserBox<Habit>(habitsBoxName, userId);
    await _openAndMigrateUserBox<HabitEntry>(habitEntriesBoxName, userId);
    await _openAndMigrateUntypedBox(habitsSyncQueueBoxName, userId);
    await _openAndMigrateUserBox<Transaction>(moneyBoxName, userId);
    await _openAndMigrateUntypedBox(moneySyncQueueBoxName, userId);
    await _openAndMigrateUntypedBox(settingsBoxName, userId);
    await _openAndMigrateUntypedBox(moneyAutomationPreferencesBoxName, userId);

    debugPrint('HiveService: All user-scoped boxes opened for UID: $userId');
  }

  /// Closes all user-scoped Hive boxes for [userId].
  /// Leaves box files on disk completely intact so data is restored on next login.
  Future<void> closeUserBoxes(String? userId) async {
    if (userId == null || userId.isEmpty) return;

    final typedBoxNames = [
      getUserBoxName(tasksBoxName, userId),
      getUserBoxName(habitsBoxName, userId),
      getUserBoxName(habitEntriesBoxName, userId),
      getUserBoxName(moneyBoxName, userId),
    ];

    for (final name in typedBoxNames) {
      if (Hive.isBoxOpen(name)) {
        try {
          if (name.startsWith(tasksBoxName)) {
            await Hive.box<Task>(name).close();
          } else if (name.startsWith(habitEntriesBoxName)) {
            await Hive.box<HabitEntry>(name).close();
          } else if (name.startsWith(habitsBoxName)) {
            await Hive.box<Habit>(name).close();
          } else if (name.startsWith(moneyBoxName)) {
            await Hive.box<Transaction>(name).close();
          }
          debugPrint('HiveService: Closed typed user-scoped box: $name');
        } catch (e) {
          debugPrint('HiveService warning closing typed box $name: $e');
        }
      }
    }

    final untypedBoxNames = [
      getUserBoxName(tasksSyncQueueBoxName, userId),
      getUserBoxName(habitsSyncQueueBoxName, userId),
      getUserBoxName(moneySyncQueueBoxName, userId),
      getUserBoxName(settingsBoxName, userId),
      getUserBoxName(moneyAutomationPreferencesBoxName, userId),
    ];

    for (final name in untypedBoxNames) {
      if (Hive.isBoxOpen(name)) {
        try {
          await Hive.box(name).close();
          debugPrint('HiveService: Closed untyped user-scoped box: $name');
        } catch (e) {
          debugPrint('HiveService warning closing untyped box $name: $e');
        }
      }
    }
  }

  Future<Box<T>> _openAndMigrateUserBox<T>(String baseBoxName, String userId) async {
    final scopedName = getUserBoxName(baseBoxName, userId);
    if (!Hive.isBoxOpen(scopedName)) {
      await Hive.openBox<T>(scopedName);
    }
    final scopedBox = Hive.box<T>(scopedName);

    // If scoped box is brand new/empty and base box has data, copy existing local data safely
    if (scopedBox.isEmpty && Hive.isBoxOpen(baseBoxName)) {
      final baseBox = Hive.box<T>(baseBoxName);
      if (baseBox.isNotEmpty) {
        debugPrint('HiveService: Copying ${baseBox.length} legacy records from $baseBoxName to $scopedName');
        for (final key in baseBox.keys) {
          final val = baseBox.get(key);
          if (val != null) {
            await scopedBox.put(key, val);
          }
        }
      }
    }
    return scopedBox;
  }

  Future<Box> _openAndMigrateUntypedBox(String baseBoxName, String userId) async {
    final scopedName = getUserBoxName(baseBoxName, userId);
    if (!Hive.isBoxOpen(scopedName)) {
      await Hive.openBox(scopedName);
    }
    final scopedBox = Hive.box(scopedName);

    if (scopedBox.isEmpty && Hive.isBoxOpen(baseBoxName)) {
      final baseBox = Hive.box(baseBoxName);
      if (baseBox.isNotEmpty) {
        debugPrint('HiveService: Copying ${baseBox.length} legacy records from $baseBoxName to $scopedName');
        for (final key in baseBox.keys) {
          final val = baseBox.get(key);
          if (val != null) {
            await scopedBox.put(key, val);
          }
        }
      }
    }
    return scopedBox;
  }

  /// Retrieves a user-scoped Hive box if open, falling back to legacy default box.
  Box<T> getUserBox<T>(String baseBoxName, String? userId) {
    final scopedName = getUserBoxName(baseBoxName, userId);
    if (!_initialized) {
      throw StateError('HiveService has not been initialized.');
    }

    if (Hive.isBoxOpen(scopedName)) {
      return Hive.box<T>(scopedName);
    }

    // Fallback to base box if open
    if (Hive.isBoxOpen(baseBoxName)) {
      return Hive.box<T>(baseBoxName);
    }

    throw StateError('HiveService: box $scopedName (or fallback $baseBoxName) is not open.');
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

