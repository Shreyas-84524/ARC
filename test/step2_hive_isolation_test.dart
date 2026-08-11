import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:arc/core/services/hive_service.dart';
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
    tempDir = await Directory.systemTemp.createTemp('arc_hive_isolation_test_');
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

  group('Step 2 Hive User Isolation & Local Cache Verification', () {
    const shreyasUid = 'shreyas_test_uid_101';
    const amanUid = 'aman_test_uid_202';

    test('Shreyas and Aman receive completely isolated Hive boxes', () async {
      // 1. Initialize Shreyas user boxes
      await HiveService().ensureUserBoxesOpened(shreyasUid);
      final shreyasTaskRepo = TaskRepository(userId: shreyasUid);
      final shreyasHabitRepo = HabitRepository(userId: shreyasUid);
      final shreyasMoneyRepo = MoneyRepository(userId: shreyasUid);

      // 2. Add Shreyas data
      final shreyasTask = Task(
        id: 'task_shreyas_1',
        title: 'Shreyas Secret Project Task',
        category: 'Work',
        priority: 'High',
        description: 'Secret Task Description',
        labels: const ['work'],
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final shreyasHabit = Habit(
        id: 'habit_shreyas_1',
        name: 'Shreyas Morning Meditation',
        category: 'Health',
        colorValue: 0xFF4CAF50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final shreyasTx = Transaction(
        id: 'tx_shreyas_1',
        amount: 5000.0,
        type: 'Income',
        category: 'Salary',
        notes: 'Monthly Salary',
        date: DateTime.now(),
        time: '09:00',
        createdAt: DateTime.now(),
      );

      await shreyasTaskRepo.saveTask(shreyasTask);
      await shreyasHabitRepo.saveHabit(shreyasHabit);
      await shreyasMoneyRepo.saveTransaction(shreyasTx);

      // Verify Shreyas local Hive data
      expect(shreyasTaskRepo.getTasks().length, equals(1));
      expect(shreyasTaskRepo.getTasks().first.title, equals('Shreyas Secret Project Task'));
      expect(shreyasHabitRepo.getHabits().length, equals(1));
      expect(shreyasMoneyRepo.getTransactions().length, equals(1));

      // 3. Initialize Aman user boxes (Simulating logout & login as Aman)
      await HiveService().ensureUserBoxesOpened(amanUid);
      final amanTaskRepo = TaskRepository(userId: amanUid);
      final amanHabitRepo = HabitRepository(userId: amanUid);
      final amanMoneyRepo = MoneyRepository(userId: amanUid);

      // 4. Verify Aman sees 0 records of Shreyas
      expect(amanTaskRepo.getTasks(), isEmpty);
      expect(amanHabitRepo.getHabits(), isEmpty);
      expect(amanMoneyRepo.getTransactions(), isEmpty);

      // 5. Add Aman data
      final amanTask = Task(
        id: 'task_aman_1',
        title: 'Aman Workout Task',
        category: 'Personal',
        priority: 'Medium',
        description: 'Gym Session',
        labels: const ['fitness'],
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await amanTaskRepo.saveTask(amanTask);

      // Verify Aman has only Aman task
      expect(amanTaskRepo.getTasks().length, equals(1));
      expect(amanTaskRepo.getTasks().first.title, equals('Aman Workout Task'));

      // 6. Switch back to Shreyas and confirm Shreyas data remains untouched
      expect(shreyasTaskRepo.getTasks().length, equals(1));
      expect(shreyasTaskRepo.getTasks().first.title, equals('Shreyas Secret Project Task'));
    });
  });
}
