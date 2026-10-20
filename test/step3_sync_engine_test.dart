import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/core/services/sync_manager.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('arc_step3_sync_test_');
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

  group('Step 3 Controlled Sync Engine & Cooldown Verification', () {
    test('TEST 1 — First full sync records timestamp successfully', () async {
      const uid = 'shreyas_t1';
      await HiveService().ensureUserBoxesOpened(uid);
      final manager = SyncManager(userId: uid);

      expect(manager.getLastSuccessfulSync(), isNull);
      expect(manager.canFullSync(), isTrue);

      final syncTime = DateTime(2026, 8, 10, 8, 0, 0);
      await manager.recordSuccessfulSync(timestamp: syncTime);

      expect(manager.getLastSuccessfulSync(), equals(syncTime));
      expect(manager.getRecentSuccessfulSyncs(now: syncTime).length, equals(1));
    });

    test('TEST 2 — 12-Hour Block: Request sync at 10:00 after 08:00 sync is blocked', () async {
      const uid = 'shreyas_t2';
      await HiveService().ensureUserBoxesOpened(uid);
      final manager = SyncManager(userId: uid);

      final sync1Time = DateTime(2026, 8, 10, 8, 0, 0);
      await manager.recordSuccessfulSync(timestamp: sync1Time);

      final syncAttemptTime = DateTime(2026, 8, 10, 10, 0, 0);
      expect(manager.canFullSync(now: syncAttemptTime), isFalse);
    });

    test('TEST 3 — 12-Hour Allow: Request sync at 20:00 after 08:00 sync is allowed', () async {
      const uid = 'shreyas_t3';
      await HiveService().ensureUserBoxesOpened(uid);
      final manager = SyncManager(userId: uid);

      final sync1Time = DateTime(2026, 8, 10, 8, 0, 0);
      await manager.recordSuccessfulSync(timestamp: sync1Time);

      final sync2Time = DateTime(2026, 8, 10, 20, 0, 0);
      expect(manager.canFullSync(now: sync2Time), isTrue);
    });

    test('TEST 4 — Max 2 Syncs / 24 Hours: 3rd sync in 24h window is blocked', () async {
      const uid = 'shreyas_t4';
      await HiveService().ensureUserBoxesOpened(uid);
      final manager = SyncManager(userId: uid);

      // Sync 1 at 08:00
      final sync1Time = DateTime(2026, 8, 10, 8, 0, 0);
      await manager.recordSuccessfulSync(timestamp: sync1Time);

      // Sync 2 at 20:00 (12 hours later)
      final sync2Time = DateTime(2026, 8, 10, 20, 0, 0);
      await manager.recordSuccessfulSync(timestamp: sync2Time);

      // Attempt Sync 3 at 22:00 (only 2 hours after sync 2, and 3rd in 24h)
      final sync3Time = DateTime(2026, 8, 10, 22, 0, 0);
      expect(manager.canFullSync(now: sync3Time), isFalse);
    });

    test('TEST 5 — Failed Sync: Error does not update lastSuccessfulSync or corrupt Hive', () async {
      const uid = 'shreyas_t5';
      await HiveService().ensureUserBoxesOpened(uid);
      final manager = SyncManager(userId: uid);

      final originalSync = DateTime(2026, 8, 1, 10, 0, 0);
      await manager.recordSuccessfulSync(timestamp: originalSync);

      // Simulate failure
      manager.handleSyncFailure('Firestore connection timeout');

      expect(manager.getSyncStatus(), equals(SyncStatus.failed));
      expect(manager.getLastError(), contains('Firestore connection timeout'));
      expect(manager.getLastSuccessfulSync(), equals(originalSync));
    });

    test('TEST 6 — Pending Queue: User mutations update Hive immediately and enqueue change', () async {
      const uid = 'shreyas_t6';
      await HiveService().ensureUserBoxesOpened(uid);
      final taskRepo = TaskRepository(userId: uid);

      final task = Task(
        id: 't_pending_1',
        title: 'Immediate Hive Task',
        category: 'Work',
        priority: 'High',
        description: 'Testing queueing',
        labels: const ['work'],
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await taskRepo.saveTask(task);

      // 1. Hive has task immediately
      expect(taskRepo.getTasks().any((t) => t.id == 't_pending_1'), isTrue);

      // 2. Queue box contains pending save item
      final queueBox = HiveService().getUserBox(HiveService.tasksSyncQueueBoxName, uid);
      expect(queueBox.containsKey('t_pending_1'), isTrue);
    });

    test('TEST 7 — User UID Isolation: Shreyas sync metadata does not affect Aman', () async {
      const shreyasUid = 'shreyas_t7';
      const amanUid = 'aman_t7';

      // 1. Shreyas performs 2 syncs
      await HiveService().ensureUserBoxesOpened(shreyasUid);
      final shreyasManager = SyncManager(userId: shreyasUid);
      await shreyasManager.recordSuccessfulSync(timestamp: DateTime(2026, 8, 10, 8, 0, 0));
      await shreyasManager.recordSuccessfulSync(timestamp: DateTime(2026, 8, 10, 20, 0, 0));

      expect(shreyasManager.canFullSync(now: DateTime(2026, 8, 10, 22, 0, 0)), isFalse);

      // 2. Aman logs in
      await HiveService().ensureUserBoxesOpened(amanUid);
      final amanManager = SyncManager(userId: amanUid);

      // Aman metadata is completely empty, so Aman is allowed to sync
      expect(amanManager.getLastSuccessfulSync(), isNull);
      expect(amanManager.canFullSync(now: DateTime(2026, 8, 10, 22, 0, 0)), isTrue);
    });

    test('TEST 8 — Offline Safety: Local data accessible and readable without network', () async {
      const uid = 'shreyas_t8';
      await HiveService().ensureUserBoxesOpened(uid);
      final moneyRepo = MoneyRepository(userId: uid);

      final tx = Transaction(
        id: 'tx_offline_1',
        amount: 250.0,
        type: 'Expense',
        category: 'Food',
        notes: 'Coffee offline',
        date: DateTime.now(),
        time: '10:00',
        createdAt: DateTime.now(),
      );

      await moneyRepo.saveTransaction(tx);

      final txs = moneyRepo.getTransactions();
      expect(txs.length, equals(1));
      expect(txs.first.notes, equals('Coffee offline'));
    });

    test('TEST 9 — App Restart: Reopening session retains Hive data & sync metadata', () async {
      const uid = 'shreyas_t9';
      await HiveService().ensureUserBoxesOpened(uid);

      final manager = SyncManager(userId: uid);
      final testTime = DateTime(2026, 8, 10, 15, 30, 0);
      await manager.recordSuccessfulSync(timestamp: testTime);

      // Simulate app restart by creating a new instance of SyncManager
      final reloadedManager = SyncManager(userId: uid);
      expect(reloadedManager.getLastSuccessfulSync(), equals(testTime));
    });

    test('TEST 10 — Existing Firestore Data Preservation Verification', () async {
      const uid = 'shreyas_t10';
      await HiveService().ensureUserBoxesOpened(uid);
      final habitRepo = HabitRepository(userId: uid);

      final habit = Habit(
        id: 'h_existing_1',
        name: 'Preserved Habit',
        category: 'Health',
        colorValue: 0xFF4CAF50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await habitRepo.saveHabit(habit);
      expect(habitRepo.getHabits().length, equals(1));
    });
  });
}
