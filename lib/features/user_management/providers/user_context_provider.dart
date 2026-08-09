import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/models/user_profile.dart';

class UserContextNotifier extends StateNotifier<UserContext> {
  UserContextNotifier() : super(UserContext.legacy);

  /// Sets the active user context for user-scoped data operations.
  void setActiveUser({required String userId, UserProfile? profile}) {
    state = UserContext(userId: userId, profile: profile);
  }

  /// Resets to legacy unauthenticated mode (single-user root collections).
  void resetToLegacy() {
    state = UserContext.legacy;
  }
}

/// Provider exposing the currently active user context across the app.
final userContextProvider =
    StateNotifierProvider<UserContextNotifier, UserContext>((ref) {
  return UserContextNotifier();
});
