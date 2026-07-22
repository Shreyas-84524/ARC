import 'package:flutter/foundation.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/settings/repository/settings_repository.dart';

class SyncService {
  final TaskRepository _taskRepository;
  final HabitRepository _habitRepository;
  final MoneyRepository _moneyRepository;
  final SettingsRepository _settingsRepository;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncService({
    required TaskRepository taskRepository,
    required HabitRepository habitRepository,
    required MoneyRepository moneyRepository,
    required SettingsRepository settingsRepository,
  })  : _taskRepository = taskRepository,
        _habitRepository = habitRepository,
        _moneyRepository = moneyRepository,
        _settingsRepository = settingsRepository;

  Future<void> syncAllPending() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      debugPrint('SyncService: Starting unified background synchronization...');
      await _taskRepository.syncPending();
      await _habitRepository.syncPending();
      await _moneyRepository.syncPending();
      await _settingsRepository.syncPending();
      debugPrint('SyncService: Unified background synchronization complete.');
    } catch (e) {
      debugPrint('SyncService warning during background sync: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
