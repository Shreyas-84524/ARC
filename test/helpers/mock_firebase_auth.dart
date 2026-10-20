import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class FakeUserMetadata implements auth.UserMetadata {
  @override
  final DateTime? creationTime;
  @override
  final DateTime? lastSignInTime;

  FakeUserMetadata([this.creationTime, this.lastSignInTime]);
}

class FakeUserInfo extends Fake implements auth.UserInfo {
  @override
  final String providerId;
  FakeUserInfo(this.providerId);
}

class FakeUser extends Fake implements auth.User {
  final String _uid;
  final String _email;
  final MockFirebaseAuth _mockAuth;
  final List<auth.UserInfo> _providerData;

  FakeUser({
    required String uid,
    required String email,
    required MockFirebaseAuth mockAuth,
    List<auth.UserInfo>? providerData,
  })  : _uid = uid,
        _email = email,
        _mockAuth = mockAuth,
        _providerData = providerData ?? [];

  @override
  String get uid => _uid;

  @override
  String? get email => _email;

  String? _displayName;
  @override
  String? get displayName => _displayName;

  @override
  Future<void> updateDisplayName(String? displayName) async {
    _displayName = displayName;
  }

  @override
  String? get photoURL => null;

  @override
  List<auth.UserInfo> get providerData => _providerData;

  @override
  auth.UserMetadata get metadata => FakeUserMetadata(DateTime.now(), DateTime.now());

  @override
  Future<auth.UserCredential> linkWithCredential(auth.AuthCredential credential) async {
    if (credential is auth.EmailAuthCredential) {
      final credentialMap = (credential as dynamic);
      final password = credentialMap.password as String?;
      if (password != null) {
        if (password.length < 6) {
          throw auth.FirebaseAuthException(
            code: 'weak-password',
            message: 'Password must be at least 6 characters long.',
          );
        }
        _mockAuth.userPasswords[_email] = password;
      }
      _providerData.add(FakeUserInfo('password'));
    }
    return FakeUserCredential(this);
  }

  @override
  Future<auth.UserCredential> reauthenticateWithCredential(auth.AuthCredential credential) async {
    final currentStoredPassword = _mockAuth.userPasswords[_email];
    if (credential is auth.EmailAuthCredential) {
      final credentialMap = (credential as dynamic);
      final password = credentialMap.password as String?;
      if (password != null && currentStoredPassword != null && password != currentStoredPassword) {
        throw auth.FirebaseAuthException(
          code: 'wrong-password',
          message: 'The current password is incorrect.',
        );
      }
    }
    return FakeUserCredential(this);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    if (newPassword.length < 6) {
      throw auth.FirebaseAuthException(
        code: 'weak-password',
        message: 'Password must be at least 6 characters long.',
      );
    }
    _mockAuth.userPasswords[_email] = newPassword;
  }
}

class FakeUserCredential extends Fake implements auth.UserCredential {
  final auth.User _user;
  FakeUserCredential(this._user);

  @override
  auth.User? get user => _user;
}

class MockFirebaseAuth extends Fake implements auth.FirebaseAuth {
  final Map<String, String> userPasswords = {};
  final StreamController<auth.User?> _authStateController = StreamController<auth.User?>.broadcast();
  auth.User? _currentUser;

  @override
  auth.User? get currentUser => _currentUser;

  @override
  Stream<auth.User?> authStateChanges() => _authStateController.stream;

  @override
  Future<auth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!userPasswords.containsKey(email)) {
      throw auth.FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found for that email.',
      );
    }
    if (userPasswords[email] != password) {
      throw auth.FirebaseAuthException(
        code: 'wrong-password',
        message: 'Wrong password provided.',
      );
    }
    final uid = 'uid_${email.split('@').first}';
    _currentUser = FakeUser(uid: uid, email: email, mockAuth: this);
    _authStateController.add(_currentUser);
    return FakeUserCredential(_currentUser!);
  }

  @override
  Future<auth.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (userPasswords.containsKey(email)) {
      throw auth.FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'The account already exists for that email.',
      );
    }
    userPasswords[email] = password;
    final uid = 'uid_${email.split('@').first}';
    _currentUser = FakeUser(uid: uid, email: email, mockAuth: this);
    _authStateController.add(_currentUser);
    return FakeUserCredential(_currentUser!);
  }

  final List<String> resetEmailsSent = [];

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    auth.ActionCodeSettings? actionCodeSettings,
  }) async {
    resetEmailsSent.add(email);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }
}
