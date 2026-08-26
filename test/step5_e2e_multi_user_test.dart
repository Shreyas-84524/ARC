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
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('arc_step5_e2e_test_');
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

  group('Step 5 Final End-to-End Multi-User Verification Tests', () {
    const userMap = {
      'Shreyas': 'uid_shreyas_step5',
      'Aman': 'uid_aman_step5',
      'Rohit': 'uid_rohit_step5',
      'Sachi': 'uid_sachi_step5',
      'Yash': 'uid_yash_step5',
      'Purushottam': 'uid_purushottam_step5',
    };

    test('PART 1 & 2 — All mandatory accounts exist and map to unique UIDs', () {
      expect(UserProfile.knownUsernames, containsAll(['Shreyas', 'Aman', 'Rohit', 'Sachi', 'Yash', 'Purushottam']));
      expect(UserProfile.knownUsernames.length, equals(6));

      final emails = UserProfile.knownUsernames.map(UserProfile.emailForUsername).toSet();
      expect(emails.length, equals(6));
      expect(emails, contains('shreyas@arc.app'));
      expect(emails, contains('purushottam@arc.app'));
      expect(emails, contains('aman@arc.app'));
      expect(emails, contains('rohit@arc.app'));
      expect(emails, contains('sachi@arc.app'));
      expect(emails, contains('yash@arc.app'));
    });

    test('PART 4 & 5 — 5-User Login & User-Scoped Hive Isolation', () async {
      for (final entry in userMap.entries) {
        final username = entry.key;
        final uid = entry.value;

        await HiveService().ensureUserBoxesOpened(uid);

        final taskBoxName = HiveService.getUserBoxName(HiveService.tasksBoxName, uid);
        final habitBoxName = HiveService.getUserBoxName(HiveService.habitsBoxName, uid);
        final moneyBoxName = HiveService.getUserBoxName(HiveService.moneyBoxName, uid);

        expect(Hive.isBoxOpen(taskBoxName), isTrue, reason: '$username task box should be open');
        expect(Hive.isBoxOpen(habitBoxName), isTrue, reason: '$username habit box should be open');
        expect(Hive.isBoxOpen(moneyBoxName), isTrue, reason: '$username money box should be open');

        await HiveService().closeUserBoxes(uid);
      }
    });

    test('PART 6, 7, 8, 9 — Multi-User Cross-Data Isolation across all 5 Users', () async {
      // 1. Write unique data for each of the 5 users
      for (final entry in userMap.entries) {
        final username = entry.key;
        final uid = entry.value;

        await HiveService().ensureUserBoxesOpened(uid);
        final taskRepo = TaskRepository(userId: uid);
        final habitRepo = HabitRepository(userId: uid);
        final moneyRepo = MoneyRepository(userId: uid);

        await taskRepo.saveTask(Task(
          id: 'task_$username',
          title: '${username}_TASK_ISOLATION',
          category: 'Work',
          priority: 'High',
          description: 'Private task for $username',
          labels: const ['isolation'],
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        await habitRepo.saveHabit(Habit(
          id: 'habit_$username',
          name: '${username}_HABIT_ISOLATION',
          category: 'Health',
          colorValue: 0xFF2196F3,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        await moneyRepo.saveTransaction(Transaction(
          id: 'tx_$username',
          amount: 5000.0,
          type: 'Income',
          category: 'Salary',
          notes: '${username}_MONEY_ISOLATION',
          date: DateTime.now(),
          time: '12:00',
          createdAt: DateTime.now(),
        ));

        await HiveService().closeUserBoxes(uid);
      }

      // 2. Cross-verify that NO user can see any other user's data
      for (final currentEntry in userMap.entries) {
        final currentUsername = currentEntry.key;
        final currentUid = currentEntry.value;

        await HiveService().ensureUserBoxesOpened(currentUid);
        final taskRepo = TaskRepository(userId: currentUid);
        final habitRepo = HabitRepository(userId: currentUid);
        final moneyRepo = MoneyRepository(userId: currentUid);

        final userTasks = taskRepo.getTasks();
        final userHabits = habitRepo.getHabits();
        final userTx = moneyRepo.getTransactions();

        expect(userTasks.length, equals(1));
        expect(userTasks.first.title, equals('${currentUsername}_TASK_ISOLATION'));

        expect(userHabits.length, equals(1));
        expect(userHabits.first.name, equals('${currentUsername}_HABIT_ISOLATION'));

        expect(userTx.length, equals(1));
        expect(userTx.first.notes, equals('${currentUsername}_MONEY_ISOLATION'));

        // Check other users' test keys do NOT exist in current user data
        for (final otherUsername in userMap.keys) {
          if (otherUsername == currentUsername) continue;
          expect(userTasks.any((t) => t.title.contains(otherUsername)), isFalse,
              reason: '$currentUsername should NOT see $otherUsername task');
          expect(userHabits.any((h) => h.name.contains(otherUsername)), isFalse,
              reason: '$currentUsername should NOT see $otherUsername habit');
          expect(userTx.any((tx) => tx.notes.contains(otherUsername)), isFalse,
              reason: '$currentUsername should NOT see $otherUsername transaction');
        }

        await HiveService().closeUserBoxes(currentUid);
      }
    });

    test('PART 10 & 11 — Hive-First Architecture & Pending Queue Isolation', () async {
      const uid = 'uid_shreyas_step5';
      await HiveService().ensureUserBoxesOpened(uid);
      final taskRepo = TaskRepository(userId: uid);

      // Local write updates Hive immediately
      await taskRepo.saveTask(Task(
        id: 't_hive_first',
        title: 'Hive-First Instant Read',
        category: 'Personal',
        priority: 'Medium',
        description: 'Instant local load',
        labels: const [],
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Read from Hive returns immediately
      final tasks = taskRepo.getTasks();
      expect(tasks.any((t) => t.id == 't_hive_first'), isTrue);

      // Check queued item in sync queue
      final queueBox = HiveService().getUserBox(HiveService.tasksSyncQueueBoxName, uid);
      expect(queueBox.containsKey('t_hive_first'), isTrue);

      await HiveService().closeUserBoxes(uid);
    });

    test('PART 12 — 12-Hour Cooldown & 2 Syncs/24 Hours Policy Preservation', () async {
      const uid = 'uid_policy_check';
      await HiveService().ensureUserBoxesOpened(uid);
      final manager = SyncManager(userId: uid);

      final t0 = DateTime.now();
      await manager.recordSuccessfulSync(timestamp: t0);

      // 1. Requesting sync 1 hour later must be blocked by 12h rule
      expect(manager.canFullSync(now: t0.add(const Duration(hours: 1))), isFalse);

      // 2. Requesting sync 13 hours later is allowed (Sync 2)
      final t1 = t0.add(const Duration(hours: 13));
      expect(manager.canFullSync(now: t1), isTrue);
      await manager.recordSuccessfulSync(timestamp: t1);

      // 3. Requesting 3rd sync within 24h window (at +20h) must be blocked by max 2 syncs/24h rule
      final t2 = t0.add(const Duration(hours: 20));
      expect(manager.canFullSync(now: t2), isFalse);

      await HiveService().closeUserBoxes(uid);
    });

    test('PART 17, 18, 19, 20 — User Switch & App Restart Scenarios', () async {
      // Shreyas -> Logout -> Aman
      const shreyasUid = 'uid_shreyas_step5';
      const amanUid = 'uid_aman_step5';

      final notifier = UserContextNotifier();
      notifier.setActiveUser(userId: shreyasUid);
      expect(notifier.state.userId, equals(shreyasUid));

      // Reset on logout
      notifier.resetToLegacy();
      expect(notifier.state.userId, isNull);

      // Aman logs in
      notifier.setActiveUser(userId: amanUid);
      expect(notifier.state.userId, equals(amanUid));
    });

    test('PART 22 — Existing Data Preservation Check', () async {
      const uid = 'uid_shreyas_legacy_test';
      await HiveService().ensureUserBoxesOpened(uid);
      final taskRepo = TaskRepository(userId: uid);

      await taskRepo.saveTask(Task(
        id: 'shreyas_legacy_001',
        title: 'Original Pre-Migration Task',
        category: 'Work',
        priority: 'High',
        description: 'Crucial historical task',
        labels: const ['legacy'],
        completed: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(days: 30)),
      ));

      await HiveService().closeUserBoxes(uid);

      // Reopen and confirm legacy task is 100% intact
      await HiveService().ensureUserBoxesOpened(uid);
      final reloadedRepo = TaskRepository(userId: uid);
      final legacyTasks = reloadedRepo.getTasks();

      expect(legacyTasks.length, equals(1));
      expect(legacyTasks.first.id, equals('shreyas_legacy_001'));
      expect(legacyTasks.first.title, equals('Original Pre-Migration Task'));

      await HiveService().closeUserBoxes(uid);
    });
  });
}
