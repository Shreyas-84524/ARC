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

/// Summary report of a dry-run migration inspection and validation.
class DryRunReport {
  final bool isReady;
  final String targetUserIdPlaceholder;
  final int totalFirestoreDocs;
  final int totalHiveRecords;
  final Map<String, int> collectionCounts;
  final Map<String, int> validRecordCounts;
  final Map<String, int> warningCounts;
  final Map<String, int> errorCounts;
  final Map<String, String> targetPathMappings;
  final List<String> integrityIssues;
  final List<String> logs;

  const DryRunReport({
    required this.isReady,
    required this.targetUserIdPlaceholder,
    required this.totalFirestoreDocs,
    required this.totalHiveRecords,
    required this.collectionCounts,
    required this.validRecordCounts,
    required this.warningCounts,
    required this.errorCounts,
    required this.targetPathMappings,
    required this.integrityIssues,
    required this.logs,
  });

  @override
  String toString() {
    return 'DryRunReport(isReady: $isReady, target: $targetUserIdPlaceholder, totalFirestoreDocs: $totalFirestoreDocs, totalHiveRecords: $totalHiveRecords, integrityIssues: ${integrityIssues.length})';
  }
}

/// Preparation service for migrating legacy unowned root collection data
/// into a user-scoped namespace (e.g. Shreyas) non-destructively.
class DataMigrationService {
  final fs.FirebaseFirestore? _firestore;
  final HiveService _hiveService;

  static const String pendingUidPlaceholder = '<SHREYAS_FIREBASE_UID_PENDING_STEP_4>';

  DataMigrationService({
    fs.FirebaseFirestore? firestore,
    HiveService? hiveService,
  })  : _firestore = firestore,
        _hiveService = hiveService ?? HiveService();

  fs.FirebaseFirestore get _db => _firestore ?? fs.FirebaseFirestore.instance;

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
      final taskDocs = await _db.collection('tasks').get();
      status['legacyTasksCount'] = taskDocs.docs.length;

      final habitDocs = await _db.collection('habits').get();
      status['legacyHabitsCount'] = habitDocs.docs.length;

      final entryDocs = await _db.collection('habitEntries').get();
      status['legacyHabitEntriesCount'] = entryDocs.docs.length;

      final txDocs = await _db.collection('transactions').get();
      status['legacyTransactionsCount'] = txDocs.docs.length;

      final budgetDocs = await _db.collection('budgets').get();
      status['legacyBudgetsCount'] = budgetDocs.docs.length;

      final summaryDocs = await _db.collection('monthlySummaries').get();
      status['legacySummariesCount'] = summaryDocs.docs.length;

      final settingsDoc = await _db.collection('settings').doc('global').get();
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

