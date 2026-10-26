import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/repository/auth_repository.dart';
import 'package:arc/core/services/data_migration_service.dart';

/// Authentication service for Project Arc providing modern Firebase multi-provider
/// authentication (Email/Password, Google Sign-In) and provider linking methods.
class AuthService {
  final AuthRepository _repository;

  AuthService({
    auth.FirebaseAuth? firebaseAuth,
    fs.FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    DataMigrationService? migrationService,
    AuthRepository? repository,
  }) : _repository = repository ??
            AuthRepository(
              firebaseAuth: firebaseAuth,
              firestore: firestore,
              googleSignIn: googleSignIn,
              migrationService: migrationService,
            );

  AuthRepository get repository => _repository;

  /// Signs in a user with email and password.
  Future<UserProfile> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _repository.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Registers a new user with full name, email, and password.
  Future<UserProfile> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return _repository.signUpWithEmailAndPassword(
      email: email,
      password: password,
      fullName: fullName,
    );
  }

  /// Signs in a user using Google Authentication.
  Future<UserProfile> signInWithGoogle() async {
    return _repository.signInWithGoogle();
  }

  /// Returns list of provider IDs linked to the current user (e.g. ['google.com', 'password']).
  List<String> getLinkedProviders() {
    return _repository.getLinkedProviders();
  }

  /// Whether current user has a linked password provider.
  bool hasPasswordProvider() {
    return getLinkedProviders().contains('password');
  }

  /// Whether current user has a linked Google provider.
  bool hasGoogleProvider() {
    return getLinkedProviders().contains('google.com');
  }

  /// Links an Email/Password credential to the current authenticated Firebase user.
  Future<void> linkPassword({required String newPassword}) async {
    return _repository.linkPassword(newPassword: newPassword);
  }

  /// Sends a password reset email to the specified address.
  Future<void> sendPasswordResetEmail({required String email}) async {
    return _repository.sendPasswordResetEmail(email: email);
  }

  /// Option A: Maps username to internal email identity (e.g. Shreyas -> shigwanshreyas4@gmail.com)
  String getInternalEmail(String username) {
    return _repository.getInternalEmail(username);
  }

  /// Sign in user using username & password.
  /// Converts username to internal Firebase email identity transparently.
  Future<UserProfile> loginWithUsername({
    required String username,
    required String password,
  }) async {
    return _repository.loginWithUsername(
      username: username,
      password: password,
    );
  }

  /// Updates the user's custom in-app display name.
  /// Validates Unicode support, rejects emojis, normalizes spacing, and caches to Hive/Firestore.
  Future<UserProfile> updateDisplayName({
    required String userId,
    required String newDisplayName,
  }) async {
    return _repository.updateDisplayName(
      userId: userId,
      newDisplayName: newDisplayName,
    );
  }

  /// Changes the currently authenticated user's password in Firebase Authentication.
  /// NEVER stores password in Firestore, Hive, or local storage.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Signs out the current user from Firebase Authentication.
  Future<void> logout() async {
    try {
      await _repository.signOut();
    } catch (e) {
      debugPrint('AuthService logout notice: $e');
    }
  }

  Future<void> signOut() async => logout();
}
