import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';

class HabitRepository {
  final Box<Habit> _habitBox = HiveService().getBox(HiveService.habitsBoxName) as Box<Habit>;
  final Box<HabitEntry> _entryBox = HiveService().getBox(HiveService.habitEntriesBoxName) as Box<HabitEntry>;
  final Box _queueBox = HiveService().getBox(HiveService.habitsSyncQueueBoxName);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Habit> getHabits() => _habitBox.values.toList();

  List<HabitEntry> getEntries() => _entryBox.values.toList();

  Future<void> saveHabit(Habit habit) async {
    await _habitBox.put(habit.id, habit);
    try {
      await _firestore.collection('habits').doc(habit.id).set(habit.toMap());
      await _queueBox.delete('habit_${habit.id}');
    } catch (e) {
      await _queueBox.put('habit_${habit.id}', {
        'id': habit.id,
        'type': 'habit',
        'action': 'upsert',
      });
    }
  }

  Future<void> deleteHabit(String id) async {
    await _habitBox.delete(id);
    
    // Delete associated entries locally
    final entriesToDelete = _entryBox.values.where((e) => e.habitId == id).toList();
    for (final entry in entriesToDelete) {
      await _entryBox.delete(entry.id);
    }

    try {
      await _firestore.collection('habits').doc(id).delete();
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
        await _firestore.collection('habitEntries').doc(entryId).set(entry.toMap());
        await _queueBox.delete('entry_$entryId');
      } catch (e) {
        await _queueBox.put('entry_$entryId', {
          'id': entryId,
          'type': 'entry',
          'action': 'upsert',
        });
      }
    } else {
      await _entryBox.delete(entryId);
      try {
        await _firestore.collection('habitEntries').doc(entryId).delete();
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

      final id = item['id'] as String;
      final type = item['type'] as String;
      final action = item['action'] as String;

      try {
        if (type == 'habit') {
          if (action == 'upsert') {
            final habit = _habitBox.get(id);
            if (habit != null) {
              await _firestore.collection('habits').doc(id).set(habit.toMap());
            }
          } else if (action == 'delete') {
            await _firestore.collection('habits').doc(id).delete();
          }
        } else if (type == 'entry') {
          if (action == 'upsert') {
            final entry = _entryBox.get(id);
            if (entry != null) {
              await _firestore.collection('habitEntries').doc(id).set(entry.toMap());
            }
          } else if (action == 'delete') {
            await _firestore.collection('habitEntries').doc(id).delete();
          }
        }
        await _queueBox.delete(key);
      } catch (e) {
        debugPrint('Failed to sync queue item $key: $e');
        break; // Stop and retry later if network fails again
      }
    }
  }
}
