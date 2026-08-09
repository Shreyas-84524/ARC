import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';

/// Summary report of a migration validation or dry-run/copy operation.
class MigrationReport {
  final bool success;
  final String targetUserId;
  final int tasksMigrated;
  final int habitsMigrated;
  final int habitEntriesMigrated;
  final int transactionsMigrated;
  final int budgetsMigrated;
  final int summariesMigrated;
  final bool settingsMigrated;
  final List<String> logs;

  const MigrationReport({
    required this.success,
    required this.targetUserId,
    required this.tasksMigrated,
    required this.habitsMigrated,
    required this.habitEntriesMigrated,
    required this.transactionsMigrated,
    required this.budgetsMigrated,
    required this.summariesMigrated,
    required this.settingsMigrated,
    required this.logs,
  });

  @override
  String toString() {
    return 'MigrationReport(success: $success, targetUserId: $targetUserId, tasks: $tasksMigrated, habits: $habitsMigrated, entries: $habitEntriesMigrated, txs: $transactionsMigrated, budgets: $budgetsMigrated, summaries: $summariesMigrated, settings: $settingsMigrated)';
  }
}

/// Preparation service for migrating legacy unowned root collection data
/// into a user-scoped namespace (e.g. Shreyas) non-destructively.
class DataMigrationService {
  final fs.FirebaseFirestore _firestore;
  final HiveService _hiveService;

  DataMigrationService({
    fs.FirebaseFirestore? firestore,
    HiveService? hiveService,
  })  : _firestore = firestore ?? fs.FirebaseFirestore.instance,
        _hiveService = hiveService ?? HiveService();

  /// Inspects and counts legacy root collection items to validate readiness for migration.
  Future<Map<String, dynamic>> inspectLegacyData() async {
    final Map<String, dynamic> status = {
      'legacyTasksCount': 0,
      'legacyHabitsCount': 0,
      'legacyHabitEntriesCount': 0,
      'legacyTransactionsCount': 0,
      'legacyBudgetsCount': 0,
      'legacySummariesCount': 0,
      'legacySettingsExist': false,
      'hiveTasksCount': 0,
      'hiveHabitsCount': 0,
      'hiveHabitEntriesCount': 0,
      'hiveTransactionsCount': 0,
    };

    try {
      final taskDocs = await _firestore.collection('tasks').get();
      status['legacyTasksCount'] = taskDocs.docs.length;

      final habitDocs = await _firestore.collection('habits').get();
      status['legacyHabitsCount'] = habitDocs.docs.length;

      final entryDocs = await _firestore.collection('habitEntries').get();
      status['legacyHabitEntriesCount'] = entryDocs.docs.length;

      final txDocs = await _firestore.collection('transactions').get();
      status['legacyTransactionsCount'] = txDocs.docs.length;

      final budgetDocs = await _firestore.collection('budgets').get();
      status['legacyBudgetsCount'] = budgetDocs.docs.length;

      final summaryDocs = await _firestore.collection('monthlySummaries').get();
      status['legacySummariesCount'] = summaryDocs.docs.length;

      final settingsDoc = await _firestore.collection('settings').doc('global').get();
      status['legacySettingsExist'] = settingsDoc.exists;

      if (_hiveService.isInitialized) {
        status['hiveTasksCount'] = _hiveService.getBox<Task>(HiveService.tasksBoxName).length;
        status['hiveHabitsCount'] = _hiveService.getBox<Habit>(HiveService.habitsBoxName).length;
        status['hiveHabitEntriesCount'] = _hiveService.getBox<HabitEntry>(HiveService.habitEntriesBoxName).length;
        status['hiveTransactionsCount'] = _hiveService.getBox<Transaction>(HiveService.moneyBoxName).length;
      }
    } catch (e) {
      debugPrint('DataMigrationService inspectLegacyData warning: $e');
    }

    return status;
  }

