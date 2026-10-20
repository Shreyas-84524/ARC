import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/admin/services/audit_log_service.dart';
import 'package:arc/core/services/hive_service.dart';

class AdminService {
  final fs.FirebaseFirestore? _firestore;
  final AuditLogService _auditLogService;

  // In-memory registered users store for active runtime & test execution
  final List<UserProfile> _registeredUsers = [];

  AdminService({
    auth.FirebaseAuth? firebaseAuth,
    fs.FirebaseFirestore? firestore,
    AuditLogService? auditLogService,
  })  : _firestore = firestore,
        _auditLogService = auditLogService ?? AuditLogService(firestore: firestore) {
    _initializeDefaultUsers();
  }

  void _initializeDefaultUsers() {
    final now = DateTime.now();
    for (final username in UserProfile.knownUsernames) {
      if (username.toUpperCase() == 'ADMIN') continue;
      _registeredUsers.add(UserProfile(
        id: 'uid_${username.toLowerCase()}',
        username: username,
        displayName: username,
        email: UserProfile.emailForUsername(username),
        role: 'user',
        createdAt: now,
      ));
    }
  }

  /// Fetches list of all non-admin Project Arc users.
  Future<List<UserProfile>> fetchUserList(UserContext adminContext) async {
    _verifyAdminAuth(adminContext);
    return List.unmodifiable(_registeredUsers);
  }

  /// Admin operation to create a new normal user account.
  /// Does NOT return or accept passwords.
  Future<UserProfile> createUser({
    required String username,
    required UserContext adminContext,
  }) async {
    _verifyAdminAuth(adminContext);

    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) {
      throw ArgumentError('Username cannot be empty.');
    }

    final RegExp validUsernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
    if (!validUsernameRegex.hasMatch(cleanUsername)) {
      throw ArgumentError(
          'Username must be 3-20 characters long and contain only letters, numbers, or underscores.');
    }

    // Check duplicate username case-insensitively
    final isDuplicate = _registeredUsers.any(
      (u) => u.username.toLowerCase() == cleanUsername.toLowerCase(),
    );
    if (isDuplicate || cleanUsername.toUpperCase() == 'ADMIN') {
      throw ArgumentError('User "$cleanUsername" already exists.');
    }

    final uid = 'uid_${cleanUsername.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
    final email = UserProfile.emailForUsername(cleanUsername);
    final now = DateTime.now();

    final newProfile = UserProfile(
      id: uid,
      username: cleanUsername,
      displayName: cleanUsername,
      email: email,
      role: 'user',
      createdAt: now,
    );

    _registeredUsers.add(newProfile);

    // Save metadata in Firestore
    try {
      final firestore = _firestore ?? fs.FirebaseFirestore.instance;
      await firestore.collection('users').doc(uid).collection('settings').doc('profile').set(newProfile.toMap());
    } catch (e) {
      debugPrint('AdminService Firestore profile creation notice: $e');
    }

    // Record Audit Log
    await _auditLogService.logAdminAction(
      adminUid: adminContext.userId ?? 'ADMIN',
      adminUsername: adminContext.profile?.username ?? 'ADMIN',
      action: 'CREATE_USER',
      targetUsername: cleanUsername,
      targetUid: uid,
      result: 'SUCCESS',
    );

    return newProfile;
  }

  /// Admin operation to delete an existing user account.
  Future<void> deleteUser({
    required String username,
    required UserContext adminContext,
  }) async {
    _verifyAdminAuth(adminContext);

    final cleanUsername = username.trim();
    if (cleanUsername.toUpperCase() == 'ADMIN') {
      throw ArgumentError('Cannot delete the primary administrative account.');
    }

    final index = _registeredUsers.indexWhere(
      (u) => u.username.toLowerCase() == cleanUsername.toLowerCase(),
    );

    if (index == -1) {
      throw ArgumentError('User "$cleanUsername" not found.');
    }

    final targetUser = _registeredUsers[index];
    _registeredUsers.removeAt(index);

    // Close and clean up user-scoped local Hive storage
    try {
      await HiveService().closeUserBoxes(targetUser.id);
    } catch (e) {
      debugPrint('AdminService Hive cleanup warning: $e');
    }

    // Record Audit Log
    await _auditLogService.logAdminAction(
      adminUid: adminContext.userId ?? 'ADMIN',
      adminUsername: adminContext.profile?.username ?? 'ADMIN',
      action: 'DELETE_USER',
      targetUsername: cleanUsername,
      targetUid: targetUser.id,
      result: 'SUCCESS',
    );
  }

  void _verifyAdminAuth(UserContext context) {
    if (!context.isAuthenticated || !context.isAdmin) {
      throw StateError('Unauthorized: Administrator privilege required.');
    }
  }
}
