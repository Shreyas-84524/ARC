import 'package:flutter/foundation.dart';
import 'package:arc/core/services/hive_service.dart';

/// Local deduplication service ensuring no duplicate transactions are processed.
///
/// RULES:
/// - If a [referenceId] is present, duplicate check prioritizes it.
/// - If [referenceId] is absent, uses the deterministic [fingerprint].
/// - Scoped to the active user to ensure complete multi-user isolation.
/// - Maintains an in-memory working cache backed by local Hive persistence.
class MoneyDeduplicationService {
  final HiveService _hiveService;
  final bool inMemoryOnly;
  static final Map<String, List<String>> _inMemoryFpsStorage = {};
  static final Map<String, List<String>> _inMemoryRefsStorage = {};

  final Set<String> _processedFingerprints = <String>{};
  final Set<String> _processedReferenceIds = <String>{};
  String? _currentUserId;

  MoneyDeduplicationService({HiveService? hiveService, this.inMemoryOnly = false})
      : _hiveService = hiveService ?? HiveService();

  @visibleForTesting
  static void resetInMemoryStorage() {
    _inMemoryFpsStorage.clear();
    _inMemoryRefsStorage.clear();
  }

  @visibleForTesting
  Set<String> get processedFingerprints => Set.unmodifiable(_processedFingerprints);

  @visibleForTesting
  Set<String> get processedReferenceIds => Set.unmodifiable(_processedReferenceIds);

  /// Initializes deduplication cache for the current user.
  void initForUser(String? userId) {
    _currentUserId = userId;
    _processedFingerprints.clear();
    _processedReferenceIds.clear();

    if (userId == null || userId.isEmpty) return;

    if (inMemoryOnly) {
      final fps = _inMemoryFpsStorage[userId];
      if (fps != null) _processedFingerprints.addAll(fps);
      final refs = _inMemoryRefsStorage[userId];
      if (refs != null) _processedReferenceIds.addAll(refs);
      return;
    }

    try {
      if (_hiveService.isInitialized) {
        final box = _hiveService.getBox(HiveService.moneyAutomationPreferencesBoxName);
        final storedFps = box.get('${userId}_dedup_fingerprints');
        if (storedFps is List) {
          _processedFingerprints.addAll(storedFps.map((e) => e.toString()));
        }
        final storedRefs = box.get('${userId}_dedup_refs');
        if (storedRefs is List) {
          _processedReferenceIds.addAll(storedRefs.map((e) => e.toString().toUpperCase().trim()));
        }
      }
    } catch (_) {
      // Gracefully continue with in-memory set if box is not yet opened
    }
  }

  /// Checks if the transaction has already been processed.
  bool isDuplicate(String fingerprint, {String? referenceId}) {
    if (referenceId != null && referenceId.trim().isNotEmpty) {
      final normalizedRef = referenceId.trim().toUpperCase();
      if (_processedReferenceIds.contains(normalizedRef)) {
        return true;
      }
    }
    return _processedFingerprints.contains(fingerprint);
  }

  /// Records the transaction fingerprint and reference ID as processed.
  Future<void> recordProcessed(String fingerprint, {String? referenceId}) async {
    _processedFingerprints.add(fingerprint);
    if (referenceId != null && referenceId.trim().isNotEmpty) {
      _processedReferenceIds.add(referenceId.trim().toUpperCase());
    }

    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    if (inMemoryOnly) {
      _inMemoryFpsStorage[userId] = _processedFingerprints.toList();
      _inMemoryRefsStorage[userId] = _processedReferenceIds.toList();
      return;
    }

    try {
      if (_hiveService.isInitialized) {
        final box = _hiveService.getBox(HiveService.moneyAutomationPreferencesBoxName);
        final fpsList = _processedFingerprints.toList();
        final trimmedFps = fpsList.length > 500 ? fpsList.sublist(fpsList.length - 500) : fpsList;
        await box.put('${userId}_dedup_fingerprints', trimmedFps);

        final refsList = _processedReferenceIds.toList();
        final trimmedRefs = refsList.length > 500 ? refsList.sublist(refsList.length - 500) : refsList;
        await box.put('${userId}_dedup_refs', trimmedRefs);
      }
    } catch (_) {
      // In-memory sets remain functional
    }
  }

  /// Clears in-memory sets upon user logout.
  void clear() {
    _processedFingerprints.clear();
    _processedReferenceIds.clear();
    _currentUserId = null;
  }
}
