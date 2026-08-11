import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:hive/hive.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';

class HabitRepository {
  final String? _userId;
  final Box<Habit> _habitBox;
  final Box<HabitEntry> _entryBox;
  final Box _queueBox;
  final fs.FirebaseFirestore? _firestore;

  HabitRepository({String? userId, fs.FirebaseFirestore? firestore})
      : _userId = userId,
        _habitBox = HiveService().getUserBox<Habit>(HiveService.habitsBoxName, userId),
        _entryBox = HiveService().getUserBox<HabitEntry>(HiveService.habitEntriesBoxName, userId),
        _queueBox = HiveService().getUserBox(HiveService.habitsSyncQueueBoxName, userId),
        _firestore = firestore;

  fs.FirebaseFirestore get _db => _firestore ?? fs.FirebaseFirestore.instance;

  String? get userId => _userId;

  fs.CollectionReference<Map<String, dynamic>> _habitsRef() {
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      return _db.collection('users').doc(uid).collection('habits');
    }
    return _db.collection('habits');
  }

  fs.CollectionReference<Map<String, dynamic>> _entriesRef() {
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      return _db.collection('users').doc(uid).collection('habitEntries');
    }
    return _db.collection('habitEntries');
  }

  List<Habit> getHabits() => _habitBox.values.toList();

  List<HabitEntry> getEntries() => _entryBox.values.toList();

  Future<void> saveHabit(Habit habit) async {
    await _habitBox.put(habit.id, habit);
    try {
      await _habitsRef().doc(habit.id).set(habit.toMap());
      await _queueBox.delete('habit_${habit.id}');
    } catch (e) {
      await _queueBox.put('habit_${habit.id}', {
        'id': habit.id,
        'type': 'habit',
        'action': 'upsert',
        'data': habit.toMap(),
      });
    }
  }

  Future<void> deleteHabit(String id) async {
    await _habitBox.delete(id);

    // Delete associated entries locally
    final entriesToDelete =
        _entryBox.values.where((e) => e.habitId == id).toList();
    for (final entry in entriesToDelete) {
      await _entryBox.delete(entry.id);
    }

    try {
      await _habitsRef().doc(id).delete();
      await _queueBox.delete('habit_$id');
    } catch (e) {
      await _queueBox.put('habit_$id', {
        'id': id,
        'type': 'habit',
        'action': 'delete',
      });
    }
  }

  Future<void> toggleEntry(String habitId, String dateStr, bool completed) async {
    final entryId = '${habitId}_$dateStr';
    final entry = HabitEntry(
      id: entryId,
      habitId: habitId,
      dateStr: dateStr,
      completed: completed,
    );

    if (completed) {
      await _entryBox.put(entryId, entry);
      try {
        await _entriesRef()
            .doc(entryId)
            .set(entry.toMap());
        await _queueBox.delete('entry_$entryId');
      } catch (e) {
        await _queueBox.put('entry_$entryId', {
          'id': entryId,
          'type': 'entry',
          'action': 'upsert',
          'data': entry.toMap(),
        });
      }
    } else {
      await _entryBox.delete(entryId);
      try {
        await _entriesRef().doc(entryId).delete();
        await _queueBox.delete('entry_$entryId');
      } catch (e) {
        await _queueBox.put('entry_$entryId', {
          'id': entryId,
          'type': 'entry',
          'action': 'delete',
        });
      }
    }
  }

  Future<void> syncPending() async {
    if (_queueBox.isEmpty) return;

    final keys = List.from(_queueBox.keys);
    for (final key in keys) {
      final item = _queueBox.get(key);
      if (item == null) continue;

      final id = item['id'] as String?;
      final type = item['type'] as String?;
      final action = item['action'] as String?;

      if (id == null || type == null || action == null) {
        await _queueBox.delete(key);
        continue;
      }

      try {
        if (type == 'habit') {
          if (action == 'upsert') {
            final habit = _habitBox.get(id);
            final payload =
                habit?.toMap() ?? (item['data'] as Map<String, dynamic>?);
            if (payload != null) {
              await _habitsRef().doc(id).set(payload);
            }
          } else if (action == 'delete') {
            await _habitsRef().doc(id).delete();
          }
        } else if (type == 'entry') {
          if (action == 'upsert') {
            final entry = _entryBox.get(id);
            final payload =
                entry?.toMap() ?? (item['data'] as Map<String, dynamic>?);
            if (payload != null) {
              await _entriesRef().doc(id).set(payload);
            }
          } else if (action == 'delete') {
            await _entriesRef().doc(id).delete();
          }
        }
        await _queueBox.delete(key);
      } catch (e) {
        debugPrint('Failed to sync habit queue item $key: $e');
        break; // Stop and retry later if network fails again
      }
    }
  }
}
