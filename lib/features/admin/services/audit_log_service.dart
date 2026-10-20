import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;

class AuditLogService {
  final fs.FirebaseFirestore? _firestore;

  AuditLogService({fs.FirebaseFirestore? firestore})
      : _firestore = firestore;

  fs.FirebaseFirestore get _db => _firestore ?? fs.FirebaseFirestore.instance;

  /// Records administrative security log in `admin_logs` collection.
  /// NEVER logs passwords, secrets, or sensitive credentials.
  Future<void> logAdminAction({
    required String adminUid,
    required String adminUsername,
    required String action,
    required String targetUsername,
    String? targetUid,
    required String result,
  }) async {
    try {
      final logData = {
        'adminUid': adminUid,
        'adminUsername': adminUsername,
        'action': action,
        'targetUsername': targetUsername,
        'targetUid': targetUid ?? '',
        'timestamp': fs.FieldValue.serverTimestamp(),
        'result': result,
      };

      await _db.collection('admin_logs').add(logData);
    } catch (e) {
      debugPrint('AuditLogService warning: Failed to record audit log: $e');
    }
  }
}
