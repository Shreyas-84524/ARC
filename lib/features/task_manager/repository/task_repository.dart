import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:hive/hive.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/task_manager/models/task_model.dart';

class TaskRepository {
  final String? _userId;
  final Box<Task> _taskBox;
  final Box _queueBox;
  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;

  TaskRepository({String? userId})
      : _userId = userId,
        _taskBox = HiveService().getUserBox<Task>(HiveService.tasksBoxName, userId),
        _queueBox = HiveService().getUserBox(HiveService.tasksSyncQueueBoxName, userId);

  String? get userId => _userId;

  fs.CollectionReference<Map<String, dynamic>> _tasksRef() {
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      return _firestore.collection('users').doc(uid).collection('tasks');
    }
    return _firestore.collection('tasks');
  }

  List<Task> getTasks() {
    return _taskBox.values.toList();
  }

  Future<void> saveTask(Task task) async {
    // 1. Save to local cache (Hive)
    await _taskBox.put(task.id, task);

    // 2. Try to sync to Firestore
    try {
      await _tasksRef().doc(task.id).set(task.toMap());
      await _queueBox.delete(task.id);
      debugPrint('Sync successful: task ${task.id} saved to Firestore.');
    } catch (e) {
      debugPrint('Sync queued for task ${task.id}. Error: $e');
      await _queueBox.put(task.id, {
        'id': task.id,
        'action': 'upsert',
        'timestamp': DateTime.now().toIso8601String(),
        'data': task.toMap(),
      });
    }
  }

  Future<void> deleteTask(String id) async {
    // 1. Delete from local cache
    await _taskBox.delete(id);

    // 2. Try to delete from Firestore
    try {
      await _tasksRef().doc(id).delete();
      await _queueBox.delete(id);
      debugPrint('Sync successful: task $id deleted from Firestore.');
    } catch (e) {
      debugPrint('Sync queued: deletion of task $id. Error: $e');
      await _queueBox.put(id, {
        'id': id,
        'action': 'delete',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> syncPending() async {
    if (_queueBox.isEmpty) return;

    debugPrint('TaskRepository: found ${_queueBox.length} pending sync actions.');
    final keys = List.from(_queueBox.keys);

    for (final key in keys) {
      final item = _queueBox.get(key);
      if (item == null) continue;

      final id = item['id'] as String?;
      final action = item['action'] as String?;

      if (id == null || action == null) {
        await _queueBox.delete(key);
        continue;
      }

      try {
        if (action == 'upsert') {
          final task = _taskBox.get(id);
          final payload = task?.toMap() ?? (item['data'] as Map<String, dynamic>?);
          if (payload != null) {
            await _tasksRef().doc(id).set(payload);
          }
        } else if (action == 'delete') {
          await _tasksRef().doc(id).delete();
        }
        await _queueBox.delete(key);
        debugPrint('Successfully synced pending action ($action) for task $id.');
      } catch (e) {
        debugPrint('Failed to sync pending action for task $id: $e');
        break; // Stop and retry later if network unavailable
      }
    }
  }

  Future<int> performEndOfDayCleanup({String? overrideDateStr}) async {
    final Box settingsBox = HiveService().getBox(HiveService.settingsBoxName);
    final todayStr = overrideDateStr ?? DateTime.now().toIso8601String().substring(0, 10);

    final lastCleanupDate = settingsBox.get('last_completed_tasks_cleanup_date');
    if (lastCleanupDate == todayStr) {
      debugPrint('End of day task cleanup already executed today ($todayStr). Skipping.');
      return 0;
    }

    final completedTasks = _taskBox.values.where((t) => t.completed).toList();
    int count = 0;
    for (final task in completedTasks) {
      await deleteTask(task.id);
      count++;
    }

    await settingsBox.put('last_completed_tasks_cleanup_date', todayStr);
    debugPrint('End of day task cleanup executed: $count completed tasks deleted.');
    return count;
  }
}
