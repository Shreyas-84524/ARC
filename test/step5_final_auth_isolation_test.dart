import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/services/auth_service.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';

void main() {
  group('Step 5 Final Authentication, Password & User Isolation Tests', () {
    final authService = AuthService();

    test('AuthService changePassword validates new password length', () async {
      expect(
        () => authService.changePassword(currentPassword: '123456', newPassword: '123'),
        throwsArgumentError,
      );
    });

    test('UserContextNotifier resets user isolation state cleanly on logout', () {
      final notifier = UserContextNotifier();
      notifier.setActiveUser(
        userId: 'shreyas_uid_123',
        profile: UserProfile(
          id: 'shreyas_uid_123',
          username: 'Shreyas',
          displayName: 'Shreyas',
          email: 'shreyas@arc.app',
          createdAt: DateTime.now(),
        ),
      );

      expect(notifier.state.userId, equals('shreyas_uid_123'));
      expect(notifier.state.isLegacy, isFalse);

      notifier.resetToLegacy();
      expect(notifier.state.userId, isNull);
      expect(notifier.state.isLegacy, isTrue);
    });

    test('All 5 users produce distinct user-scoped collection paths', () {
      for (final username in UserProfile.knownUsernames) {
        final uid = 'uid_$username';
        final context = UserContext(userId: uid);
        expect(context.firestoreCollectionPath('tasks'), equals('users/$uid/tasks'));
        expect(context.firestoreCollectionPath('habits'), equals('users/$uid/habits'));
        expect(context.firestoreCollectionPath('transactions'), equals('users/$uid/transactions'));
      }
    });
  });
}
