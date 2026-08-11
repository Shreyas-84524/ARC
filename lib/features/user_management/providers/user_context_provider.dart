import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/core/services/hive_service.dart';

class UserContextNotifier extends StateNotifier<UserContext> {
  StreamSubscription<auth.User?>? _authSubscription;
  final auth.FirebaseAuth? _providedAuth;

  UserContextNotifier({auth.FirebaseAuth? firebaseAuth})
      : _providedAuth = firebaseAuth,
        super(UserContext.legacy) {
    _initAuthListener();
  }

  void _initAuthListener() {
    try {
      final firebaseAuth = _providedAuth ?? auth.FirebaseAuth.instance;
      final currentUser = firebaseAuth.currentUser;
      if (currentUser != null) {
        _setFromFirebaseUser(currentUser);
      }

      _authSubscription = firebaseAuth.authStateChanges().listen((user) {
        if (user != null) {
          _setFromFirebaseUser(user);
        } else {
          state = UserContext.legacy;
        }
      });
    } catch (e) {
      // In unit test environments where Firebase core is not initialized,
      // UserContextNotifier safely falls back to default context.
    }
  }

  void _setFromFirebaseUser(auth.User user) {
    final email = user.email ?? '';
    final username = _usernameFromEmail(email);
    final profile = UserProfile(
      id: user.uid,
      username: username,
      displayName: username,
      email: email,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: user.metadata.lastSignInTime,
    );
    HiveService().ensureUserBoxesOpened(user.uid);
    state = UserContext(userId: user.uid, profile: profile);
  }

  static String _usernameFromEmail(String email) {
    if (email.contains('@')) {
      final prefix = email.split('@').first;
      if (prefix.isNotEmpty) {
        return prefix[0].toUpperCase() + prefix.substring(1).toLowerCase();
      }
    }
    return 'User';
  }

  /// Sets the active user context for user-scoped data operations.
  void setActiveUser({required String userId, UserProfile? profile}) {
    HiveService().ensureUserBoxesOpened(userId);
    state = UserContext(userId: userId, profile: profile);
  }

  /// Resets to legacy unauthenticated mode (single-user root collections).
  void resetToLegacy() {
    state = UserContext.legacy;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Provider exposing the currently active user context across the app.
final userContextProvider =
    StateNotifierProvider<UserContextNotifier, UserContext>((ref) {
  return UserContextNotifier();
});