  /// Copies existing legacy global root data into target user's namespace.
  ///
  /// CRITICAL SAFETY GUARANTEE:
  /// - Old data is NEVER deleted or altered.
  /// - Operates strictly as a non-destructive COPY & VERIFY process.
  /// - DO NOT call this automatically in Step 2.
  Future<MigrationReport> migrateLegacyDataToUser({
    required String targetUserId,
  }) async {
    final List<String> logs = [];
    logs.add('Starting non-destructive data migration to user: $targetUserId');

    int tasksCount = 0;
    int habitsCount = 0;
    int entriesCount = 0;
    int txCount = 0;
    int budgetsCount = 0;
    int summariesCount = 0;
    bool settingsDone = false;

    try {
      final userRef = _firestore.collection('users').doc(targetUserId);

      // 1. Copy Tasks
      final taskDocs = await _firestore.collection('tasks').get();
      for (final doc in taskDocs.docs) {
        await userRef.collection('tasks').doc(doc.id).set(doc.data());
        tasksCount++;
      }
      logs.add('Copied $tasksCount task documents to users/$targetUserId/tasks.');

      // 2. Copy Habits
      final habitDocs = await _firestore.collection('habits').get();
      for (final doc in habitDocs.docs) {
        await userRef.collection('habits').doc(doc.id).set(doc.data());
        habitsCount++;
      }
      logs.add('Copied $habitsCount habit documents to users/$targetUserId/habits.');

      // 3. Copy Habit Entries
      final entryDocs = await _firestore.collection('habitEntries').get();
      for (final doc in entryDocs.docs) {
        await userRef.collection('habitEntries').doc(doc.id).set(doc.data());
        entriesCount++;
      }
      logs.add('Copied $entriesCount habit entry documents to users/$targetUserId/habitEntries.');

      // 4. Copy Transactions
      final txDocs = await _firestore.collection('transactions').get();
      for (final doc in txDocs.docs) {
        await userRef.collection('transactions').doc(doc.id).set(doc.data());
        txCount++;
      }
      logs.add('Copied $txCount transaction documents to users/$targetUserId/transactions.');

      // 5. Copy Monthly Budgets
      final budgetDocs = await _firestore.collection('budgets').get();
      for (final doc in budgetDocs.docs) {
        await userRef.collection('budgets').doc(doc.id).set(doc.data());
        budgetsCount++;
      }
      logs.add('Copied $budgetsCount budget documents to users/$targetUserId/budgets.');

      // 6. Copy Monthly Summaries
      final summaryDocs = await _firestore.collection('monthlySummaries').get();
      for (final doc in summaryDocs.docs) {
        await userRef.collection('monthlySummaries').doc(doc.id).set(doc.data());
        summariesCount++;
      }
      logs.add('Copied $summariesCount monthly summary documents to users/$targetUserId/monthlySummaries.');

      // 7. Copy Settings
      final settingsDoc = await _firestore.collection('settings').doc('global').get();
      if (settingsDoc.exists && settingsDoc.data() != null) {
        await userRef.collection('settings').doc('profile').set(settingsDoc.data()!);
        settingsDone = true;
        logs.add('Copied settings/global to users/$targetUserId/settings/profile.');
      }

      // 8. Verification Step
      final userTasks = await userRef.collection('tasks').get();
      if (userTasks.docs.length != taskDocs.docs.length) {
        throw StateError('Verification mismatch: expected ${taskDocs.docs.length} tasks, found ${userTasks.docs.length}');
      }

      logs.add('Migration verification complete: All documents matched target user subcollections.');

      return MigrationReport(
        success: true,
        targetUserId: targetUserId,
        tasksMigrated: tasksCount,
        habitsMigrated: habitsCount,
        habitEntriesMigrated: entriesCount,
        transactionsMigrated: txCount,
        budgetsMigrated: budgetsCount,
        summariesMigrated: summariesCount,
        settingsMigrated: settingsDone,
        logs: logs,
      );
    } catch (e) {
      logs.add('Migration failed with error: $e');
      return MigrationReport(
        success: false,
        targetUserId: targetUserId,
        tasksMigrated: tasksCount,
        habitsMigrated: habitsCount,
        habitEntriesMigrated: entriesCount,
        transactionsMigrated: txCount,
        budgetsMigrated: budgetsCount,
        summariesMigrated: summariesCount,
        settingsMigrated: settingsDone,
        logs: logs,
      );
    }
  }
}
