import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/core/services/sync_manager.dart';
import 'package:arc/core/services/sync_service.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/models/monthly_summary_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/settings/repository/settings_repository.dart';
import 'package:arc/features/settings/models/settings_model.dart';

class TestTaskRepo implements TaskRepository {
  final String? _uid;
  final Box _queueBox;
  final Box<Task> _taskBox;
  bool shouldFail = false;
  int writeCount = 0;

  TestTaskRepo(this._uid)
      : _queueBox = HiveService().getUserBox(HiveService.tasksSyncQueueBoxName, _uid),
        _taskBox = HiveService().getUserBox<Task>(HiveService.tasksBoxName, _uid);

  @override
  String? get userId => _uid;

  @override
  List<Task> getTasks() => _taskBox.values.toList();

  @override
  Future<void> saveTask(Task task) async {
    await _taskBox.put(task.id, task);
    await _queueBox.put(task.id, {
      'id': task.id,
      'action': 'upsert',
      'data': task.toMap(),
    });
  }

  @override
  Future<void> deleteTask(String id) async {
    await _taskBox.delete(id);
    await _queueBox.put(id, {
      'id': id,
      'action': 'delete',
    });
  }

  @override
  Future<bool> syncPending() async {
    if (_queueBox.isEmpty) return true;
    if (shouldFail) return false;

    final keys = List.from(_queueBox.keys);
    for (final k in keys) {
      writeCount++;
      await _queueBox.delete(k);
    }
    return true;
  }

  @override
  Future<int> performEndOfDayCleanup({String? overrideDateStr}) async => 0;
}

class TestHabitRepo implements HabitRepository {
  final String? _uid;
  final Box _queueBox;
  final Box<Habit> _habitBox;
  bool shouldFail = false;
  int writeCount = 0;

  TestHabitRepo(this._uid)
      : _queueBox = HiveService().getUserBox(HiveService.habitsSyncQueueBoxName, _uid),
        _habitBox = HiveService().getUserBox<Habit>(HiveService.habitsBoxName, _uid);

  @override
  String? get userId => _uid;

  @override
  List<Habit> getHabits() => _habitBox.values.toList();

  @override
  List<HabitEntry> getEntries() => [];

  @override
  Future<void> saveHabit(Habit habit) async {
    await _habitBox.put(habit.id, habit);
    await _queueBox.put('habit_${habit.id}', {
      'id': habit.id,
      'type': 'habit',
      'action': 'upsert',
      'data': habit.toMap(),
    });
  }

  @override
  Future<void> deleteHabit(String id) async {
    await _habitBox.delete(id);
    await _queueBox.put('habit_$id', {
      'id': id,
      'type': 'habit',
      'action': 'delete',
    });
  }

  @override
  Future<void> toggleEntry(String habitId, String dateStr, bool completed) async {}

  @override
  Future<bool> syncPending() async {
    if (_queueBox.isEmpty) return true;
    if (shouldFail) return false;

    final keys = List.from(_queueBox.keys);
    for (final k in keys) {
      writeCount++;
      await _queueBox.delete(k);
    }
    return true;
  }
}

class TestMoneyRepo implements MoneyRepository {
  final String? _uid;
  final Box _queueBox;
  final Box<Transaction> _txBox;
  bool shouldFail = false;
  int writeCount = 0;

  TestMoneyRepo(this._uid)
      : _queueBox = HiveService().getUserBox(HiveService.moneySyncQueueBoxName, _uid),
        _txBox = HiveService().getUserBox<Transaction>(HiveService.moneyBoxName, _uid);

  @override
  String? get userId => _uid;

  @override
  List<Transaction> getTransactions() => _txBox.values.toList();

  @override
  double getMonthlyBudget(String yearMonth) => 0.0;

  @override
  Future<void> saveMonthlyBudget(String yearMonth, double amount) async {}

  @override
  Future<void> saveTransaction(Transaction tx) async {
    await _txBox.put(tx.id, tx);
    await _queueBox.put('tx_${tx.id}', {
      'id': tx.id,
      'type': 'tx',
      'action': 'upsert',
      'data': tx.toMap(),
    });
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _txBox.delete(id);
    await _queueBox.put('tx_$id', {
      'id': id,
      'type': 'tx',
      'action': 'delete',
    });
  }

