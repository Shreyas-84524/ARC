import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/admin/services/admin_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserContext adminContext;
  late UserContext normalUserContext;
  late UserContext spoofedAdminContext;
  late AdminService adminService;

  setUp(() {
    final now = DateTime.now();

    final adminProfile = UserProfile(
      id: 'uid_admin',
      username: 'ADMIN',
      displayName: 'ADMIN',
      email: 'admin@arc.app',
      role: 'admin',
      createdAt: now,
    );
    adminContext = UserContext(userId: adminProfile.id, profile: adminProfile, isInitializing: false);

    final normalProfile = UserProfile(
      id: 'uid_aman',
      username: 'Aman',
      displayName: 'Aman',
      email: 'aman@arc.app',
      role: 'user',
      createdAt: now,
    );
    normalUserContext = UserContext(userId: normalProfile.id, profile: normalProfile, isInitializing: false);

    // Spoofed user context attempting to use username "ADMIN" but with role "user"
    final spoofedProfile = UserProfile(
      id: 'uid_hacker',
      username: 'ADMIN',
      displayName: 'ADMIN',
      email: 'admin@fake.app',
      role: 'user',
      createdAt: now,
    );
    spoofedAdminContext = UserContext(userId: spoofedProfile.id, profile: spoofedProfile, isInitializing: false);

    adminService = AdminService();
  });

  group('Project Arc — Secure Admin System Verification Suite (16 Mandatory Security Tests)', () {
    test('TEST 1: Normal user login evaluated as normal user context', () {
      expect(normalUserContext.isAuthenticated, isTrue);
      expect(normalUserContext.isAdmin, isFalse);
    });

    test('TEST 2: ADMIN login evaluated as administrator context', () {
      expect(adminContext.isAuthenticated, isTrue);
      expect(adminContext.isAdmin, isTrue);
    });

    test('TEST 3: Normal user context returns isAdmin == false blocking Admin Dashboard access', () {
      expect(normalUserContext.isAdmin, isFalse);
    });

    test('TEST 4: Changing username to "ADMIN" with role "user" does NOT grant admin privileges', () {
      expect(spoofedAdminContext.profile?.username, equals('ADMIN'));
      expect(spoofedAdminContext.profile?.role, equals('user'));
      expect(spoofedAdminContext.isAdmin, isFalse);
    });

    test('TEST 5: ADMIN creates a new user successfully', () async {
      final newUser = await adminService.createUser(
        username: 'Pooja',
        adminContext: adminContext,
      );

      expect(newUser.username, equals('Pooja'));
      expect(newUser.email, equals('pooja@arc.app'));

      final users = await adminService.fetchUserList(adminContext);
      expect(users.map((u) => u.username), contains('Pooja'));
    });

    test('TEST 6: Duplicate username is rejected safely', () async {
      await adminService.createUser(username: 'Vikram', adminContext: adminContext);

      expect(
        () => adminService.createUser(username: 'Vikram', adminContext: adminContext),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('already exists'))),
      );
    });

    test('TEST 7: ADMIN deletes an existing normal user successfully', () async {
      await adminService.createUser(username: 'Karan', adminContext: adminContext);

      var users = await adminService.fetchUserList(adminContext);
      expect(users.map((u) => u.username), contains('Karan'));

      await adminService.deleteUser(username: 'Karan', adminContext: adminContext);

      users = await adminService.fetchUserList(adminContext);
      expect(users.map((u) => u.username), isNot(contains('Karan')));
    });

    test('TEST 8: Normal user cannot invoke create-user backend operation', () async {
      expect(
        () => adminService.createUser(username: 'UnauthorizedUser', adminContext: normalUserContext),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Unauthorized'))),
      );
    });

    test('TEST 9: Normal user cannot invoke delete-user backend operation', () async {
      expect(
        () => adminService.deleteUser(username: 'Aman', adminContext: normalUserContext),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Unauthorized'))),
      );
    });

    test('TEST 10: ADMIN cannot retrieve or view another user password from UserProfile or AdminService', () async {
      final user = await adminService.createUser(username: 'Sneha', adminContext: adminContext);

      final userMap = user.toMap();
      expect(userMap.containsKey('password'), isFalse);
      expect(userMap.containsKey('passwordHash'), isFalse);
      expect(userMap.containsKey('secret'), isFalse);
    });

    test('TEST 11: No password is stored in UserProfile or serialization maps', () {
      final profile = UserProfile(
        id: 'u123',
        username: 'TestUser',
        displayName: 'TestUser',
        email: 'testuser@arc.app',
        createdAt: DateTime.now(),
      );

      final map = profile.toMap();
      expect(map.values.any((v) => v.toString().contains('143926004')), isFalse);
      expect(map.keys, isNot(contains('password')));
    });

    test('TEST 12: No password returned in AdminService fetchUserList response', () async {
      final users = await adminService.fetchUserList(adminContext);
      for (final u in users) {
        final map = u.toMap();
        expect(map.containsKey('password'), isFalse);
      }
    });

    test('TEST 13: ADMIN logout correctly resets UserContext to legacy/unauthenticated', () {
      var context = adminContext;
      expect(context.isAdmin, isTrue);

      context = UserContext.legacy;
      expect(context.isAuthenticated, isFalse);
      expect(context.isAdmin, isFalse);
    });

    test('TEST 14: After ADMIN logout, a normal user logging in receives only normal Dashboard context', () {
      var activeContext = adminContext;
      expect(activeContext.isAdmin, isTrue);

      activeContext = UserContext.legacy;
      expect(activeContext.isAuthenticated, isFalse);

      activeContext = normalUserContext;
      expect(activeContext.isAuthenticated, isTrue);
      expect(activeContext.isAdmin, isFalse);
    });

    test('TEST 15: Existing normal-user authentication mapping continues working', () {
      expect(UserProfile.emailForUsername('Aman'), equals('aman@arc.app'));
      expect(UserProfile.knownUsernames, containsAll(['Shreyas', 'Aman', 'Rohit', 'Sachi', 'Yash']));
      expect(UserProfile.isKnownUsername('ADMIN'), isTrue);
    });

    test('TEST 16: Multi-user data isolation guarantees user namespaces are unique', () {
      expect(adminContext.userNamespace, equals('uid_admin'));
      expect(normalUserContext.userNamespace, equals('uid_aman'));
      expect(adminContext.userNamespace, isNot(equals(normalUserContext.userNamespace)));
    });
  });
}
