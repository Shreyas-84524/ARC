import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service responsible for preserving unfinished feedback forms locally as drafts.
class FeedbackDraftService {
  final SharedPreferences? _prefs;

  FeedbackDraftService({
    SharedPreferences? prefs,
  }) : _prefs = prefs;

  static const String _prefix = 'arc_feedback_draft_';

  String _getKey(String category) => '$_prefix$category';

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs;
    return await SharedPreferences.getInstance();
  }

  /// Saves form fields locally as a draft for the given [category].
  /// Optionally supports [extraFields] for specialized category screens.
  Future<void> saveDraft({
    required String category,
    required String module,
    required String message,
    int? rating,
    String? contactEmail,
    Map<String, dynamic>? extraFields,
  }) async {
    final hasExtraContent = extraFields != null &&
        extraFields.values.any((v) => v != null && v.toString().trim().isNotEmpty);

    // Don't save empty drafts
    if (message.trim().isEmpty &&
        (contactEmail == null || contactEmail.trim().isEmpty) &&
        rating == null &&
        !hasExtraContent) {
      await clearDraft(category);
      return;
    }

    final data = <String, dynamic>{
      'category': category,
      'module': module,
      'message': message,
      'rating': rating,
      'contactEmail': contactEmail,
      'savedAt': DateTime.now().toIso8601String(),
    };
    if (extraFields != null) {
      data['extraFields'] = extraFields;
    }

    final prefs = await _getPrefs();
    await prefs.setString(_getKey(category), jsonEncode(data));
  }

  /// Retrieves the saved draft for [category], or null if none exists.
  Future<Map<String, dynamic>?> loadDraft(String category) async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(_getKey(category));
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Clear corrupt draft
      await clearDraft(category);
    }
    return null;
  }

  /// Clears the saved draft for [category] upon successful submission.
  Future<void> clearDraft(String category) async {
    final prefs = await _getPrefs();
    await prefs.remove(_getKey(category));
  }

  /// Checks if a draft exists for [category].
  Future<bool> hasDraft(String category) async {
    final prefs = await _getPrefs();
    return prefs.containsKey(_getKey(category));
  }
}

/// Riverpod provider for [FeedbackDraftService].
final feedbackDraftServiceProvider = Provider<FeedbackDraftService>((ref) {
  return FeedbackDraftService();
});
