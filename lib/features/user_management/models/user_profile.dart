import 'package:flutter/foundation.dart';

@immutable
class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String email;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.lastLoginAt,
  });

  /// Known initial users planned for Project Arc
  static const List<String> knownUsernames = [
    'Shreyas',
    'Aman',
    'Rohit',
    'Sachi',
    'Yash',
  ];

  /// Standard internal email generator for username mapping
  static String emailForUsername(String username) {
    final sanitized = username.trim().toLowerCase();
    return '$sanitized@arc.app';
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? email,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? map['username'] ?? '',
      email: map['email'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
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
        other.createdAt == createdAt &&
        other.lastLoginAt == lastLoginAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      username,
      displayName,
      email,
      createdAt,
      lastLoginAt,
    );
  }
}
