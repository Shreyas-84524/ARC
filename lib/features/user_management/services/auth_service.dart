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
    if (cleanUsername.isEmpty) {
      throw ArgumentError('Invalid username.');
    }
    if (password.isEmpty) {
      throw ArgumentError('Invalid password.');
    }

    final allUsernames = [...UserProfile.knownUsernames, 'ADMIN'];
    final matchingUsername = allUsernames.firstWhere(
      (u) => u.toLowerCase() == cleanUsername.toLowerCase(),
      orElse: () => throw ArgumentError('Invalid username.'),
    );

    final internalEmail = getInternalEmail(matchingUsername);
    auth.UserCredential credential;

    try {
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: internalEmail,
          password: password,
        );
      } on auth.FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // Account doesn't exist yet - auto-create account on first login
          credential = await _auth.createUserWithEmailAndPassword(
            email: internalEmail,
            password: password,
          );
        } else if (e.code == 'invalid-credential') {
          // invalid-credential can occur for wrong password OR non-existent account (user enumeration protection).
          // Attempt account creation to distinguish between the two.
          try {
            credential = await _auth.createUserWithEmailAndPassword(
              email: internalEmail,
              password: password,
            );
          } on auth.FirebaseAuthException catch (createErr) {
            if (createErr.code == 'email-already-in-use') {
              // Account already exists -> initial failure was due to incorrect password!
              throw ArgumentError('Invalid password.');
            } else {
              rethrow;
            }
          }
        } else if (e.code == 'wrong-password') {
          throw ArgumentError('Invalid password.');
        } else {
          rethrow;
        }
      }
    } on auth.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw ArgumentError('Invalid password.');
      } else if (e.code == 'user-not-found') {
        throw ArgumentError('Invalid username.');
      } else if (e.code == 'weak-password') {
        throw ArgumentError('Password does not meet requirements.');
      } else {
        throw ArgumentError('Authentication failed. Please check your credentials.');
      }
    }

    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase Authentication returned a null user.');
    }
    final uid = user.uid;

    final now = DateTime.now();

    // 2. Open user-scoped Hive boxes for authenticated UID
    try {
      await HiveService().ensureUserBoxesOpened(uid);
    } catch (e) {
      debugPrint('AuthService Hive box scoping warning: $e');
    }

    final role = matchingUsername.toLowerCase() == 'admin' ? 'admin' : 'user';

    // 3. Build non-sensitive UserProfile
    final profile = UserProfile(
      id: uid,
      username: matchingUsername,
      displayName: matchingUsername,
      email: internalEmail,
      role: role,
      createdAt: now,
      lastLoginAt: now,
    );

    // 4. Save profile metadata in Firestore: users/{uid}/settings/profile
    try {
      final profileRef = _db.collection('users').doc(uid).collection('settings').doc('profile');
      await profileRef.set(profile.toMap(), fs.SetOptions(merge: true));
    } catch (e) {
      debugPrint('AuthService profile save warning: $e');
    }

    // 5. If Shreyas logins for the first time, migrate legacy root collections to users/{uid}/*
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

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw ArgumentError('No authenticated user found. Please log in again.');
    }

    final email = currentUser.email;
    if (email == null || email.isEmpty) {
      throw ArgumentError('User email is missing. Cannot reauthenticate.');
    }

    try {
      // Re-authenticate user with current password
      final credential = auth.EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await currentUser.reauthenticateWithCredential(credential);

      // Update password in Firebase Authentication
      await currentUser.updatePassword(newPassword);
    } on auth.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'user-mismatch') {
        throw ArgumentError('Current password is incorrect.');
      } else if (e.code == 'weak-password') {
        throw ArgumentError('Your new password does not meet the password requirements.');
      } else if (e.code == 'requires-recent-login') {
        throw ArgumentError('For security reasons, please log out and log back in before changing your password.');
      } else {
        throw ArgumentError('Failed to change password. Please check your connection and try again.');
      }
    }
  }

  /// Signs out the current user from Firebase Authentication.
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService logout warning: $e');
    }
  }
}
