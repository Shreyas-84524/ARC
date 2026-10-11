import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/models/auth_exception.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/core/services/data_migration_service.dart';

abstract class IAuthRepository {
  Stream<auth.User?> authStateChanges();
  auth.User? get currentUser;
  Future<UserProfile> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<UserProfile> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  });
  Future<UserProfile> signInWithGoogle();
  List<String> getLinkedProviders();
  Future<void> linkPassword({required String newPassword});
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> signOut();
  Future<UserProfile?> getUserProfile(String uid);
  Future<void> updateUserProfile(UserProfile profile);
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

class AuthRepository implements IAuthRepository {
  final auth.FirebaseAuth? _firebaseAuth;
  final fs.FirebaseFirestore? _firestore;
  final GoogleSignIn? _googleSignInInstance;
  final DataMigrationService _migrationService;

  AuthRepository({
    auth.FirebaseAuth? firebaseAuth,
    fs.FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    DataMigrationService? migrationService,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore,
        _googleSignInInstance = googleSignIn,
        _migrationService = migrationService ?? DataMigrationService();

  auth.FirebaseAuth get _auth => _firebaseAuth ?? auth.FirebaseAuth.instance;
  fs.FirebaseFirestore get _db => _firestore ?? fs.FirebaseFirestore.instance;
  GoogleSignIn get _googleSignIn => _googleSignInInstance ?? GoogleSignIn();

  @override
  Stream<auth.User?> authStateChanges() => _auth.authStateChanges();

  @override
  auth.User? get currentUser => _auth.currentUser;

  @override
  Future<UserProfile> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      throw const AuthException('Please enter your email address.');
    }
    if (password.isEmpty) {
      throw const AuthException('Please enter your password.');
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException('Failed to retrieve authenticated user session.');
      }

      // Open user-scoped Hive boxes
      try {
        await HiveService().ensureUserBoxesOpened(user.uid);
      } catch (e) {
        debugPrint('AuthRepository Hive box warning: $e');
      }

      // Fetch or sync user profile
      UserProfile? profile = await getUserProfile(user.uid);
      final now = DateTime.now();

      final UserProfile activeProfile;
      if (profile == null) {
        final displayName = user.displayName ?? _displayNameFromEmail(cleanEmail);
        final role = _deriveRole(cleanEmail);
        activeProfile = UserProfile(
          id: user.uid,
          username: displayName,
          displayName: displayName,
          email: cleanEmail,
          photoURL: _safePhotoURL(user),
          authProvider: 'password',
          role: role,
          createdAt: user.metadata.creationTime ?? now,
          updatedAt: now,
          lastLoginAt: now,
        );
      } else {
        activeProfile = profile.copyWith(
          lastLoginAt: now,
          updatedAt: now,
        );
      }

      // Persist profile in Firestore without any sensitive credentials
      await _persistProfile(activeProfile);

      return activeProfile;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException.fromFirebase(e);
    }
  }

  @override
  Future<UserProfile> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = fullName.trim();

    if (cleanName.isEmpty) {
      throw const AuthException('Please enter your full name.');
    }
    if (cleanName.length < 2) {
      throw const AuthException('Full name must be at least 2 characters.');
    }
    if (cleanEmail.isEmpty) {
      throw const AuthException('Please enter your email address.');
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(cleanEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }
    if (password.isEmpty) {
      throw const AuthException('Please enter a password.');
    }
    if (password.length < 6) {
      throw const AuthException('Password must be at least 6 characters long.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException('Failed to initialize new user account.');
      }

      // Update user display name in Firebase Auth
      try {
        await user.updateDisplayName(cleanName);
      } catch (e) {
        debugPrint('AuthRepository updateDisplayName warning: $e');
      }

      final now = DateTime.now();
      final role = _deriveRole(cleanEmail);

      final profile = UserProfile(
        id: user.uid,
        username: cleanName,
        displayName: cleanName,
        email: cleanEmail,
        photoURL: _safePhotoURL(user),
        authProvider: 'password',
        role: role,
        createdAt: now,
        updatedAt: now,
        lastLoginAt: now,
      );

      // Open user-scoped Hive boxes
      try {
        await HiveService().ensureUserBoxesOpened(user.uid);
      } catch (e) {
        debugPrint('AuthRepository Hive box warning: $e');
      }

      // Persist profile in Firestore without secrets
      await _persistProfile(profile);

      return profile;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException.fromFirebase(e);
    }
  }

  @override
  Future<UserProfile> signInWithGoogle() async {
    try {
      auth.UserCredential credential;

      if (kIsWeb) {
        final googleProvider = auth.GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        credential = await _auth.signInWithPopup(googleProvider);
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw const AuthException('Google sign-in was cancelled.', code: 'cancelled');
        }

        final googleAuth = await googleUser.authentication;
        final authCredential = auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        credential = await _auth.signInWithCredential(authCredential);
      }

      final user = credential.user;
      if (user == null) {
        throw const AuthException('Failed to retrieve authenticated user session.');
      }

      try {
        await HiveService().ensureUserBoxesOpened(user.uid);
      } catch (e) {
        debugPrint('AuthRepository Hive box warning: $e');
      }

      final now = DateTime.now();
      UserProfile? existingProfile = await getUserProfile(user.uid);

      UserProfile profile;
      if (existingProfile == null) {
        final displayName = (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName!
            : (user.email != null ? _displayNameFromEmail(user.email!) : 'Google User');
        final role = _deriveRole(user.email ?? '');

        profile = UserProfile(
          id: user.uid,
          username: displayName,
          displayName: displayName,
          email: user.email,
          photoURL: user.photoURL,
          authProvider: 'google',
          role: role,
          createdAt: user.metadata.creationTime ?? now,
          updatedAt: now,
          lastLoginAt: now,
        );
      } else {
        profile = existingProfile.copyWith(
          lastLoginAt: now,
          updatedAt: now,
          displayName: existingProfile.displayName.isNotEmpty
              ? existingProfile.displayName
              : (user.displayName ?? existingProfile.displayName),
          photoURL: user.photoURL ?? existingProfile.photoURL,
          authProvider: 'google',
        );
      }

      await _persistProfile(profile);

      return profile;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException.fromFirebase(e);
    }
  }

  @override
  List<String> getLinkedProviders() {
    try {
      final user = currentUser;
      if (user == null) return [];
      return user.providerData.map((p) => p.providerId).toList();
    } catch (e) {
      // In mock/test environments without initialized Firebase Core
      return [];
    }
  }

  @override
  Future<void> linkPassword({required String newPassword}) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('No active user session found.', code: 'no-current-user');
    }
    final email = user.email;
    if (email == null || email.trim().isEmpty) {
      throw const AuthException('A verified email is required to add an ARC password.', code: 'missing-email');
    }
    if (newPassword.length < 6) {
      throw const AuthException('Password must be at least 6 characters.', code: 'weak-password');
    }

    try {
      final credential = auth.EmailAuthProvider.credential(
        email: email.trim(),
        password: newPassword,
      );
      await user.linkWithCredential(credential);

      final now = DateTime.now();
      final existingProfile = await getUserProfile(user.uid);
      if (existingProfile != null) {
        final updated = existingProfile.copyWith(
          authProvider: 'password,google',
          updatedAt: now,
        );
        await _persistProfile(updated);
      }
    } on auth.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        try {
          if (!kIsWeb) {
            final googleUser = await _googleSignIn.signIn();
            if (googleUser != null) {
              final googleAuth = await googleUser.authentication;
              final cred = auth.GoogleAuthProvider.credential(
                idToken: googleAuth.idToken,
                accessToken: googleAuth.accessToken,
              );
              await user.reauthenticateWithCredential(cred);
              final pwdCred = auth.EmailAuthProvider.credential(
                email: email.trim(),
                password: newPassword,
              );
              await user.linkWithCredential(pwdCred);
              return;
            }
          }
        } catch (_) {
          // Fall through to throw standard requires-recent-login
        }
      }
      throw AuthException.fromFirebase(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException.fromFirebase(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      throw const AuthException('Please enter your email address.');
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(cleanEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }

    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException.fromFirebase(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb && _googleSignInInstance != null) {
        try {
          await _googleSignInInstance.signOut();
        } catch (_) {}
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthRepository signOut warning: $e');
      throw AuthException.fromFirebase(e);
    }
  }

  @override
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      // 1. Try reading from users/{uid}
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        return UserProfile.fromMap(userDoc.data()!);
      }

      // 2. Fallback to users/{uid}/settings/profile
      final profileDoc = await _db
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('profile')
          .get();
      if (profileDoc.exists && profileDoc.data() != null) {
        return UserProfile.fromMap(profileDoc.data()!);
      }
    } catch (e) {
      debugPrint('AuthRepository getUserProfile notice: $e');
    }
    return null;
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) async {
    await _persistProfile(profile);
  }

  @override
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
      final credential = auth.EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await currentUser.reauthenticateWithCredential(credential);
      await currentUser.updatePassword(newPassword);
    } on auth.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'user-mismatch') {
        throw ArgumentError('Current password is incorrect.');
      } else if (e.code == 'weak-password') {
        throw ArgumentError('Your new password does not meet the password requirements.');
      } else if (e.code == 'requires-recent-login') {
        throw ArgumentError(
          'For security reasons, please log out and log back in before changing your password.',
        );
      } else {
        throw ArgumentError('Failed to change password. Please check your connection and try again.');
      }
    }
  }

  /// Option A: Legacy username-to-email helper.
  String getInternalEmail(String username) {
    return UserProfile.emailForUsername(username);
  }

  /// Option A legacy loginWithUsername for backwards compatibility.
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
          credential = await _auth.createUserWithEmailAndPassword(
            email: internalEmail,
            password: password,
          );
        } else if (e.code == 'invalid-credential') {
          try {
            credential = await _auth.createUserWithEmailAndPassword(
              email: internalEmail,
              password: password,
            );
          } on auth.FirebaseAuthException catch (createErr) {
            if (createErr.code == 'email-already-in-use') {
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

    try {
      await HiveService().ensureUserBoxesOpened(uid);
    } catch (e) {
      debugPrint('AuthRepository Hive box warning: $e');
    }

    final role = matchingUsername.toLowerCase() == 'admin' ? 'admin' : 'user';

    final profile = UserProfile(
      id: uid,
      username: matchingUsername,
      displayName: matchingUsername,
      email: internalEmail,
      authProvider: 'password',
      role: role,
      createdAt: now,
      updatedAt: now,
      lastLoginAt: now,
    );

    await _persistProfile(profile);

    if (matchingUsername.toLowerCase() == 'shreyas') {
      try {
        await _migrationService.migrateLegacyDataToUser(targetUserId: uid);
      } catch (migrationError) {
        debugPrint('AuthRepository Shreyas data migration notice: $migrationError');
      }
    }

    return profile;
  }

  Future<void> _persistProfile(UserProfile profile) async {
    try {
      final profileMap = profile.toMap();

      // Write under users/{uid} (Task 5 & 10 requirement)
      await _db
          .collection('users')
          .doc(profile.id)
          .set(profileMap, fs.SetOptions(merge: true));

      // Also write under users/{uid}/settings/profile for backwards compatibility with security rules
      await _db
          .collection('users')
          .doc(profile.id)
          .collection('settings')
          .doc('profile')
          .set(profileMap, fs.SetOptions(merge: true));
    } catch (e) {
      debugPrint('AuthRepository profile save warning: $e');
    }
  }

  String? _safePhotoURL(auth.User user) {
    try {
      return user.photoURL;
    } catch (_) {
      return null;
    }
  }

  String _displayNameFromEmail(String email) {
    if (email.contains('@')) {
      final prefix = email.split('@').first;
      if (prefix.isNotEmpty) {
        return prefix[0].toUpperCase() + prefix.substring(1).toLowerCase();
      }
    }
    return 'User';
  }

  String _deriveRole(String email) {
    final lower = email.toLowerCase().trim();
    if (lower == 'admin@arc.app' || lower.startsWith('admin@')) {
      return 'admin';
    }
    return 'user';
  }
}
