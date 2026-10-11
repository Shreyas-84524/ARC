import 'package:flutter/foundation.dart';

@immutable
class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? photoURL;
  final String authProvider; // 'password', 'google'
  final String role;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.photoURL,
    this.authProvider = 'password',
    this.role = 'user',
    required this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  /// Known initial users planned for Project Arc
  static const List<String> knownUsernames = [
    'Shreyas',
    'Aman',
    'Rohit',
    'Sachi',
    'Yash',
    'Purushottam',
  ];

  static bool isKnownUsername(String username) {
    final clean = username.trim().toLowerCase();
    return clean == 'admin' || knownUsernames.any((u) => u.toLowerCase() == clean);
  }

  /// Standard internal email generator for username mapping
  static String emailForUsername(String username) {
    final sanitized = username.trim().toLowerCase();
    if (sanitized == 'shreyas') {
      return 'shigwanshreyas4@gmail.com';
    }
    return '$sanitized@arc.app';
  }

  bool get isAdmin => role == 'admin';

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? email,
    String? photoURL,
    String? authProvider,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      authProvider: authProvider ?? this.authProvider,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': id,
      'username': username,
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'authProvider': authProvider,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': (updatedAt ?? createdAt).toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? map['uid'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? map['username'] ?? '',
      email: map['email'] as String?,
      photoURL: map['photoURL'] as String?,
      authProvider: map['authProvider'] ?? 'password',
      role: map['role'] ?? 'user',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'])
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.username == username &&
        other.displayName == displayName &&
        other.email == email &&
        other.photoURL == photoURL &&
        other.authProvider == authProvider &&
        other.role == role &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.lastLoginAt == lastLoginAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      username,
      displayName,
      email,
      photoURL,
      authProvider,
      role,
      createdAt,
      updatedAt,
      lastLoginAt,
    );
  }
}
