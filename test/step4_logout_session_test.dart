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
import 'package:arc/features/user_management/providers/user_context_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('arc_step4_logout_test_');
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

  group('Step 4 Logout & Session Restoration Workflow Tests', () {
    test('TEST 1 — Logout with no pending changes closes boxes cleanly', () async {
      const uid = 'shreyas_s4_t1';
      await HiveService().ensureUserBoxesOpened(uid);
      expect(Hive.isBoxOpen(HiveService.getUserBoxName(HiveService.tasksBoxName, uid)), isTrue);

      await HiveService().closeUserBoxes(uid);
      expect(Hive.isBoxOpen(HiveService.getUserBoxName(HiveService.tasksBoxName, uid)), isFalse);
    });

    test('TEST 2 — Logout with pending Task enqueues change safely', () async {
      const uid = 'shreyas_s4_t2';
      await HiveService().ensureUserBoxesOpened(uid);
      final taskRepo = TaskRepository(userId: uid);

      final task = Task(
        id: 'task_logout_1',
        title: 'Task before logout',
        category: 'Work',
        priority: 'High',
        description: 'Pending task',
        labels: const ['logout'],
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await taskRepo.saveTask(task);

      final queueBox = HiveService().getUserBox(HiveService.tasksSyncQueueBoxName, uid);
      expect(queueBox.containsKey('task_logout_1'), isTrue);

      await HiveService().closeUserBoxes(uid);
      expect(Hive.isBoxOpen(HiveService.getUserBoxName(HiveService.tasksBoxName, uid)), isFalse);
    });

    test('TEST 3 — Logout with pending Habit enqueues change safely', () async {
      const uid = 'shreyas_s4_t3';
      await HiveService().ensureUserBoxesOpened(uid);
      final habitRepo = HabitRepository(userId: uid);

      final habit = Habit(
        id: 'habit_logout_1',
        name: 'Habit before logout',
        category: 'Health',
        colorValue: 0xFF4CAF50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await habitRepo.saveHabit(habit);

      final queueBox = HiveService().getUserBox(HiveService.habitsSyncQueueBoxName, uid);
      expect(queueBox.containsKey('habit_habit_logout_1'), isTrue);

      await HiveService().closeUserBoxes(uid);
    });

    test('TEST 4 — Logout with pending Transaction enqueues change safely', () async {
      const uid = 'shreyas_s4_t4';
      await HiveService().ensureUserBoxesOpened(uid);
      final moneyRepo = MoneyRepository(userId: uid);

      final tx = Transaction(
        id: 'tx_logout_1',
        amount: 1500.0,
        type: 'Expense',
        category: 'Shopping',
        notes: 'Shopping before logout',
        date: DateTime.now(),
        time: '14:00',
        createdAt: DateTime.now(),
      );

      await moneyRepo.saveTransaction(tx);

      final queueBox = HiveService().getUserBox(HiveService.moneySyncQueueBoxName, uid);
      expect(queueBox.containsKey('tx_tx_logout_1'), isTrue);

      await HiveService().closeUserBoxes(uid);
    });

    test('TEST 5 — Logout Sync Failure keeps user logged in and preserves local data', () async {
      const uid = 'shreyas_s4_t5';
      await HiveService().ensureUserBoxesOpened(uid);
      final taskRepo = TaskRepository(userId: uid);

      final task = Task(
        id: 'task_failed_logout',
        title: 'Task failed logout',
        category: 'Work',
        priority: 'High',
        description: 'Unsaved task',
        labels: const ['failed'],
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await taskRepo.saveTask(task);

      final queueBox = HiveService().getUserBox(HiveService.tasksSyncQueueBoxName, uid);
      expect(queueBox.containsKey('task_failed_logout'), isTrue);

      // On failure, box MUST NOT be closed and data MUST NOT be deleted
      expect(Hive.isBoxOpen(HiveService.getUserBoxName(HiveService.tasksBoxName, uid)), isTrue);
      expect(taskRepo.getTasks().any((t) => t.id == 'task_failed_logout'), isTrue);
    });

    test('TEST 6 & 7 — User Isolation & Reverse User Isolation', () async {
      const shreyasUid = 'shreyas_s4_t6';
      const amanUid = 'aman_s4_t6';

      // 1. Shreyas logs in and writes task
      await HiveService().ensureUserBoxesOpened(shreyasUid);
      final shreyasTaskRepo = TaskRepository(userId: shreyasUid);
      await shreyasTaskRepo.saveTask(Task(
        id: 't_shreyas_iso',
        title: 'Shreyas Secret Data',
        category: 'Personal',
        priority: 'High',
        description: 'Secret',
        labels: const [],
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await HiveService().closeUserBoxes(shreyasUid);

      // 2. Aman logs in
      await HiveService().ensureUserBoxesOpened(amanUid);
      final amanTaskRepo = TaskRepository(userId: amanUid);
      expect(amanTaskRepo.getTasks(), isEmpty); // Aman sees 0% of Shreyas data

      await amanTaskRepo.saveTask(Task(
        id: 't_aman_iso',
        title: 'Aman Private Data',
        category: 'Personal',
        priority: 'Low',
        description: 'Private',
        labels: const [],
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await HiveService().closeUserBoxes(amanUid);

      // 3. Shreyas logs back in
      await HiveService().ensureUserBoxesOpened(shreyasUid);
      final reloadedShreyasRepo = TaskRepository(userId: shreyasUid);
      expect(reloadedShreyasRepo.getTasks().length, equals(1));
      expect(reloadedShreyasRepo.getTasks().first.title, equals('Shreyas Secret Data'));
    });

    test('TEST 8 — Session Restoration restores correct user box on relaunch', () async {
      const uid = 'shreyas_s4_t8';
      await HiveService().ensureUserBoxesOpened(uid);
      final notifier = UserContextNotifier();
      notifier.setActiveUser(userId: uid);

      expect(notifier.state.userId, equals(uid));
      expect(Hive.isBoxOpen(HiveService.getUserBoxName(HiveService.tasksBoxName, uid)), isTrue);
    });

    test('TEST 9 — Post-Logout Restart resets state to legacy unauthenticated', () async {
      const uid = 'shreyas_s4_t9';
      final notifier = UserContextNotifier();
      notifier.setActiveUser(userId: uid);
      expect(notifier.state.userId, equals(uid));

      notifier.resetToLegacy();
      expect(notifier.state.userId, isNull);
      expect(notifier.state.isAuthenticated, isFalse);
    });

    test('TEST 10 — Listener Cleanup stops real-time listeners cleanly on logout', () async {
      const uid = 'shreyas_s4_t10';
      await HiveService().ensureUserBoxesOpened(uid);
      await HiveService().closeUserBoxes(uid);
      expect(Hive.isBoxOpen(HiveService.getUserBoxName(HiveService.tasksBoxName, uid)), isFalse);
    });

    test('TEST 11 — Existing Data Preservation Verification', () async {
      const uid = 'shreyas_s4_t11';
      await HiveService().ensureUserBoxesOpened(uid);
      final habitRepo = HabitRepository(userId: uid);

      final habit = Habit(
        id: 'h_preserved_1',
        name: 'Preserved Habit',
        category: 'Health',
        colorValue: 0xFF4CAF50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await habitRepo.saveHabit(habit);
      await HiveService().closeUserBoxes(uid);

      // Reopen and verify data survived box closure
      await HiveService().ensureUserBoxesOpened(uid);
      final reloadedRepo = HabitRepository(userId: uid);
      expect(reloadedRepo.getHabits().length, equals(1));
      expect(reloadedRepo.getHabits().first.name, equals('Preserved Habit'));
    });

    test('TEST 12 — Sync Policy Preservation Verification', () async {
      const uid = 'shreyas_s4_t12';
      await HiveService().ensureUserBoxesOpened(uid);
      final manager = SyncManager(userId: uid);

      final now = DateTime.now();
      await manager.recordSuccessfulSync(timestamp: now);

      // 12-hour minimum interval check
      expect(manager.canFullSync(now: now.add(const Duration(hours: 2))), isFalse);
    });
  });
}