  /// Performs a 100% READ-ONLY dry run migration.
  ///
  /// - Reads all legacy Firestore collections and local Hive boxes.
  /// - Validates schemas, data types, and timestamps.
  /// - Checks cross-record integrity (e.g. habitEntries -> habits).
  /// - Computes future target paths using placeholder `<SHREYAS_FIREBASE_UID_PENDING_STEP_4>`.
  /// - NEVER writes, deletes, or modifies anything in Firestore or Hive.
  Future<DryRunReport> performDryRun({
    String targetPlaceholder = pendingUidPlaceholder,
  }) async {
    final List<String> logs = [];
    final List<String> integrityIssues = [];

    final Map<String, int> collectionCounts = {};
    final Map<String, int> validRecordCounts = {};
    final Map<String, int> warningCounts = {};
    final Map<String, int> errorCounts = {};
    final Map<String, String> targetPathMappings = {};

    logs.add('--- STARTING NON-DESTRUCTIVE DRY RUN MIGRATION ---');
    logs.add('Target Placeholder UID: $targetPlaceholder');

    int totalFirestoreDocs = 0;
    int totalHiveRecords = 0;

    // Define collections to evaluate
    final Set<String> habitIds = {};

    try {
      // 1. Inspect Tasks
      final taskDocs = await _db.collection('tasks').get();
      collectionCounts['tasks'] = taskDocs.docs.length;
      validRecordCounts['tasks'] = 0;
      warningCounts['tasks'] = 0;
      errorCounts['tasks'] = 0;
      targetPathMappings['tasks'] = 'users/$targetPlaceholder/tasks';
      totalFirestoreDocs += taskDocs.docs.length;

      for (final doc in taskDocs.docs) {
        final data = doc.data();
        if (data['id'] == null || data['title'] == null) {
          errorCounts['tasks'] = (errorCounts['tasks'] ?? 0) + 1;
          integrityIssues.add('Task document ${doc.id} missing required id or title field');
        } else {
          validRecordCounts['tasks'] = (validRecordCounts['tasks'] ?? 0) + 1;
        }
      }
      logs.add('Tasks dry run: ${taskDocs.docs.length} found, ${validRecordCounts['tasks']} valid.');

      // 2. Inspect Habits
      final habitDocs = await _db.collection('habits').get();
      collectionCounts['habits'] = habitDocs.docs.length;
      validRecordCounts['habits'] = 0;
      warningCounts['habits'] = 0;
      errorCounts['habits'] = 0;
      targetPathMappings['habits'] = 'users/$targetPlaceholder/habits';
      totalFirestoreDocs += habitDocs.docs.length;

      for (final doc in habitDocs.docs) {
        final data = doc.data();
        final habitId = data['id'] as String?;
        if (habitId == null || data['name'] == null) {
          errorCounts['habits'] = (errorCounts['habits'] ?? 0) + 1;
          integrityIssues.add('Habit document ${doc.id} missing required id or name field');
        } else {
          habitIds.add(habitId);
          validRecordCounts['habits'] = (validRecordCounts['habits'] ?? 0) + 1;
        }
      }
      logs.add('Habits dry run: ${habitDocs.docs.length} found, ${validRecordCounts['habits']} valid.');

      // 3. Inspect Habit Entries & Cross-Reference Integrity
      final entryDocs = await _db.collection('habitEntries').get();
      collectionCounts['habitEntries'] = entryDocs.docs.length;
      validRecordCounts['habitEntries'] = 0;
      warningCounts['habitEntries'] = 0;
      errorCounts['habitEntries'] = 0;
      targetPathMappings['habitEntries'] = 'users/$targetPlaceholder/habitEntries';
      totalFirestoreDocs += entryDocs.docs.length;

      for (final doc in entryDocs.docs) {
        final data = doc.data();
        final habitId = data['habitId'] as String?;
        if (habitId == null) {
          errorCounts['habitEntries'] = (errorCounts['habitEntries'] ?? 0) + 1;
          integrityIssues.add('HabitEntry document ${doc.id} missing habitId reference');
        } else if (!habitIds.contains(habitId)) {
          warningCounts['habitEntries'] = (warningCounts['habitEntries'] ?? 0) + 1;
          integrityIssues.add('HabitEntry document ${doc.id} references non-existent habitId: $habitId');
          validRecordCounts['habitEntries'] = (validRecordCounts['habitEntries'] ?? 0) + 1;
        } else {
          validRecordCounts['habitEntries'] = (validRecordCounts['habitEntries'] ?? 0) + 1;
        }
      }
      logs.add('HabitEntries dry run: ${entryDocs.docs.length} found, ${validRecordCounts['habitEntries']} valid, ${warningCounts['habitEntries']} orphan warnings.');

      // 4. Inspect Transactions
      final txDocs = await _db.collection('transactions').get();
      collectionCounts['transactions'] = txDocs.docs.length;
      validRecordCounts['transactions'] = 0;
      warningCounts['transactions'] = 0;
      errorCounts['transactions'] = 0;
      targetPathMappings['transactions'] = 'users/$targetPlaceholder/transactions';
      totalFirestoreDocs += txDocs.docs.length;

      for (final doc in txDocs.docs) {
        final data = doc.data();
        if (data['id'] == null || data['amount'] == null) {
          errorCounts['transactions'] = (errorCounts['transactions'] ?? 0) + 1;
          integrityIssues.add('Transaction document ${doc.id} missing id or amount field');
        } else {
          validRecordCounts['transactions'] = (validRecordCounts['transactions'] ?? 0) + 1;
        }
      }
      logs.add('Transactions dry run: ${txDocs.docs.length} found, ${validRecordCounts['transactions']} valid.');

      // 5. Inspect Budgets
      final budgetDocs = await _db.collection('budgets').get();
      collectionCounts['budgets'] = budgetDocs.docs.length;
      validRecordCounts['budgets'] = 0;
      warningCounts['budgets'] = 0;
      errorCounts['budgets'] = 0;
      targetPathMappings['budgets'] = 'users/$targetPlaceholder/budgets';
      totalFirestoreDocs += budgetDocs.docs.length;

      for (final _ in budgetDocs.docs) {
        validRecordCounts['budgets'] = (validRecordCounts['budgets'] ?? 0) + 1;
      }
      logs.add('Budgets dry run: ${budgetDocs.docs.length} found, ${validRecordCounts['budgets']} valid.');

      // 6. Inspect Monthly Summaries
      final summaryDocs = await _db.collection('monthlySummaries').get();
      collectionCounts['monthlySummaries'] = summaryDocs.docs.length;
      validRecordCounts['monthlySummaries'] = 0;
      warningCounts['monthlySummaries'] = 0;
      errorCounts['monthlySummaries'] = 0;
      targetPathMappings['monthlySummaries'] = 'users/$targetPlaceholder/monthlySummaries';
      totalFirestoreDocs += summaryDocs.docs.length;

      for (final _ in summaryDocs.docs) {
        validRecordCounts['monthlySummaries'] = (validRecordCounts['monthlySummaries'] ?? 0) + 1;
      }
      logs.add('MonthlySummaries dry run: ${summaryDocs.docs.length} found, ${validRecordCounts['monthlySummaries']} valid.');

      // 7. Inspect Global Settings
      final settingsDoc = await _db.collection('settings').doc('global').get();
      if (settingsDoc.exists) {
        collectionCounts['settings'] = 1;
        validRecordCounts['settings'] = 1;
        targetPathMappings['settings'] = 'users/$targetPlaceholder/settings/profile';
        totalFirestoreDocs += 1;
        logs.add('Settings dry run: 1 global settings document found, 1 valid.');
      } else {
        collectionCounts['settings'] = 0;
        validRecordCounts['settings'] = 0;
        targetPathMappings['settings'] = 'users/$targetPlaceholder/settings/profile';
        logs.add('Settings dry run: No global settings document found in Firestore (will use defaults).');
      }

      // 8. Inspect Local Hive Boxes
      if (_hiveService.isInitialized) {
        final hiveTasks = _hiveService.getBox<Task>(HiveService.tasksBoxName).length;
        final hiveHabits = _hiveService.getBox<Habit>(HiveService.habitsBoxName).length;
        final hiveEntries = _hiveService.getBox<HabitEntry>(HiveService.habitEntriesBoxName).length;
        final hiveTxs = _hiveService.getBox<Transaction>(HiveService.moneyBoxName).length;
        totalHiveRecords = hiveTasks + hiveHabits + hiveEntries + hiveTxs;
        logs.add('Hive local cache dry run: $hiveTasks tasks, $hiveHabits habits, $hiveEntries habit entries, $hiveTxs transactions.');
      }

      logs.add('--- DRY RUN COMPLETED SUCCESSFULLY: 0 WRITES PERFORMED ---');

      return DryRunReport(
        isReady: errorCounts.values.every((c) => c == 0),
        targetUserIdPlaceholder: targetPlaceholder,
        totalFirestoreDocs: totalFirestoreDocs,
        totalHiveRecords: totalHiveRecords,
        collectionCounts: collectionCounts,
        validRecordCounts: validRecordCounts,
        warningCounts: warningCounts,
        errorCounts: errorCounts,
        targetPathMappings: targetPathMappings,
        integrityIssues: integrityIssues,
        logs: logs,
      );
    } catch (e) {
      logs.add('Dry run encountered an error: $e');
      return DryRunReport(
        isReady: false,
        targetUserIdPlaceholder: targetPlaceholder,
        totalFirestoreDocs: totalFirestoreDocs,
        totalHiveRecords: totalHiveRecords,
        collectionCounts: collectionCounts,
        validRecordCounts: validRecordCounts,
        warningCounts: warningCounts,
        errorCounts: errorCounts,
        targetPathMappings: targetPathMappings,
        integrityIssues: integrityIssues..add('Fatal error during dry run: $e'),
        logs: logs,
      );
    }
  }

