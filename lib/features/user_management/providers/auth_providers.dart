import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/repository/auth_repository.dart';
import 'package:arc/features/user_management/services/auth_service.dart';

/// Provider providing access to the authentication repository singleton
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Provider exposing AuthService configured with the active repository
final authServiceProvider = Provider<AuthService>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthService(repository: repository);
});

/// Stream provider for listening to native Firebase Auth state transitions
final authStateChangesProvider = StreamProvider<auth.User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges();
});

/// Current authenticated Firebase user instance
final currentUserProvider = Provider<auth.User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.currentUser;
});

/// Provider to fetch user profile metadata by UID
final userProfileProvider = FutureProvider.family<UserProfile?, String>((ref, uid) async {
  final repository = ref.watch(authRepositoryProvider);
  return repository.getUserProfile(uid);
});
