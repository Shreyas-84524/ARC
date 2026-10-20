import 'package:flutter_test/flutter_test.dart';
import 'package:arc/core/utils/greeting_utils.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/models/user_context.dart';

void main() {
  group('Dashboard Greeting & User-Specific Logic Unit Tests', () {
    test('TEST 1: Shreyas produces "Good Morning, Shreyas" at 9 AM', () {
      final now = DateTime(2026, 8, 24, 9, 0); // 9:00 AM (Morning)
      final greeting = GreetingUtils.getGreetingTitle(
        title: 'Dashboard',
        username: 'Shreyas',
        now: now,
      );
      expect(greeting, equals('Good Morning, Shreyas'));
    });

    test('TEST 2: Aman produces "Good Morning, Aman" at 10 AM, "Good Afternoon, Aman" at 2 PM', () {
      final morningTime = DateTime(2026, 8, 24, 10, 0);
      final afternoonTime = DateTime(2026, 8, 24, 14, 0);

      final morningGreeting = GreetingUtils.getGreetingTitle(
        title: 'Dashboard',
        username: 'Aman',
        now: morningTime,
      );
      final afternoonGreeting = GreetingUtils.getGreetingTitle(
        title: 'Dashboard',
        username: 'Aman',
        now: afternoonTime,
      );

      expect(morningGreeting, equals('Good Morning, Aman'));
      expect(afternoonGreeting, equals('Good Afternoon, Aman'));
    });

    test('TEST 3: Rohit, Sachi, and Yash greetings match dynamically across time periods', () {
      final knownUsers = ['Rohit', 'Sachi', 'Yash'];

      // Morning (8 AM), Afternoon (1 PM), Evening (6 PM), Night (10 PM)
      final morning = DateTime(2026, 8, 24, 8, 0);
      final afternoon = DateTime(2026, 8, 24, 13, 0);
      final evening = DateTime(2026, 8, 24, 18, 0);
      final night = DateTime(2026, 8, 24, 22, 0);

      for (final username in knownUsers) {
        expect(
          GreetingUtils.getGreetingTitle(title: 'Dashboard', username: username, now: morning),
          equals('Good Morning, $username'),
        );
        expect(
          GreetingUtils.getGreetingTitle(title: 'Dashboard', username: username, now: afternoon),
          equals('Good Afternoon, $username'),
        );
        expect(
          GreetingUtils.getGreetingTitle(title: 'Dashboard', username: username, now: evening),
          equals('Good Evening, $username'),
        );
        expect(
          GreetingUtils.getGreetingTitle(title: 'Dashboard', username: username, now: night),
          equals('Good Night, $username'),
        );
      }
    });

    test('TEST 4: Restored session user profile generates correct greeting after app restart', () {
      final profile = UserProfile(
        id: 'uid_aman_persistent',
        username: 'Aman',
        displayName: 'Aman',
        email: 'aman@arc.app',
        createdAt: DateTime.now(),
      );
      final context = UserContext(userId: profile.id, profile: profile, isInitializing: false);

      final morning = DateTime(2026, 8, 24, 9, 30);
      final restoredGreeting = GreetingUtils.getGreetingTitle(
        title: 'Dashboard',
        username: context.profile?.displayName ?? context.profile?.username,
        now: morning,
      );

      expect(restoredGreeting, equals('Good Morning, Aman'));
    });

    test('TEST 5: Switching user from Shreyas to Aman does not leave Shreyas cached or fallback', () {
      final shreyasProfile = UserProfile(
        id: 'uid_shreyas',
        username: 'Shreyas',
        displayName: 'Shreyas',
        email: 'shreyas@arc.app',
        createdAt: DateTime.now(),
      );

      final amanProfile = UserProfile(
        id: 'uid_aman',
        username: 'Aman',
        displayName: 'Aman',
        email: 'aman@arc.app',
        createdAt: DateTime.now(),
      );

      final morning = DateTime(2026, 8, 24, 9, 0);

      // User 1: Shreyas
      var activeContext = UserContext(userId: shreyasProfile.id, profile: shreyasProfile);
      var greeting = GreetingUtils.getGreetingTitle(
        title: 'Dashboard',
        username: activeContext.profile?.displayName ?? activeContext.profile?.username,
        now: morning,
      );
      expect(greeting, equals('Good Morning, Shreyas'));

      // Logout -> Legacy Context
      activeContext = UserContext.legacy;
      greeting = GreetingUtils.getGreetingTitle(
        title: 'Dashboard',
        username: activeContext.profile?.displayName ?? activeContext.profile?.username,
        now: morning,
      );
      expect(greeting, equals('Good Morning'));
      expect(greeting.contains('Shreyas'), isFalse);

      // User 2: Aman
      activeContext = UserContext(userId: amanProfile.id, profile: amanProfile);
      greeting = GreetingUtils.getGreetingTitle(
        title: 'Dashboard',
        username: activeContext.profile?.displayName ?? activeContext.profile?.username,
        now: morning,
      );
      expect(greeting, equals('Good Morning, Aman'));
      expect(greeting.contains('Shreyas'), isFalse);
    });

    test('FALLBACK: Unauthenticated/initializing context returns neutral greeting without fallback name', () {
      final morning = DateTime(2026, 8, 24, 9, 0);
      final afternoon = DateTime(2026, 8, 24, 15, 0);
      final evening = DateTime(2026, 8, 24, 19, 0);
      final night = DateTime(2026, 8, 24, 23, 0);

      expect(GreetingUtils.getGreetingTitle(title: 'Dashboard', username: null, now: morning), equals('Good Morning'));
      expect(GreetingUtils.getGreetingTitle(title: 'Dashboard', username: '', now: morning), equals('Good Morning'));

      expect(GreetingUtils.getGreetingTitle(title: 'Dashboard', username: null, now: afternoon), equals('Good Afternoon'));
      expect(GreetingUtils.getGreetingTitle(title: 'Dashboard', username: null, now: evening), equals('Good Evening'));
      expect(GreetingUtils.getGreetingTitle(title: 'Dashboard', username: null, now: night), equals('Good Night'));
    });

    test('NON-DASHBOARD: Returns title as-is for non-Dashboard screens', () {
      expect(GreetingUtils.getGreetingTitle(title: 'Task Manager', username: 'Aman'), equals('Task Manager'));
      expect(GreetingUtils.getGreetingTitle(title: 'Money Tracker', username: 'Shreyas'), equals('Money Tracker'));
      expect(GreetingUtils.getGreetingTitle(title: 'Habit Tracker', username: 'Rohit'), equals('Habit Tracker'));
    });
  });
}
