import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:arc/features/user_management/repository/auth_repository.dart';
import 'package:arc/features/user_management/models/auth_exception.dart';
import 'helpers/mock_firebase_auth.dart';

void main() {
  group('AuthRepository Unit Tests', () {
    late MockFirebaseAuth mockAuth;
    late AuthRepository authRepository;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      authRepository = AuthRepository(firebaseAuth: mockAuth);
    });

    test('signUpWithEmailAndPassword succeeds with valid details and updates display name', () async {
      final profile = await authRepository.signUpWithEmailAndPassword(
        email: 'tester@arc.app',
        password: 'securePassword123',
        fullName: 'Jane Doe',
      );

      expect(profile.email, equals('tester@arc.app'));
      expect(profile.displayName, equals('Jane Doe'));
      expect(profile.role, equals('user'));
      expect(profile.id, equals('uid_tester'));

      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser!.email, equals('tester@arc.app'));
      expect(mockAuth.currentUser!.displayName, equals('Jane Doe'));
    });

    test('signUpWithEmailAndPassword rejects invalid inputs', () async {
      // Empty full name
      expect(
        () => authRepository.signUpWithEmailAndPassword(
          email: 'test@arc.app',
          password: 'password123',
          fullName: '',
        ),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('full name'))),
      );

      // Short full name
      expect(
        () => authRepository.signUpWithEmailAndPassword(
          email: 'test@arc.app',
          password: 'password123',
          fullName: 'A',
        ),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('at least 2 characters'))),
      );

      // Invalid email
      expect(
        () => authRepository.signUpWithEmailAndPassword(
          email: 'not-an-email',
          password: 'password123',
          fullName: 'John Doe',
        ),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('valid email'))),
      );

      // Short password
      expect(
        () => authRepository.signUpWithEmailAndPassword(
          email: 'test@arc.app',
          password: '123',
          fullName: 'John Doe',
        ),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('at least 6 characters'))),
      );
    });

    test('signUpWithEmailAndPassword throws when email already in use', () async {
      // Register first time
      await authRepository.signUpWithEmailAndPassword(
        email: 'duplicate@arc.app',
        password: 'password123',
        fullName: 'First User',
      );

      // Attempt second registration with same email
      expect(
        () => authRepository.signUpWithEmailAndPassword(
          email: 'duplicate@arc.app',
          password: 'newPassword456',
          fullName: 'Second User',
        ),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', equals('email-already-in-use'))),
      );
    });

    test('signInWithEmailAndPassword succeeds with correct credentials', () async {
      // Register account first
      await authRepository.signUpWithEmailAndPassword(
        email: 'signin@arc.app',
        password: 'correctPassword',
        fullName: 'Alex Smith',
      );

      // Logout
      await authRepository.signOut();
      expect(mockAuth.currentUser, isNull);

      // Sign In
      final profile = await authRepository.signInWithEmailAndPassword(
        email: 'signin@arc.app',
        password: 'correctPassword',
      );

      expect(profile.email, equals('signin@arc.app'));
      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser!.email, equals('signin@arc.app'));
    });

    test('signInWithEmailAndPassword fails with wrong password or unknown user', () async {
      // Register account
      await authRepository.signUpWithEmailAndPassword(
        email: 'valid@arc.app',
        password: 'correctPassword',
        fullName: 'User One',
      );
      await authRepository.signOut();

      // Wrong password
      expect(
        () => authRepository.signInWithEmailAndPassword(
          email: 'valid@arc.app',
          password: 'wrongPassword',
        ),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', equals('wrong-password'))),
      );

      // Non-existent user
      expect(
        () => authRepository.signInWithEmailAndPassword(
          email: 'nonexistent@arc.app',
          password: 'anyPassword',
        ),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', equals('user-not-found'))),
      );
    });

    test('sendPasswordResetEmail tracks dispatched email and validates format', () async {
      // Valid email
      await authRepository.sendPasswordResetEmail(email: 'resetme@arc.app');
      expect(mockAuth.resetEmailsSent, contains('resetme@arc.app'));

      // Empty email
      expect(
        () => authRepository.sendPasswordResetEmail(email: ''),
        throwsA(isA<AuthException>()),
      );

      // Invalid email
      expect(
        () => authRepository.sendPasswordResetEmail(email: 'invalid-email-address'),
        throwsA(isA<AuthException>()),
      );
    });

    test('signOut clears user session and notifies authStateChanges stream', () async {
      await authRepository.signUpWithEmailAndPassword(
        email: 'stream@arc.app',
        password: 'password123',
        fullName: 'Stream User',
      );

      expect(authRepository.currentUser, isNotNull);

      final authStates = <auth.User?>[];
      final subscription = authRepository.authStateChanges().listen(authStates.add);

      await authRepository.signOut();
      expect(authRepository.currentUser, isNull);

      await Future.delayed(Duration.zero);
      expect(authStates.last, isNull);

      await subscription.cancel();
    });

    test('AuthException translates various Firebase error codes to friendly strings', () {
      final exc1 = AuthException.fromFirebase(auth.FirebaseAuthException(code: 'user-not-found'));
      expect(exc1.message, equals('No account found with this email address.'));

      final exc2 = AuthException.fromFirebase(auth.FirebaseAuthException(code: 'wrong-password'));
      expect(exc2.message, equals('Incorrect password. Please try again.'));

      final exc3 = AuthException.fromFirebase(auth.FirebaseAuthException(code: 'invalid-credential'));
      expect(exc3.message, equals('Invalid email or password. Please verify your credentials.'));

      final exc4 = AuthException.fromFirebase(auth.FirebaseAuthException(code: 'network-request-failed'));
      expect(exc4.message, contains('Network connection error'));

      final exc5 = AuthException.fromFirebase(auth.FirebaseAuthException(code: 'operation-not-allowed'));
      expect(exc5.message, contains('Firebase Console'));
    });
  });
}
