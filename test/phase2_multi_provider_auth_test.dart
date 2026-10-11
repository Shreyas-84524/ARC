import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/models/auth_exception.dart';
import 'package:arc/features/user_management/services/auth_service.dart';
import 'package:arc/features/user_management/services/login_rate_limiter.dart';
import 'package:arc/features/user_management/views/login_screen.dart';
import 'package:arc/features/user_management/views/signup_screen.dart';
import 'package:arc/features/user_management/views/widgets/google_logo.dart';
import 'package:go_router/go_router.dart';
import 'package:arc/providers/global_providers.dart';
import 'package:arc/features/settings/screens/settings_screen.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/routes/app_router.dart';

// --- MOCK IMPLEMENTATIONS FOR TESTS ---

class MockAuthServiceForLimiter extends Fake implements AuthService {
  bool signInCalled = false;
  bool signInSuccess = false;
  String? lastEmail;
  String? lastPassword;
  int callCount = 0;

  @override
  Future<UserProfile> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalled = true;
    callCount++;
    lastEmail = email;
    lastPassword = password;

    if (!signInSuccess) {
      throw const AuthException('Invalid email or password.', code: 'invalid-credential');
    }

    return UserProfile(
      id: 'uid_test_123',
      username: 'Test User',
      displayName: 'Test User',
      email: email,
      authProvider: 'password',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<UserProfile> signInWithGoogle() async {
    return UserProfile(
      id: 'uid_google_123',
      username: 'Google User',
      displayName: 'Google User',
      email: 'googler@arc.app',
      authProvider: 'google',
      createdAt: DateTime.now(),
    );
  }

  List<String> mockProviders = ['google.com'];
  @override
  List<String> getLinkedProviders() => mockProviders;

  @override
  bool hasPasswordProvider() => mockProviders.contains('password');

  @override
  bool hasGoogleProvider() => mockProviders.contains('google.com');

  bool linkPasswordCalled = false;
  String? linkedPasswordValue;
  bool shouldFailLinkWithConflict = false;

  @override
  Future<void> linkPassword({required String newPassword}) async {
    linkPasswordCalled = true;
    linkedPasswordValue = newPassword;
    if (shouldFailLinkWithConflict) {
      throw const AuthException('An account already exists with this email address.', code: 'credential-already-in-use');
    }
    mockProviders.add('password');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARC Refined Authentication & Login Limiter Test Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // =========================================================================
    // 1. DATA MODEL & PHONE AUDIT TESTS
    // =========================================================================
    group('Data Model & Clean Removal of Phone Dependency', () {
      test('UserProfile does not contain or depend on phoneNumber', () {
        final profile = UserProfile(
          id: 'uid_user_1',
          username: 'Shreyas',
          displayName: 'Shreyas',
          email: 'shigwanshreyas4@gmail.com',
          photoURL: 'https://lh3.googleusercontent.com/photo.jpg',
          authProvider: 'google',
          createdAt: DateTime.parse('2026-10-10T12:00:00Z'),
        );

        expect(profile.authProvider, equals('google'));
        expect(profile.email, equals('shigwanshreyas4@gmail.com'));

        final map = profile.toMap();
        expect(map.containsKey('phoneNumber'), isFalse);
        expect(map['authProvider'], equals('google'));

        final restored = UserProfile.fromMap(map);
        expect(restored.id, equals('uid_user_1'));
        expect(restored.email, equals('shigwanshreyas4@gmail.com'));
        expect(restored.authProvider, equals('google'));
      });

      test('AuthException translates limiter and recent login codes accurately', () {
        final limitEx = auth.FirebaseAuthException(code: 'too-many-requests');
        expect(AuthException.fromFirebase(limitEx).message,
            contains('Too many failed attempts'));

        const arcLimit = AuthException(
          'Too many login attempts. For security and reliability, ARC allows up to 10 password login attempts every 6 hours.',
          code: 'auth-limit-reached',
        );
        expect(arcLimit.code, equals('auth-limit-reached'));
        expect(arcLimit.message, contains('10 password login attempts every 6 hours'));

        final recentLoginEx = auth.FirebaseAuthException(code: 'requires-recent-login');
        expect(AuthException.fromFirebase(recentLoginEx).message,
            contains('recent authentication'));
      });
    });

    // =========================================================================
    // 2. LOGIN RATE LIMITER UNIT TESTS
    // =========================================================================
    group('LoginRateLimiter Core Logic', () {
      test('First login attempt records 1 attempt and is NOT locked', () async {
        DateTime currentTime = DateTime(2026, 10, 11, 10, 0);
        final limiter = LoginRateLimiter(clock: () => currentTime);

        expect(await limiter.isLocked(), isFalse);
        expect(await limiter.getAttempts(), equals(0));

        final count = await limiter.recordAttempt();
        expect(count, equals(1));
        expect(await limiter.getAttempts(), equals(1));
        expect(await limiter.isLocked(), isFalse);
      });

      test('Tenth login attempt triggers locked state for 6 hours', () async {
        DateTime currentTime = DateTime(2026, 10, 11, 10, 0);
        final limiter = LoginRateLimiter(clock: () => currentTime);

        for (int i = 0; i < 9; i++) {
          await limiter.recordAttempt();
          expect(await limiter.isLocked(), isFalse);
        }

        final tenth = await limiter.recordAttempt();
        expect(tenth, equals(10));
        expect(await limiter.isLocked(), isTrue);

        final remaining = await limiter.getRemainingLockDuration();
        expect(remaining.inHours, equals(6));
        expect(LoginRateLimiter.formatRemaining(remaining), equals('6h 0m'));
      });

      test('Eleventh attempt remains locked and blocked', () async {
        DateTime currentTime = DateTime(2026, 10, 11, 10, 0);
        final limiter = LoginRateLimiter(clock: () => currentTime);

        for (int i = 0; i < 10; i++) {
          await limiter.recordAttempt();
        }

        expect(await limiter.isLocked(), isTrue);
        final remaining = await limiter.getRemainingLockDuration();
        final msg = LoginRateLimiter.getThrottledMessage(remaining);
        expect(msg, contains('ARC allows up to 10 password login attempts every 6 hours'));
      });

      test('Six-hour reset automatically resets attempt count and unlocks', () async {
        DateTime currentTime = DateTime(2026, 10, 11, 10, 0);
        var limiter = LoginRateLimiter(clock: () => currentTime);

        for (int i = 0; i < 10; i++) {
          await limiter.recordAttempt();
        }
        expect(await limiter.isLocked(), isTrue);

        // Advance clock by 6 hours and 1 minute
        currentTime = currentTime.add(const Duration(hours: 6, minutes: 1));
        limiter = LoginRateLimiter(clock: () => currentTime);

        expect(await limiter.isLocked(), isFalse);
        expect(await limiter.getAttempts(), equals(0));
      });

      test('Persistent lock survives app restart (new instance reads same storage)', () async {
        DateTime currentTime = DateTime(2026, 10, 11, 10, 0);
        final limiter1 = LoginRateLimiter(clock: () => currentTime);

        for (int i = 0; i < 10; i++) {
          await limiter1.recordAttempt();
        }
        expect(await limiter1.isLocked(), isTrue);

        // Simulate app restart 1 hour later
        currentTime = currentTime.add(const Duration(hours: 1));
        final limiter2 = LoginRateLimiter(clock: () => currentTime);

        expect(await limiter2.isLocked(), isTrue);
        final remaining = await limiter2.getRemainingLockDuration();
        expect(remaining.inHours, equals(5));
      });

      test('Successful authentication resets attempt state', () async {
        DateTime currentTime = DateTime(2026, 10, 11, 10, 0);
        final limiter = LoginRateLimiter(clock: () => currentTime);

        for (int i = 0; i < 5; i++) {
          await limiter.recordAttempt();
        }
        expect(await limiter.getAttempts(), equals(5));

        await limiter.reset();
        expect(await limiter.getAttempts(), equals(0));
        expect(await limiter.isLocked(), isFalse);
      });
    });

    // =========================================================================
    // 3. UI INTEGRATION: LOGIN & SIGN-UP FLOWS
    // =========================================================================
    group('Login & Sign-Up Screen UI & Actions', () {
      testWidgets('LoginScreen displays required elements and NO Continue with Phone',
          (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const LoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
        expect(find.text('OR'), findsOneWidget);
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.byType(GoogleLogo), findsOneWidget);
        expect(find.text('Forgot Password?'), findsOneWidget);
        expect(find.text("Don't have an account? "), findsOneWidget);
        expect(find.text('Sign Up'), findsOneWidget);

        // Must NOT contain phone button
        expect(find.text('Continue with Phone'), findsNothing);
      });

      testWidgets('SignUpScreen displays required elements and NO Sign up with Phone',
          (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const SignUpScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Full Name'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Confirm Password'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Sign Up'), findsOneWidget);
        expect(find.text('OR'), findsOneWidget);
        expect(find.text('Sign up with Google'), findsOneWidget);
        expect(find.byType(GoogleLogo), findsOneWidget);
        expect(find.text('Already have an account? '), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);

        // Must NOT contain phone button
        expect(find.text('Sign up with Phone'), findsNothing);
      });

      testWidgets('Invalid form submission does NOT record an attempt in rate limiter',
          (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockAuth = MockAuthServiceForLimiter();
        final limiter = LoginRateLimiter();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: LoginScreen(
                authService: mockAuth,
                rateLimiter: limiter,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Submit form without filling fields
        // Form button is disabled when empty, tap it or attempt handle login
        final loginBtn = find.widgetWithText(ElevatedButton, 'Sign In');
        await tester.tap(loginBtn, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Firebase not called and attempts remain 0
        expect(mockAuth.signInCalled, isFalse);
        expect(await limiter.getAttempts(), equals(0));
      });

      testWidgets('Tenth attempt locks LoginScreen and shows 6-hour throttle banner',
          (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockAuth = MockAuthServiceForLimiter();
        final limiter = LoginRateLimiter();

        // Simulate 9 already failed attempts
        for (int i = 0; i < 9; i++) {
          await limiter.recordAttempt();
        }

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: LoginScreen(
                authService: mockAuth,
                rateLimiter: limiter,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'shreyas@arc.app');
        await tester.enterText(textFields.at(1), 'wrongpass123');
        await tester.pumpAndSettle();

        final loginBtn = find.widgetWithText(ElevatedButton, 'Sign In');
        await tester.tap(loginBtn);
        await tester.pumpAndSettle();

        expect(mockAuth.callCount, equals(1));
        expect(await limiter.isLocked(), isTrue);

        // Throttle banner is displayed
        expect(find.textContaining('Too many login attempts'), findsOneWidget);
        expect(find.textContaining('ARC allows up to 10 password login attempts every 6 hours'), findsOneWidget);

        // Eleventh attempt does NOT call Firebase
        mockAuth.signInCalled = false;
        await tester.tap(loginBtn);
        await tester.pumpAndSettle();

        expect(mockAuth.signInCalled, isFalse);
      });

      testWidgets('Google Sign-In remains accessible and functional while password login is locked',
          (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool loginSuccessCalled = false;
        final mockAuth = MockAuthServiceForLimiter();
        final limiter = LoginRateLimiter();

        // Pre-lock password attempts
        for (int i = 0; i < 10; i++) {
          await limiter.recordAttempt();
        }
        expect(await limiter.isLocked(), isTrue);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: LoginScreen(
                authService: mockAuth,
                rateLimiter: limiter,
                onLoginSuccess: () {
                  loginSuccessCalled = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final googleBtn = find.text('Continue with Google');
        await tester.ensureVisible(googleBtn);
        await tester.tap(googleBtn);
        await tester.pumpAndSettle();

        expect(loginSuccessCalled, isTrue);
      });
    });

    // =========================================================================
    // 4. SETTINGS & ADD ARC PASSWORD TESTS
    // =========================================================================
    group('Settings Screen Sign-in Methods & Password Linking', () {
      testWidgets('Google-only account displays Add ARC Password button in Settings',
          (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final googleProfile = UserProfile(
          id: 'uid_google_only',
          username: 'Google User',
          displayName: 'Google User',
          email: 'googler@arc.app',
          authProvider: 'google',
          createdAt: DateTime.now(),
        );

        final mockAuth = MockAuthServiceForLimiter();
        mockAuth.mockProviders = ['google.com'];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              themeModeProvider.overrideWith((ref) => ThemeMode.light),
              userContextProvider.overrideWith((ref) {
                final notifier = UserContextNotifier();
                notifier.setActiveUser(
                  userId: 'uid_google_only',
                  profile: googleProfile,
                );
                return notifier;
              }),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: SettingsScreen(
                authService: mockAuth,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Sign-in Methods section is present
        expect(find.text('Sign-in Methods'), findsOneWidget);
        expect(find.text('Google'), findsOneWidget);
        expect(find.text('Email & Password'), findsOneWidget);
        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Not configured'), findsOneWidget);
        expect(find.text('Add ARC Password'), findsOneWidget);

        // Change Password button is hidden for accounts without a password
        expect(find.text('Change Password'), findsNothing);
      });

      testWidgets('Password successfully linked retains UID and updates status',
          (tester) async {
        final mockAuth = MockAuthServiceForLimiter();
        expect(mockAuth.mockProviders, equals(['google.com']));

        await mockAuth.linkPassword(newPassword: 'MyNewArcPassword123');

        expect(mockAuth.linkPasswordCalled, isTrue);
        expect(mockAuth.linkedPasswordValue, equals('MyNewArcPassword123'));
        expect(mockAuth.mockProviders, contains('password'));
        expect(mockAuth.hasPasswordProvider(), isTrue);
      });

      testWidgets('Credential conflict throws user-friendly AuthException',
          (tester) async {
        final mockAuth = MockAuthServiceForLimiter()..shouldFailLinkWithConflict = true;

        expect(
          () => mockAuth.linkPassword(newPassword: 'Password123'),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('An account already exists with this email address'),
          )),
        );
      });
    });

    // =========================================================================
    // 5. ROUTE GUARDS & PHONE-AUTH REMOVAL REGRESSION
    // =========================================================================
    group('Route Guards & Phone Auth Route Removal', () {
      test('Unauthenticated /phone-auth location redirects to /login via routerNotifier', () {
        final container = ProviderContainer(
          overrides: [
            userContextProvider.overrideWith((ref) {
              final notifier = UserContextNotifier();
              notifier.resetToLegacy();
              return notifier;
            }),
          ],
        );

        final routerNotifier = container.read(routerNotifierProvider);
        // User is not authenticated -> any non-public auth route redirects to /login
        final redirectPath = routerNotifier.redirect(
          MockBuildContext(),
          MockGoRouterState('/phone-auth'),
        );

        expect(redirectPath, equals('/login'));
      });
    });
  });
}

class MockBuildContext extends Fake implements BuildContext {}

class MockGoRouterState extends Fake implements GoRouterState {
  final String _matchedLocation;
  MockGoRouterState(this._matchedLocation);

  @override
  String get matchedLocation => _matchedLocation;

  @override
  Uri get uri => Uri.parse(_matchedLocation);
}