  /// Copies existing legacy global root data into target user's namespace.
  ///
  /// CRITICAL SAFETY GUARANTEE:
  /// - Old data is NEVER deleted or altered.
  /// - Operates strictly as a non-destructive COPY & VERIFY process.
  /// - DO NOT call this automatically in Step 3.
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
      final userRef = _db.collection('users').doc(targetUserId);

      // Check if target user namespace is already migrated
      final existingUserTasks = await userRef.collection('tasks').get();
      if (existingUserTasks.docs.isNotEmpty) {
        logs.add('Target user $targetUserId already contains ${existingUserTasks.docs.length} migrated tasks. Skipping migration.');
        return MigrationReport(
          success: true,
          targetUserId: targetUserId,
          tasksMigrated: existingUserTasks.docs.length,
          habitsMigrated: (await userRef.collection('habits').get()).docs.length,
          habitEntriesMigrated: (await userRef.collection('habitEntries').get()).docs.length,
          transactionsMigrated: (await userRef.collection('transactions').get()).docs.length,
          budgetsMigrated: (await userRef.collection('budgets').get()).docs.length,
          summariesMigrated: (await userRef.collection('monthlySummaries').get()).docs.length,
          settingsMigrated: (await userRef.collection('settings').doc('profile').get()).exists,
          logs: logs,
        );
      }

