import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/services/auth_service.dart';

void main() {
  group('Step 4 Option A Authentication & User Mapping Tests', () {
    final authService = AuthService();

    test('Option A maps usernames to internal email identities correctly', () {
      expect(authService.getInternalEmail('Shreyas'), equals('shreyas@arc.app'));
      expect(authService.getInternalEmail('Aman'), equals('aman@arc.app'));
      expect(authService.getInternalEmail('Rohit'), equals('rohit@arc.app'));
      expect(authService.getInternalEmail('Sachi'), equals('sachi@arc.app'));
      expect(authService.getInternalEmail('Yash'), equals('yash@arc.app'));
    });

    test('All 5 mandatory usernames exist in knownUsernames', () {
      expect(UserProfile.knownUsernames, containsAll(['Shreyas', 'Aman', 'Rohit', 'Sachi', 'Yash']));
      expect(UserProfile.knownUsernames.length, equals(5));
    });

    test('AuthService loginWithUsername fallback handles invalid username gracefully', () async {
      expect(
        () => authService.loginWithUsername(username: 'UnknownUser', password: '123'),
        throwsArgumentError,
      );
    });

    test('AuthService loginWithUsername creates valid UserProfile for Shreyas', () async {
      final profile = await authService.loginWithUsername(
        username: 'Shreyas',
        password: '123456',
      );

      expect(profile.username, equals('Shreyas'));
      expect(profile.email, equals('shreyas@arc.app'));
      expect(profile.id, startsWith('arc_uid_'));
    });

    test('AuthService loginWithUsername creates valid UserProfile for Aman', () async {
      final profile = await authService.loginWithUsername(
        username: 'Aman',
        password: '123456',
      );

      expect(profile.username, equals('Aman'));
      expect(profile.email, equals('aman@arc.app'));
    });
  });
}
