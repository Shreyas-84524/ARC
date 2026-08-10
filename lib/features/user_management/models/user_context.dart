import 'package:flutter/foundation.dart';
import 'package:arc/features/user_management/models/user_profile.dart';

@immutable
class UserContext {
  final String? userId;
  final UserProfile? profile;

  const UserContext({
    this.userId,
    this.profile,
  });

  /// Default unauthenticated context representing legacy single-user mode
  static const UserContext legacy = UserContext(userId: null, profile: null);

  bool get isAuthenticated => userId != null && userId!.isNotEmpty;

  bool get isLegacy => !isAuthenticated;

  String get userNamespace => (userId != null && userId!.isNotEmpty) ? userId! : 'global';

  /// Generates the target Firestore collection path for a given base collection.
  ///
  /// In legacy mode (userId == null), returns the root collection name (e.g. "tasks").
  /// In user-scoped mode (userId != null), returns "users/{userId}/{collectionName}".
  String firestoreCollectionPath(String collectionName) {
    if (!isAuthenticated) return collectionName;
    return 'users/$userId/$collectionName';
  }

  /// Generates the target Firestore settings document reference path.
  ///
  /// In legacy mode, returns "settings/global".
  /// In user-scoped mode, returns "users/{userId}/settings/profile".
  String firestoreSettingsDocPath() {
    if (!isAuthenticated) return 'settings/global';
    return 'users/$userId/settings/profile';
  }

  UserContext copyWith({
    String? userId,
    UserProfile? profile,
    bool setNullUser = false,
  }) {
    return UserContext(
      userId: setNullUser ? null : (userId ?? this.userId),
      profile: setNullUser ? null : (profile ?? this.profile),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserContext &&
        other.userId == userId &&
        other.profile == profile;
  }

  @override
  int get hashCode => Object.hash(userId, profile);
}
