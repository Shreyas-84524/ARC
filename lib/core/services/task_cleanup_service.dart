import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';

/// TaskCleanupService schedules and executes the 11:59 PM auto cleanup of completed tasks.
class TaskCleanupService {
  static final TaskCleanupService _instance = TaskCleanupService._internal();
  factory TaskCleanupService() => _instance;
  TaskCleanupService._internal();

  Timer? _timer;
  TaskRepository? _taskRepository;
  void Function()? _onCleanupCallback;

  void init(TaskRepository taskRepository, {void Function()? onCleanup}) {
    _taskRepository = taskRepository;
    _onCleanupCallback = onCleanup;
    _scheduleDailyCleanup();
    _checkMissedCleanup();
  }

  void _scheduleDailyCleanup() {
    _timer?.cancel();
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    final now = DateTime.now();
    // Schedule for 11:59:00 PM local time today
    var target = DateTime(now.year, now.month, now.day, 23, 59, 0);

    if (now.isAfter(target)) {
      // If 11:59 PM for today has already passed, schedule for tomorrow 11:59 PM
      target = target.add(const Duration(days: 1));
    }

    final duration = target.difference(now);
    debugPrint('TaskCleanupService: Next auto cleanup scheduled in ${duration.inMinutes} minutes at $target.');

    _timer = Timer(duration, () async {
      await runCleanup();
      _scheduleDailyCleanup(); // Reschedule for next day
    });
  }

  Future<int> runCleanup() async {
    if (_taskRepository == null) return 0;
    final count = await _taskRepository!.performEndOfDayCleanup();
    if (count > 0 && _onCleanupCallback != null) {
      _onCleanupCallback!();
    }
    return count;
  }

  void _checkMissedCleanup() {
    final now = DateTime.now();
    if (now.hour == 23 && now.minute >= 59) {
      runCleanup();
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
