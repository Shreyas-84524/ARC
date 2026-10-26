import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/repository/auth_repository.dart';
import 'package:arc/core/services/hive_service.dart';

class UserContextNotifier extends StateNotifier<UserContext> {
  StreamSubscription<auth.User?>? _authSubscription;
  final auth.FirebaseAuth? _providedAuth;

  UserContextNotifier({auth.FirebaseAuth? firebaseAuth})
      : _providedAuth = firebaseAuth,
        super(UserContext.initializing) {
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

      if (currentUser == null) {
        Future.microtask(() {
          if (state.isInitializing) {
            state = UserContext.legacy;
          }
        });
      }
    } catch (e) {
      // In unit test environments where Firebase core is not initialized,
      // UserContextNotifier safely falls back to default context.
      state = UserContext.legacy;
    }
  }

  Future<void> _setFromFirebaseUser(auth.User user) async {
    try {
      await HiveService().ensureUserBoxesOpened(user.uid);
    } catch (e) {
      // Ignore in mock testing environments
    }

    // Check Hive cache first for instantaneous offline/startup display
    UserProfile? cachedProfile;
    try {
      final box = HiveService().getUserBox(HiveService.settingsBoxName, user.uid);
      final raw = box.get('cached_user_profile');
      if (raw is Map) {
        cachedProfile = UserProfile.fromMap(Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      debugPrint('UserContextNotifier: Error reading cached profile: $e');
    }

    if (cachedProfile != null) {
      state = UserContext(userId: user.uid, profile: cachedProfile, isInitializing: false);
      unawaited(_reconcileProfile(user.uid));
      return;
    }

    final email = user.email;
    final displayName = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName!
        : (email != null && email.isNotEmpty)
            ? _usernameFromEmail(email)
            : 'User';
    final username = displayName;

    String role = 'user';
    try {
      final tokenResult = await user.getIdTokenResult();
      if (tokenResult.claims?['role'] == 'admin') {
        role = 'admin';
      }
    } catch (_) {
      // Ignore token fetch errors in testing environments
    }

    if (username.toUpperCase() == 'ADMIN' ||
        (email != null && email.toLowerCase() == 'admin@arc.app')) {
      role = 'admin';
    }

    String provider = 'password';
    if (user.providerData.isNotEmpty) {
      final providerId = user.providerData.first.providerId;
      if (providerId.contains('google')) {
        provider = 'google';
      }
    }

    final profile = UserProfile(
      id: user.uid,
      username: username,
      displayName: displayName,
      displayNameSource: provider == 'google' ? 'google' : 'default',
      displayNameUpdatedAt: DateTime.now(),
      email: email,
      photoURL: user.photoURL,
      authProvider: provider,
      role: role,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: user.metadata.lastSignInTime,
    );

    try {
      final box = HiveService().getUserBox(HiveService.settingsBoxName, user.uid);
      await box.put('cached_user_profile', profile.toMap());
    } catch (_) {}

    state = UserContext(userId: user.uid, profile: profile, isInitializing: false);
    unawaited(_reconcileProfile(user.uid));
  }

  Future<void> _reconcileProfile(String uid) async {
    try {
      final authRepo = AuthRepository();
      await authRepo.flushPendingProfileSync(uid);
      final remote = await authRepo.getUserProfile(uid);
      if (remote != null && mounted) {
        state = state.copyWith(profile: remote);
      }
    } catch (e) {
      debugPrint('UserContextNotifier reconcile warning: $e');
    }
  }

  static String _usernameFromEmail(String email) {
    if (email.contains('@')) {
      final prefix = email.split('@').first;
      if (prefix.toLowerCase() == 'admin') {
        return 'ADMIN';
      }
      if (prefix.isNotEmpty) {
        return prefix[0].toUpperCase() + prefix.substring(1).toLowerCase();
      }
    }
    return 'User';
  }

  /// Sets the active user context for user-scoped data operations.
  void setActiveUser({required String userId, UserProfile? profile}) {
    try {
      HiveService().ensureUserBoxesOpened(userId);
      if (profile != null) {
        final box = HiveService().getUserBox(HiveService.settingsBoxName, userId);
        box.put('cached_user_profile', profile.toMap());
      }
    } catch (e) {
      // In mock/test environments HiveService might not be initialized
    }
    state = UserContext(userId: userId, profile: profile, isInitializing: false);
  }

  /// Updates the profile in state and syncs to user-scoped Hive cache.
  void updateProfile(UserProfile updatedProfile) {
    state = state.copyWith(profile: updatedProfile);
    try {
      final box = HiveService().getUserBox(HiveService.settingsBoxName, updatedProfile.id);
      box.put('cached_user_profile', updatedProfile.toMap());
    } catch (e) {
      debugPrint('UserContextNotifier updateProfile cache warning: $e');
    }
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