  @override
  Future<void> saveMonthlySummary(MonthlySummary summary) async {}

  @override
  Future<bool> syncPending() async {
    if (_queueBox.isEmpty) return true;
    if (shouldFail) return false;

    final keys = List.from(_queueBox.keys);
    for (final k in keys) {
      writeCount++;
      await _queueBox.delete(k);
    }
    return true;
  }
}

class TestSettingsRepo implements SettingsRepository {
  final String? _uid;
  bool shouldFail = false;

  TestSettingsRepo(this._uid);

  @override
  String? get userId => _uid;

  @override
  SettingsModel getSettings() => SettingsModel.defaultSettings();

  @override
  Future<void> saveSettings(SettingsModel settings) async {}

  @override
  Future<bool> syncPending() async {
    return !shouldFail;
  }
}

Task createTask(String id, String title) {
  return Task(
    id: id,
    title: title,
    description: '',
    category: 'General',
    priority: 'Medium',
    labels: [],
    completed: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

Habit createHabit(String id, String name) {
  return Habit(
    id: id,
    name: name,
    category: 'General',
    colorValue: 0xFF000000,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

Transaction createTx(String id, double amount) {
  return Transaction(
    id: id,
    amount: amount,
    type: 'Expense',
    category: 'Food',
    date: DateTime.now(),
    notes: '',
    time: '12:00 PM',
    createdAt: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('arc_critical_logout_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(HabitAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HabitEntryAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(TransactionAdapter());

    await Hive.openBox<Task>(HiveService.tasksBoxName);
    await Hive.openBox(HiveService.tasksSyncQueueBoxName);
    await Hive.openBox<Habit>(HiveService.habitsBoxName);
    await Hive.openBox<HabitEntry>(HiveService.habitEntriesBoxName);
    await Hive.openBox(HiveService.habitsSyncQueueBoxName);
    await Hive.openBox<Transaction>(HiveService.moneyBoxName);
    await Hive.openBox(HiveService.moneySyncQueueBoxName);
    await Hive.openBox(HiveService.settingsBoxName);

    HiveService().setInitializedForTesting(true);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 10 — Critical Logout Synchronization Test Suite', () {
    test('TEST 1 — Logout with zero pending queue items succeeds immediately', () async {
      const uid = 'user_test_1';
      await HiveService().ensureUserBoxesOpened(uid);

      final taskRepo = TestTaskRepo(uid);
      final habitRepo = TestHabitRepo(uid);
      final moneyRepo = TestMoneyRepo(uid);
      final settingsRepo = TestSettingsRepo(uid);

      final syncService = SyncService(
        userId: uid,
        taskRepository: taskRepo,
        habitRepository: habitRepo,
        moneyRepository: moneyRepo,
        settingsRepository: settingsRepo,
      );

      final syncManager = SyncManager(userId: uid);
      final success = await syncManager.flushPendingChanges(syncService);

      expect(success, isTrue);
      expect(syncManager.getLogoutSyncStatus(), LogoutSyncStatus.success);
    });

    test('TEST 2 — Logout with pending Task mutation flushes task queue cleanly', () async {
      const uid = 'user_test_2';
      await HiveService().ensureUserBoxesOpened(uid);

      final taskRepo = TestTaskRepo(uid);
      final habitRepo = TestHabitRepo(uid);
      final moneyRepo = TestMoneyRepo(uid);
      final settingsRepo = TestSettingsRepo(uid);

      await taskRepo.saveTask(createTask('task_t2', 'Task test 2'));

      final q = HiveService().getUserBox(HiveService.tasksSyncQueueBoxName, uid);
      expect(q.length, 1);

      final syncService = SyncService(
        userId: uid,
        taskRepository: taskRepo,
        habitRepository: habitRepo,
        moneyRepository: moneyRepo,
        settingsRepository: settingsRepo,
      );

      final syncManager = SyncManager(userId: uid);
      final success = await syncManager.flushPendingChanges(syncService);

      expect(success, isTrue);
      expect(q.isEmpty, isTrue);
      expect(taskRepo.writeCount, 1);
    });

    test('TEST 3 — Logout with pending Habit mutation flushes habit queue cleanly', () async {
      const uid = 'user_test_3';
      await HiveService().ensureUserBoxesOpened(uid);

      final taskRepo = TestTaskRepo(uid);
      final habitRepo = TestHabitRepo(uid);
      final moneyRepo = TestMoneyRepo(uid);
      final settingsRepo = TestSettingsRepo(uid);

      await habitRepo.saveHabit(createHabit('habit_t3', 'Habit test 3'));

      final q = HiveService().getUserBox(HiveService.habitsSyncQueueBoxName, uid);
      expect(q.length, 1);

      final syncService = SyncService(
        userId: uid,
        taskRepository: taskRepo,
        habitRepository: habitRepo,
        moneyRepository: moneyRepo,
        settingsRepository: settingsRepo,
      );

      final syncManager = SyncManager(userId: uid);
      final success = await syncManager.flushPendingChanges(syncService);

      expect(success, isTrue);
      expect(q.isEmpty, isTrue);
      expect(habitRepo.writeCount, 1);
    });

    test('TEST 4 — Logout with pending Transaction mutation flushes money queue cleanly', () async {
      const uid = 'user_test_4';
      await HiveService().ensureUserBoxesOpened(uid);

      final taskRepo = TestTaskRepo(uid);
      final habitRepo = TestHabitRepo(uid);
      final moneyRepo = TestMoneyRepo(uid);
      final settingsRepo = TestSettingsRepo(uid);

      await moneyRepo.saveTransaction(createTx('tx_t4', 50.0));

      final q = HiveService().getUserBox(HiveService.moneySyncQueueBoxName, uid);
      expect(q.length, 1);

      final syncService = SyncService(
        userId: uid,
        taskRepository: taskRepo,
        habitRepository: habitRepo,
        moneyRepository: moneyRepo,
        settingsRepository: settingsRepo,
      );

      final syncManager = SyncManager(userId: uid);
      final success = await syncManager.flushPendingChanges(syncService);

      expect(success, isTrue);
      expect(q.isEmpty, isTrue);
      expect(moneyRepo.writeCount, 1);
    });

    test('TEST 5 — Logout with multiple pending mutations flushes all queues', () async {
      const uid = 'user_test_5';
      await HiveService().ensureUserBoxesOpened(uid);

      final taskRepo = TestTaskRepo(uid);
      final habitRepo = TestHabitRepo(uid);
      final moneyRepo = TestMoneyRepo(uid);
      final settingsRepo = TestSettingsRepo(uid);

      await taskRepo.saveTask(createTask('t5_task', 'T5 Task'));
      await habitRepo.saveHabit(createHabit('t5_habit', 'T5 Habit'));
      await moneyRepo.saveTransaction(createTx('t5_tx', 10.0));

      final taskQ = HiveService().getUserBox(HiveService.tasksSyncQueueBoxName, uid);
      final habitQ = HiveService().getUserBox(HiveService.habitsSyncQueueBoxName, uid);
      final moneyQ = HiveService().getUserBox(HiveService.moneySyncQueueBoxName, uid);

      expect(taskQ.length, 1);
      expect(habitQ.length, 1);
      expect(moneyQ.length, 1);

      final syncService = SyncService(
        userId: uid,
        taskRepository: taskRepo,
        habitRepository: habitRepo,
        moneyRepository: moneyRepo,
        settingsRepository: settingsRepo,
      );

      final syncManager = SyncManager(userId: uid);
      final success = await syncManager.flushPendingChanges(syncService);

      expect(success, isTrue);
      expect(taskQ.isEmpty, isTrue);
      expect(habitQ.isEmpty, isTrue);
      expect(moneyQ.isEmpty, isTrue);
    });

    test('TEST 6 & 7 — Offline / Write failure pauses logout and preserves local queues', () async {
      const uid = 'user_test_6';
      await HiveService().ensureUserBoxesOpened(uid);

      final taskRepo = TestTaskRepo(uid)..shouldFail = true;
      final habitRepo = TestHabitRepo(uid);
      final moneyRepo = TestMoneyRepo(uid);
      final settingsRepo = TestSettingsRepo(uid);

      await taskRepo.saveTask(createTask('t6_failed', 'Failed Task'));
      final taskQ = HiveService().getUserBox(HiveService.tasksSyncQueueBoxName, uid);
      expect(taskQ.length, 1);

      final syncService = SyncService(
        userId: uid,
        taskRepository: taskRepo,
        habitRepository: habitRepo,
        moneyRepository: moneyRepo,
        settingsRepository: settingsRepo,
      );

      final syncManager = SyncManager(userId: uid);
      final success = await syncManager.flushPendingChanges(syncService);

      expect(success, isFalse);
      expect(taskQ.length, 1); // Preserved in Hive!
      expect(syncManager.getLogoutSyncStatus(), LogoutSyncStatus.failed);
    });

    test('TEST 8 — Retry after failure succeeds without duplicate document writes', () async {
      const uid = 'user_test_8';
      await HiveService().ensureUserBoxesOpened(uid);

      final taskRepo = TestTaskRepo(uid)..shouldFail = true;
      final habitRepo = TestHabitRepo(uid);
      final moneyRepo = TestMoneyRepo(uid);
      final settingsRepo = TestSettingsRepo(uid);

      await taskRepo.saveTask(createTask('t8_task', 'Idempotent Task'));

      final syncService = SyncService(
        userId: uid,
        taskRepository: taskRepo,
        habitRepository: habitRepo,
        moneyRepository: moneyRepo,
        settingsRepository: settingsRepo,
      );

      final syncManager = SyncManager(userId: uid);

      // Attempt 1 (Fails)
      var success = await syncManager.flushPendingChanges(syncService);
      expect(success, isFalse);
      expect(taskRepo.writeCount, 0);

      // Network restored -> Attempt 2 (Retry)
      taskRepo.shouldFail = false;
      success = await syncManager.flushPendingChanges(syncService);
      expect(success, isTrue);
      expect(taskRepo.writeCount, 1); // Handled idempotently!
    });

    test('TEST 9 — Concurrency lock serializes background sync and logout flush without race condition', () async {
      const uid = 'user_test_9';
      await HiveService().ensureUserBoxesOpened(uid);

      final taskRepo = TestTaskRepo(uid);
      final habitRepo = TestHabitRepo(uid);
      final moneyRepo = TestMoneyRepo(uid);
      final settingsRepo = TestSettingsRepo(uid);

      final syncService = SyncService(
        userId: uid,
        taskRepository: taskRepo,
        habitRepository: habitRepo,
        moneyRepository: moneyRepo,
        settingsRepository: settingsRepo,
      );

      final syncManager = SyncManager(userId: uid);

      // Fire 2 sync operations concurrently
      final f1 = syncManager.flushPendingChanges(syncService);
      final f2 = syncManager.flushPendingChanges(syncService);

      final results = await Future.wait([f1, f2]);
      expect(results[0], isTrue);
      expect(results[1], isTrue);
    });

    test('TEST 10 — Synchronization complete status is distinct for logout vs background', () async {
      const uid = 'user_test_10';
      await HiveService().ensureUserBoxesOpened(uid);

      final syncManager = SyncManager(userId: uid);
      expect(syncManager.getLogoutSyncStatus(), LogoutSyncStatus.idle);
      expect(syncManager.getSyncStatus(), SyncStatus.idle);
    });

    test('TEST 11 & 12 — User isolation and post-logout user data isolation', () async {
      const uidA = 'user_isolation_A';
      const uidB = 'user_isolation_B';

      await HiveService().ensureUserBoxesOpened(uidA);
      final taskRepoA = TestTaskRepo(uidA);
      await taskRepoA.saveTask(createTask('task_A', 'Task A'));

      await HiveService().closeUserBoxes(uidA);

      await HiveService().ensureUserBoxesOpened(uidB);
      final taskRepoB = TestTaskRepo(uidB);
      expect(taskRepoB.getTasks().isEmpty, isTrue);
    });
  });
}
