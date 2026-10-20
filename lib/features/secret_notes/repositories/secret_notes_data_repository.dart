import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/secret_notes/models/secret_note.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// - NO Firestore collections for notes
// - NO sync queues
// - NO realtime listeners
// - NO Firebase repositories
// - NO uploading note titles, descriptions, or metadata
// - NO attachment to ARC cloud sync
// All note data is strictly persisted in isolated local device storage.

class SecretNotesDataRepository {
  static const String dataBoxName = HiveService.secretNotesDataBoxName;

  final bool inMemoryOnly;
  Box<dynamic>? _dataBox;
  final Map<String, Map<String, dynamic>> _inMemoryStore = {};
  bool _isInitialized = false;

  SecretNotesDataRepository({this.inMemoryOnly = false, Box<dynamic>? dataBox})
      : _dataBox = dataBox;

  Future<void> init() async {
    if (_isInitialized) return;
    if (inMemoryOnly) {
      _isInitialized = true;
      return;
    }

    try {
      final isHiveReady =
          HiveService().isInitialized || Hive.isBoxOpen(dataBoxName);
      if (!isHiveReady) {
        _isInitialized = true;
        return;
      }

      if (_dataBox == null) {
        if (Hive.isBoxOpen(dataBoxName)) {
          _dataBox = Hive.box(dataBoxName);
        } else {
          _dataBox = await Hive.openBox(dataBoxName);
        }
      }

      _isInitialized = true;
      debugPrint('Secret Notes: data namespace successfully initialized.');
    } catch (e) {
      debugPrint(
          'Secret Notes: data storage initialization warning, operating with memory fallback: $e');
      _isInitialized = true;
    }
  }

  /// Retrieves all secret notes sorted by updatedAt descending.
  Future<List<SecretNote>> getNotes() async {
    await init();

    final List<SecretNote> notes = [];

    try {
      if (!inMemoryOnly && _dataBox != null && _dataBox!.isOpen) {
        for (final key in _dataBox!.keys) {
          try {
            final raw = _dataBox!.get(key);
            if (raw is Map) {
              notes.add(SecretNote.fromMap(raw));
            }
          } catch (e) {
            // Isolate individual corrupted record without breaking other notes
            debugPrint('Secret Notes: skipped corrupted record during load: $e');
          }
        }
      } else {
        for (final map in _inMemoryStore.values) {
          try {
            notes.add(SecretNote.fromMap(map));
          } catch (e) {
            debugPrint('Secret Notes: skipped corrupted memory record: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Secret Notes: error reading notes list: $e');
    }

    // Sort by updatedAt descending (most recently created or edited note first)
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  /// Retrieves a specific note by ID.
  Future<SecretNote?> getNoteById(String id) async {
    await init();

    try {
      if (!inMemoryOnly && _dataBox != null && _dataBox!.isOpen) {
        final raw = _dataBox!.get(id);
        if (raw is Map) {
          return SecretNote.fromMap(raw);
        }
      } else {
        final raw = _inMemoryStore[id];
        if (raw != null) {
          return SecretNote.fromMap(raw);
        }
      }
    } catch (e) {
      debugPrint('Secret Notes: error retrieving note by id: $e');
    }
    return null;
  }

  /// Persists a note locally (insert or update).
  Future<void> saveNote(SecretNote note) async {
    await init();

    try {
      final map = note.toMap();
      if (!inMemoryOnly && _dataBox != null && _dataBox!.isOpen) {
        await _dataBox!.put(note.id, map);
      } else {
        _inMemoryStore[note.id] = map;
      }
    } catch (e) {
      debugPrint('Secret Notes: failed to save note locally, fallback to memory: $e');
      _inMemoryStore[note.id] = note.toMap();
    }
  }

  /// Permanently removes a note by ID.
  Future<void> deleteNote(String id) async {
    await init();

    try {
      if (!inMemoryOnly && _dataBox != null && _dataBox!.isOpen) {
        await _dataBox!.delete(id);
      } else {
        _inMemoryStore.remove(id);
      }
    } catch (e) {
      debugPrint('Secret Notes: error deleting note: $e');
      _inMemoryStore.remove(id);
    }
  }

  /// Clears all notes from local store (for testing or full reset).
  Future<void> clearAll() async {
    try {
      if (_dataBox != null && _dataBox!.isOpen) {
        await _dataBox!.clear();
      }
    } catch (_) {}
    _inMemoryStore.clear();
  }
}
