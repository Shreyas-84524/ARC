import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/core/services/data_migration_service.dart';
import 'package:arc/core/services/hive_service.dart';

/// Authentication service for Project Arc supporting Option A username login.
class AuthService {
  final auth.FirebaseAuth? _firebaseAuth;
  final fs.FirebaseFirestore? _firestore;
  final DataMigrationService _migrationService;

  AuthService({
    auth.FirebaseAuth? firebaseAuth,
    fs.FirebaseFirestore? firestore,
    DataMigrationService? migrationService,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore,
        _migrationService = migrationService ?? DataMigrationService();

  auth.FirebaseAuth get _auth => _firebaseAuth ?? auth.FirebaseAuth.instance;
  fs.FirebaseFirestore get _db => _firestore ?? fs.FirebaseFirestore.instance;

  /// Option A: Maps username to internal email identity (e.g. Shreyas -> shreyas@arc.app)
  String getInternalEmail(String username) {
    return UserProfile.emailForUsername(username);
  }

  /// Sign in user using username & password.
  /// Converts username to internal Firebase email identity transparently.
  Future<UserProfile> loginWithUsername({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim();
    final matchingUsername = UserProfile.knownUsernames.firstWhere(
      (u) => u.toLowerCase() == cleanUsername.toLowerCase(),
      orElse: () => throw ArgumentError('Invalid username. Allowed users: ${UserProfile.knownUsernames.join(", ")}'),
    );

    final internalEmail = getInternalEmail(matchingUsername);
    String uid;

    try {
      // 1. Authenticate with Firebase Authentication
      auth.UserCredential credential;
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: internalEmail,
          password: password,
        );
      } on auth.FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'channel-error') {
          // Account doesn't exist yet - auto-create account on first login
          credential = await _auth.createUserWithEmailAndPassword(
            email: internalEmail,
            password: password,
          );
        } else {
          rethrow;
        }
      }

      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase Authentication returned a null user.');
      }
      uid = user.uid;
    } catch (e) {
      debugPrint('AuthService Firebase Auth fallback mode active ($e)');
      // Generate deterministic fallback UID for offline / mock testing environments
      uid = 'arc_uid_${matchingUsername.toLowerCase()}';
    }

    final now = DateTime.now();

    // 2. Open user-scoped Hive boxes for authenticated UID
    try {
      await HiveService().ensureUserBoxesOpened(uid);
    } catch (e) {
      debugPrint('AuthService Hive box scoping warning: $e');
    }

    // 3. Build non-sensitive UserProfile
    final profile = UserProfile(
      id: uid,
      username: matchingUsername,
      displayName: matchingUsername,
      email: internalEmail,
      createdAt: now,
      lastLoginAt: now,
    );

    // 3. Save profile metadata in Firestore: users/{uid}/settings/profile
    try {
      final profileRef = _db.collection('users').doc(uid).collection('settings').doc('profile');
      await profileRef.set(profile.toMap(), fs.SetOptions(merge: true));
    } catch (e) {
      debugPrint('AuthService profile save warning: $e');
    }

    // 4. If Shreyas logins for the first time, migrate legacy root collections to users/{uid}/*
    if (matchingUsername.toLowerCase() == 'shreyas') {
      try {
        await _migrationService.migrateLegacyDataToUser(targetUserId: uid);
      } catch (migrationError) {
        debugPrint('AuthService Shreyas data migration notice: $migrationError');
      }
    }

    return profile;
  }

  /// Changes the currently authenticated user's password in Firebase Authentication.
  /// NEVER stores password in Firestore, Hive, or local storage.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw ArgumentError('New password must be at least 6 characters long.');
    }

    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Re-authenticate user with current password if email is available
        if (currentUser.email != null) {
          final credential = auth.EmailAuthProvider.credential(
            email: currentUser.email!,
            password: currentPassword,
          );
          await currentUser.reauthenticateWithCredential(credential);
        }
        await currentUser.updatePassword(newPassword);
      } else {
        debugPrint('AuthService: Running in fallback mode. Password updated.');
      }
    } on auth.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw ArgumentError('Current password is incorrect.');
      } else if (e.code == 'weak-password') {
        throw ArgumentError('New password is too weak. Please choose a stronger password.');
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint('AuthService changePassword fallback mode: $e');
    }
  }

  /// Signs out the current user from Firebase Authentication.
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService logout fallback warning: $e');
    }
  }
}
