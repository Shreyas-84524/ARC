import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/user_management/services/auth_service.dart';
import 'helpers/mock_firebase_auth.dart';

void main() {
  group('Phase 11 — Authentication & Password Change Test Suite', () {
    late MockFirebaseAuth mockAuth;
    late AuthService authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      authService = AuthService(firebaseAuth: mockAuth);
    });

    test('TEST 1 — Correct Username + Correct Password succeeds via Firebase Auth', () async {
      // First login creates the user account in Firebase Auth
      final profile1 = await authService.loginWithUsername(
        username: 'Shreyas',
        password: 'password123',
      );

      expect(profile1.username, equals('Shreyas'));
      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser!.uid, equals('uid_shreyas'));

      // Logout and re-login with correct password
      await authService.logout();
      expect(mockAuth.currentUser, isNull);

      final profile2 = await authService.loginWithUsername(
        username: 'Shreyas',
        password: 'password123',
      );
      expect(profile2.username, equals('Shreyas'));
      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser!.uid, equals('uid_shreyas'));
    });

    test('TEST 2 — Correct Username + Wrong Password fails authentication', () async {
      // Account created during initial signup
      await authService.loginWithUsername(
        username: 'Shreyas',
        password: 'correct_password',
      );

      await authService.logout();
      expect(mockAuth.currentUser, isNull);

      // Attempt login with wrong password
      expect(
        () => authService.loginWithUsername(
          username: 'Shreyas',
          password: 'wrong_password',
        ),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', equals('Invalid password.'))),
      );

      // Verify user remains unauthenticated
      expect(mockAuth.currentUser, isNull);
    });

    test('TEST 3 — Invalid Username fails immediately', () async {
      expect(
        () => authService.loginWithUsername(
          username: 'NonExistentUser',
          password: 'password123',
        ),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', equals('Invalid username.'))),
      );
      expect(mockAuth.currentUser, isNull);
    });

    test('TEST 4 & 5 — Empty Username & Empty Password validation', () async {
      expect(
        authService.loginWithUsername(
          username: '',
          password: 'password123',
        ),
        throwsArgumentError,
      );

      expect(
        authService.loginWithUsername(
          username: 'Shreyas',
          password: '',
        ),
        throwsArgumentError,
      );
    });

    test('TEST 6 — Correct Password After Previous Failed Attempt succeeds', () async {
      // Provision account
      await authService.loginWithUsername(username: 'Shreyas', password: 'my_secret_pass');
      await authService.logout();

      // Failed attempt
      try {
        await authService.loginWithUsername(username: 'Shreyas', password: 'bad_password');
      } catch (_) {}
      expect(mockAuth.currentUser, isNull);

      // Retrying with correct password succeeds
      final profile = await authService.loginWithUsername(username: 'Shreyas', password: 'my_secret_pass');
      expect(profile.username, equals('Shreyas'));
      expect(mockAuth.currentUser, isNotNull);
    });

    test('TEST 7 — Change Password successfully updates Firebase Auth', () async {
      await authService.loginWithUsername(username: 'Shreyas', password: 'old_password_123');
      expect(mockAuth.currentUser, isNotNull);

      await authService.changePassword(
        currentPassword: 'old_password_123',
        newPassword: 'new_secure_password_456',
      );

      // Verify current user is still authenticated
      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.userPasswords['shreyas@arc.app'], equals('new_secure_password_456'));
    });

    test('TEST 8 — Wrong Current Password fails password change', () async {
      await authService.loginWithUsername(username: 'Shreyas', password: 'old_password_123');

      expect(
        () => authService.changePassword(
          currentPassword: 'wrong_current_password',
          newPassword: 'new_secure_password_456',
        ),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', equals('Current password is incorrect.'))),
      );

      // Password remains unchanged
      expect(mockAuth.userPasswords['shreyas@arc.app'], equals('old_password_123'));
    });

    test('TEST 9 — New Password Validation fails if password < 6 characters', () async {
      await authService.loginWithUsername(username: 'Shreyas', password: 'old_password_123');

      expect(
        () => authService.changePassword(
          currentPassword: 'old_password_123',
          newPassword: '123',
        ),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('at least 6 characters'))),
      );
    });

    test('TEST 10 & 11 — Old Password fails and New Password succeeds after Change Password', () async {
      await authService.loginWithUsername(username: 'Shreyas', password: 'original_pass');
      await authService.changePassword(
        currentPassword: 'original_pass',
        newPassword: 'updated_pass_99',
      );

      await authService.logout();

      // TEST 10: Old password MUST fail
      expect(
        () => authService.loginWithUsername(username: 'Shreyas', password: 'original_pass'),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', equals('Invalid password.'))),
      );
      expect(mockAuth.currentUser, isNull);

      // TEST 11: New password MUST succeed
      final profile = await authService.loginWithUsername(username: 'Shreyas', password: 'updated_pass_99');
      expect(profile.username, equals('Shreyas'));
      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser!.uid, equals('uid_shreyas'));
    });

    test('TEST 12 — Password Change Does Not Break Session', () async {
      final profile = await authService.loginWithUsername(username: 'Shreyas', password: 'pass_before_change');
      final initialUid = profile.id;

      await authService.changePassword(
        currentPassword: 'pass_before_change',
        newPassword: 'pass_after_change',
      );

      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser!.uid, equals(initialUid));
    });

    test('TEST 13 & 14 — Explicit Logout and Re-login after Password Change', () async {
      await authService.loginWithUsername(username: 'Shreyas', password: 'password_v1');
      await authService.changePassword(currentPassword: 'password_v1', newPassword: 'password_v2');

      // TEST 13: Explicit Logout works normally
      await authService.logout();
      expect(mockAuth.currentUser, isNull);

      // TEST 14: Login after logout succeeds with new password
      final profile = await authService.loginWithUsername(username: 'Shreyas', password: 'password_v2');
      expect(profile.username, equals('Shreyas'));
      expect(mockAuth.currentUser, isNotNull);
    });

    test('TEST 15 — User Isolation (Changing User A password does NOT affect User B)', () async {
      // Provision User A (Shreyas) and User B (Aman)
      await authService.loginWithUsername(username: 'Shreyas', password: 'shreyas_pass_1');
      await authService.logout();

      await authService.loginWithUsername(username: 'Aman', password: 'aman_pass_1');
      await authService.logout();

      // Login as User A and change password
      await authService.loginWithUsername(username: 'Shreyas', password: 'shreyas_pass_1');
      await authService.changePassword(currentPassword: 'shreyas_pass_1', newPassword: 'shreyas_pass_2');
      await authService.logout();

      // User B password should remain aman_pass_1
      final amanProfile = await authService.loginWithUsername(username: 'Aman', password: 'aman_pass_1');
      expect(amanProfile.username, equals('Aman'));
      expect(mockAuth.currentUser!.uid, equals('uid_aman'));

      // User A new password should work
      await authService.logout();
      final shreyasProfile = await authService.loginWithUsername(username: 'Shreyas', password: 'shreyas_pass_2');
      expect(shreyasProfile.username, equals('Shreyas'));
      expect(mockAuth.currentUser!.uid, equals('uid_shreyas'));
    });
  });
}
