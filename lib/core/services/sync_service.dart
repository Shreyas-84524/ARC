import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:hive/hive.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/settings/repository/settings_repository.dart';

class SyncService {
  final String? _userId;
  final TaskRepository _taskRepository;
  final HabitRepository _habitRepository;
  final MoneyRepository _moneyRepository;
  final SettingsRepository _settingsRepository;

  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;
  late final Box _settingsBox;
  final List<StreamSubscription> _subscriptions = [];

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncService({
    String? userId,
    required TaskRepository taskRepository,
    required HabitRepository habitRepository,
    required MoneyRepository moneyRepository,
    required SettingsRepository settingsRepository,
  })  : _userId = userId,
        _taskRepository = taskRepository,
        _habitRepository = habitRepository,
        _moneyRepository = moneyRepository,
        _settingsRepository = settingsRepository {
    _settingsBox = HiveService().getUserBox(HiveService.settingsBoxName, _userId);
  }

  String? get userId => _userId;

  fs.CollectionReference<Map<String, dynamic>> _collectionRef(String colName) {
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      return _firestore.collection('users').doc(uid).collection(colName);
    }
    return _firestore.collection(colName);
  }

  fs.DocumentReference<Map<String, dynamic>> _settingsDocRef() {
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      return _firestore.collection('users').doc(uid).collection('settings').doc('profile');
    }
    return _firestore.collection('settings').doc('global');
  }

  bool isInitialSyncCompleted() {
    return _settingsBox.get('initial_sync_completed', defaultValue: false) as bool;
  }

  bool isFirstInstallAndEmpty() {
    if (isInitialSyncCompleted()) return false;
    final taskBox = HiveService().getUserBox<Task>(HiveService.tasksBoxName, _userId);
    final habitBox = HiveService().getUserBox<Habit>(HiveService.habitsBoxName, _userId);
    final moneyBox = HiveService().getUserBox<Transaction>(HiveService.moneyBoxName, _userId);
    return taskBox.isEmpty && habitBox.isEmpty && moneyBox.isEmpty;
  }

  Future<void> syncAllPending() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      debugPrint('SyncService: Starting background synchronization of pending queues...');
      await _taskRepository.syncPending();
      await _habitRepository.syncPending();
      await _moneyRepository.syncPending();
      await _settingsRepository.syncPending();
      debugPrint('SyncService: Background synchronization complete.');
    } catch (e) {
      debugPrint('SyncService warning during background sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> pullInitialDataFromFirestore({VoidCallback? onRefreshState}) async {
    try {
      debugPrint('SyncService: Downloading Cloud Firestore data to local database...');

      // 1. Sync tasks collection
      final taskBox = HiveService().getUserBox<Task>(HiveService.tasksBoxName, _userId);
      final taskQueue = HiveService().getUserBox(HiveService.tasksSyncQueueBoxName, _userId);
      final taskDocs = await _collectionRef('tasks').get().timeout(const Duration(seconds: 10));

      for (final doc in taskDocs.docs) {
        final data = doc.data();
        final remoteTask = Task.fromMap(data);
        final localTask = taskBox.get(remoteTask.id);

        // Check if there is an unpushed local edit in queue
        if (taskQueue.containsKey(remoteTask.id)) continue;

        if (localTask == null || remoteTask.updatedAt.isAfter(localTask.updatedAt) || remoteTask.updatedAt.isAtSameMomentAs(localTask.updatedAt)) {
          await taskBox.put(remoteTask.id, remoteTask);
        }
      }

      // 2. Sync habits collection
      final habitBox = HiveService().getUserBox<Habit>(HiveService.habitsBoxName, _userId);
      final habitQueue = HiveService().getUserBox(HiveService.habitsSyncQueueBoxName, _userId);
      final habitDocs = await _collectionRef('habits').get().timeout(const Duration(seconds: 10));

      for (final doc in habitDocs.docs) {
        final data = doc.data();
        final remoteHabit = Habit.fromMap(data);
        final localHabit = habitBox.get(remoteHabit.id);

        if (habitQueue.containsKey('habit_${remoteHabit.id}')) continue;

        if (localHabit == null || remoteHabit.updatedAt.isAfter(localHabit.updatedAt) || remoteHabit.updatedAt.isAtSameMomentAs(localHabit.updatedAt)) {
          await habitBox.put(remoteHabit.id, remoteHabit);
        }
      }

      // 3. Sync habit entries collection
      final entryBox = HiveService().getUserBox<HabitEntry>(HiveService.habitEntriesBoxName, _userId);
      final entryDocs = await _collectionRef('habitEntries').get().timeout(const Duration(seconds: 10));

      for (final doc in entryDocs.docs) {
        final data = doc.data();
        final entry = HabitEntry.fromMap(data);
        if (habitQueue.containsKey('entry_${entry.id}')) continue;
        await entryBox.put(entry.id, entry);
      }

      // 4. Sync transactions collection
      final txBox = HiveService().getUserBox<Transaction>(HiveService.moneyBoxName, _userId);
      final moneyQueue = HiveService().getUserBox(HiveService.moneySyncQueueBoxName, _userId);
      final txDocs = await _collectionRef('transactions').get().timeout(const Duration(seconds: 10));

      for (final doc in txDocs.docs) {
        final data = doc.data();
        final remoteTx = Transaction.fromMap(data);
        if (moneyQueue.containsKey('tx_${remoteTx.id}')) continue;
        await txBox.put(remoteTx.id, remoteTx);
      }

      // 5. Sync monthly budgets collection
      final budgetDocs = await _collectionRef('budgets').get().timeout(const Duration(seconds: 10));
      for (final doc in budgetDocs.docs) {
        final data = doc.data();
        final month = doc.id;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        if (!moneyQueue.containsKey('budget_$month')) {
          await _settingsBox.put('budget_$month', amount);
        }
      }

      // 6. Sync monthly summaries collection
      final summaryDocs = await _collectionRef('monthlySummaries').get().timeout(const Duration(seconds: 10));
      for (final doc in summaryDocs.docs) {
        final data = doc.data();
        final month = doc.id;
        if (!moneyQueue.containsKey('summary_$month')) {
          await _settingsBox.put('summary_$month', data);
        }
      }

      // 7. Sync settings document
      final settingsDoc = await _settingsDocRef().get().timeout(const Duration(seconds: 10));
      if (settingsDoc.exists && settingsDoc.data() != null) {
        final data = settingsDoc.data()!;
        final isQueued = _settingsBox.get('settings_sync_queued', defaultValue: false) as bool;
        if (!isQueued) {
          await _settingsBox.put(SettingsRepository.settingsHiveKey, data);
        }
      }

      // 8. Process any remaining local pending changes to push upstream
      await syncAllPending();

      await _settingsBox.put('initial_sync_completed', true);
      debugPrint('SyncService: Download from Firestore completed successfully.');

      if (onRefreshState != null) {
        onRefreshState();
      }
    } catch (e) {
      debugPrint("SyncService notice: You're offline. Using locally stored data. Error: $e");
    }
  }

  void startRealTimeSync({VoidCallback? onRefreshState}) {
    // Cancel existing listeners if any
    stopRealTimeSync();

    try {
      // 1. Tasks Listener
      _subscriptions.add(
        _collectionRef('tasks').snapshots().listen((snapshot) async {
          final taskBox = HiveService().getUserBox<Task>(HiveService.tasksBoxName, _userId);
          final taskQueue = HiveService().getUserBox(HiveService.tasksSyncQueueBoxName, _userId);

          for (final change in snapshot.docChanges) {
            final id = change.doc.id;
            if (taskQueue.containsKey(id)) continue;

            if (change.type == fs.DocumentChangeType.removed) {
              await taskBox.delete(id);
            } else if (change.doc.data() != null) {
              final remoteTask = Task.fromMap(change.doc.data()!);
              final localTask = taskBox.get(id);
              if (localTask == null || remoteTask.updatedAt.isAfter(localTask.updatedAt) || remoteTask.updatedAt.isAtSameMomentAs(localTask.updatedAt)) {
                await taskBox.put(id, remoteTask);
              }
            }
          }
          if (onRefreshState != null) onRefreshState();
        }, onError: (e) {
          debugPrint('SyncService real-time tasks listener notice: $e');
        }),
      );

      // 2. Habits Listener
      _subscriptions.add(
        _collectionRef('habits').snapshots().listen((snapshot) async {
          final habitBox = HiveService().getUserBox<Habit>(HiveService.habitsBoxName, _userId);
          final habitQueue = HiveService().getUserBox(HiveService.habitsSyncQueueBoxName, _userId);

          for (final change in snapshot.docChanges) {
            final id = change.doc.id;
            if (habitQueue.containsKey('habit_$id')) continue;

            if (change.type == fs.DocumentChangeType.removed) {
              await habitBox.delete(id);
            } else if (change.doc.data() != null) {
              final remoteHabit = Habit.fromMap(change.doc.data()!);
              final localHabit = habitBox.get(id);
              if (localHabit == null || remoteHabit.updatedAt.isAfter(localHabit.updatedAt) || remoteHabit.updatedAt.isAtSameMomentAs(localHabit.updatedAt)) {
                await habitBox.put(id, remoteHabit);
              }
            }
          }
          if (onRefreshState != null) onRefreshState();
        }, onError: (e) {
          debugPrint('SyncService real-time habits listener notice: $e');
        }),
      );

      // 3. Habit Entries Listener
      _subscriptions.add(
        _collectionRef('habitEntries').snapshots().listen((snapshot) async {
          final entryBox = HiveService().getUserBox<HabitEntry>(HiveService.habitEntriesBoxName, _userId);
          final habitQueue = HiveService().getUserBox(HiveService.habitsSyncQueueBoxName, _userId);

          for (final change in snapshot.docChanges) {
            final id = change.doc.id;
            if (habitQueue.containsKey('entry_$id')) continue;

            if (change.type == fs.DocumentChangeType.removed) {
              await entryBox.delete(id);
            } else if (change.doc.data() != null) {
              final entry = HabitEntry.fromMap(change.doc.data()!);
              await entryBox.put(id, entry);
            }
          }
          if (onRefreshState != null) onRefreshState();
        }, onError: (e) {
          debugPrint('SyncService real-time habitEntries listener notice: $e');
        }),
      );

      // 4. Money Transactions Listener
      _subscriptions.add(
        _collectionRef('transactions').snapshots().listen((snapshot) async {
          final txBox = HiveService().getUserBox<Transaction>(HiveService.moneyBoxName, _userId);
          final moneyQueue = HiveService().getUserBox(HiveService.moneySyncQueueBoxName, _userId);

          for (final change in snapshot.docChanges) {
            final id = change.doc.id;
            if (moneyQueue.containsKey('tx_$id')) continue;

            if (change.type == fs.DocumentChangeType.removed) {
              await txBox.delete(id);
            } else if (change.doc.data() != null) {
              final tx = Transaction.fromMap(change.doc.data()!);
              await txBox.put(id, tx);
            }
          }
          if (onRefreshState != null) onRefreshState();
        }, onError: (e) {
          debugPrint('SyncService real-time transactions listener notice: $e');
        }),
      );

      // 5. Monthly Budgets Listener
      _subscriptions.add(
        _collectionRef('budgets').snapshots().listen((snapshot) async {
          final moneyQueue = HiveService().getUserBox(HiveService.moneySyncQueueBoxName, _userId);
          for (final change in snapshot.docChanges) {
            final month = change.doc.id;
            if (moneyQueue.containsKey('budget_$month')) continue;
            if (change.type == fs.DocumentChangeType.removed) {
              await _settingsBox.delete('budget_$month');
            } else if (change.doc.data() != null) {
              final val = (change.doc.data()!['amount'] as num?)?.toDouble() ?? 0.0;
              await _settingsBox.put('budget_$month', val);
            }
          }
          if (onRefreshState != null) onRefreshState();
        }, onError: (e) {
          debugPrint('SyncService real-time budgets listener notice: $e');
        }),
      );

      // 6. Settings Listener
      _subscriptions.add(
        _settingsDocRef().snapshots().listen((snapshot) async {
          final isQueued = _settingsBox.get('settings_sync_queued', defaultValue: false) as bool;
          if (!isQueued && snapshot.exists && snapshot.data() != null) {
            await _settingsBox.put(SettingsRepository.settingsHiveKey, snapshot.data()!);
            if (onRefreshState != null) onRefreshState();
          }
        }, onError: (e) {
          debugPrint('SyncService real-time settings listener notice: $e');
        }),
      );

      debugPrint('SyncService: Real-time Firestore listeners started.');
    } catch (e) {
      debugPrint('SyncService: Failed to start real-time listeners: $e');
    }
  }

  void stopRealTimeSync() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