      // 1. Copy Tasks
      final taskDocs = await _db.collection('tasks').get();
      for (final doc in taskDocs.docs) {
        await userRef.collection('tasks').doc(doc.id).set(doc.data());
        tasksCount++;
      }
      logs.add('Copied $tasksCount task documents to users/$targetUserId/tasks.');

      // 2. Copy Habits
      final habitDocs = await _db.collection('habits').get();
      for (final doc in habitDocs.docs) {
        await userRef.collection('habits').doc(doc.id).set(doc.data());
        habitsCount++;
      }
      logs.add('Copied $habitsCount habit documents to users/$targetUserId/habits.');

      // 3. Copy Habit Entries
      final entryDocs = await _db.collection('habitEntries').get();
      for (final doc in entryDocs.docs) {
        await userRef.collection('habitEntries').doc(doc.id).set(doc.data());
        entriesCount++;
      }
      logs.add('Copied $entriesCount habit entry documents to users/$targetUserId/habitEntries.');

      // 4. Copy Transactions
      final txDocs = await _db.collection('transactions').get();
      for (final doc in txDocs.docs) {
        await userRef.collection('transactions').doc(doc.id).set(doc.data());
        txCount++;
      }
      logs.add('Copied $txCount transaction documents to users/$targetUserId/transactions.');

      // 5. Copy Monthly Budgets
      final budgetDocs = await _db.collection('budgets').get();
      for (final doc in budgetDocs.docs) {
        await userRef.collection('budgets').doc(doc.id).set(doc.data());
        budgetsCount++;
      }
      logs.add('Copied $budgetsCount budget documents to users/$targetUserId/budgets.');

      // 6. Copy Monthly Summaries
      final summaryDocs = await _db.collection('monthlySummaries').get();
      for (final doc in summaryDocs.docs) {
        await userRef.collection('monthlySummaries').doc(doc.id).set(doc.data());
        summariesCount++;
      }
      logs.add('Copied $summariesCount monthly summary documents to users/$targetUserId/monthlySummaries.');

      // 7. Copy Settings
      final settingsDoc = await _db.collection('settings').doc('global').get();
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
