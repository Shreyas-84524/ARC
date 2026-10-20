import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/user_management/models/auth_exception.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/services/auth_service.dart';
import 'package:arc/features/user_management/views/login_screen.dart';
import 'package:arc/features/user_management/views/signup_screen.dart';

// Test mock for AuthService to simulate specific exceptions
class MockAuthServiceForErrors extends Fake implements AuthService {
  Exception? errorToThrowOnGoogle;
  UserProfile? userToReturnOnGoogle;

  @override
  Future<UserProfile> signInWithGoogle() async {
    if (errorToThrowOnGoogle != null) {
      throw errorToThrowOnGoogle!;
    }
    return userToReturnOnGoogle ??
        UserProfile(
          id: 'test_google_uid',
          username: 'Google User',
          displayName: 'Google User',
          email: 'googleuser@arc.app',
          authProvider: 'google',
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<UserProfile> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return UserProfile(
      id: 'test_uid',
      username: fullName,
      displayName: fullName,
      email: email,
      authProvider: 'password',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<UserProfile> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return UserProfile(
      id: 'test_uid',
      username: 'Test User',
      displayName: 'Test User',
      email: email,
      authProvider: 'password',
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Google Sign-In AuthException Mapping Unit Tests', () {
    test('ApiException: 10 maps to configuration-error with user-friendly message', () {
      final rawPlatformException = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 10: ',
        details: null,
      );

      final authException = AuthException.fromFirebase(rawPlatformException);

      expect(authException.code, equals('configuration-error'));
      expect(
        authException.message,
        equals("Google sign-in isn't configured correctly for this app build. Please update ARC or contact support."),
      );
      expect(authException.diagnostic, contains('verify package name and SHA certificate'));
      // Raw exception must not leak into user message
      expect(authException.message, isNot(contains('ApiException')));
      expect(authException.message, isNot(contains('PlatformException')));
      expect(authException.message, isNot(contains('com.google')));
    });

    test('DEVELOPER_ERROR string maps to configuration-error', () {
      final error = Exception('DEVELOPER_ERROR: 10');
      final authException = AuthException.fromFirebase(error);

      expect(authException.code, equals('configuration-error'));
      expect(
        authException.message,
        equals("Google sign-in isn't configured correctly for this app build. Please update ARC or contact support."),
      );
    });

    test('Cancellation (12501 / sign_in_canceled) maps to cancelled code', () {
      final cancel12501 = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 12501: ',
      );
      final ex1 = AuthException.fromFirebase(cancel12501);
      expect(ex1.code, equals('cancelled'));
      expect(ex1.message, equals('Google sign-in was cancelled.'));

      final cancelCanceled = PlatformException(
        code: 'sign_in_canceled',
        message: 'The user canceled the sign-in flow.',
      );
      final ex2 = AuthException.fromFirebase(cancelCanceled);
      expect(ex2.code, equals('cancelled'));
      expect(ex2.message, equals('Google sign-in was cancelled.'));
    });

    test('Network errors map to network-error', () {
      final networkPlatformEx = PlatformException(
        code: 'network_error',
        message: 'A network error occurred.',
      );
      final ex1 = AuthException.fromFirebase(networkPlatformEx);
      expect(ex1.code, equals('network-error'));
      expect(
        ex1.message,
        equals('Unable to connect to Google. Check your internet connection and try again.'),
      );

      final networkApiException = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 7: ',
      );
      final ex2 = AuthException.fromFirebase(networkApiException);
      expect(ex2.code, equals('network-error'));
      expect(
        ex2.message,
        equals('Unable to connect to Google. Check your internet connection and try again.'),
      );
    });

    test('Google Play Services unavailable or outdated maps correctly', () {
      final playServicesEx = PlatformException(
        code: 'sign_in_failed',
        message: 'Google Play Services service_version_update_required (ApiException: 2)',
      );
      final ex = AuthException.fromFirebase(playServicesEx);
      expect(ex.code, equals('play-services-unavailable'));
      expect(
        ex.message,
        equals('Google Play Services is unavailable or needs to be updated.'),
      );
    });

    test('Firebase invalid-credential maps to friendly credentials message', () {
      final credException = auth.FirebaseAuthException(
        code: 'invalid-credential',
        message: 'The custom token format is incorrect.',
      );
      final ex = AuthException.fromFirebase(credException);
      expect(ex.code, equals('invalid-credential'));
      expect(
        ex.message,
        equals('Invalid email or password. Please verify your credentials.'),
      );
    });

    test('Raw unhandled PlatformException never leaks raw class names', () {
      final unknownPlatformEx = PlatformException(
        code: 'unexpected_native_failure',
        message: 'com.google.android.gms.internal.something.FatalCrash',
      );
      final ex = AuthException.fromFirebase(unknownPlatformEx);
      expect(ex.message, equals("Google sign-in couldn't be completed. Please try again."));
      expect(ex.message, isNot(contains('PlatformException')));
      expect(ex.message, isNot(contains('FatalCrash')));
      expect(ex.message, isNot(contains('com.google')));
    });
  });

  group('LoginScreen and SignUpScreen Google Error Handling Widget Tests', () {
    late MockAuthServiceForErrors mockAuthService;

    setUp(() {
      mockAuthService = MockAuthServiceForErrors();
    });

    Widget createTestApp(Widget home) {
      return ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: home,
        ),
      );
    }

    testWidgets('LoginScreen displays user-friendly banner on ApiException: 10 without leaking raw exception', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockAuthService.errorToThrowOnGoogle = AuthException.fromFirebase(
        PlatformException(
          code: 'sign_in_failed',
          message: 'com.google.android.gms.common.api.ApiException: 10: ',
        ),
      );

      await tester.pumpWidget(createTestApp(LoginScreen(authService: mockAuthService)));
      await tester.pumpAndSettle();

      final googleButton = find.text('Continue with Google');
      expect(googleButton, findsOneWidget);

      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      // Ensure user-friendly message is displayed
      expect(
        find.text("Google sign-in isn't configured correctly for this app build. Please update ARC or contact support."),
        findsOneWidget,
      );

      // Verify no raw exception leaks
      expect(find.textContaining('PlatformException'), findsNothing);
      expect(find.textContaining('ApiException'), findsNothing);
      expect(find.textContaining('com.google'), findsNothing);
    });

    testWidgets('LoginScreen suppresses error banner when user cancels Google Sign-In', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockAuthService.errorToThrowOnGoogle = AuthException.fromFirebase(
        PlatformException(
          code: 'sign_in_canceled',
          message: 'The user canceled the sign-in flow.',
        ),
      );

      await tester.pumpWidget(createTestApp(LoginScreen(authService: mockAuthService)));
      await tester.pumpAndSettle();

      final googleButton = find.text('Continue with Google');
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      // No error banner should be displayed for cancellation
      expect(find.text('Google sign-in was cancelled.'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      // No raw platform exception
      expect(find.textContaining('PlatformException'), findsNothing);
    });

    testWidgets('SignUpScreen displays user-friendly banner on network error during Google Sign-In', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockAuthService.errorToThrowOnGoogle = AuthException.fromFirebase(
        PlatformException(
          code: 'network_error',
          message: 'Network error occurred.',
        ),
      );

      await tester.pumpWidget(createTestApp(SignUpScreen(authService: mockAuthService)));
      await tester.pumpAndSettle();

      final googleButton = find.text('Sign up with Google');
      expect(googleButton, findsOneWidget);

      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to connect to Google. Check your internet connection and try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('PlatformException'), findsNothing);
    });

    testWidgets('SignUpScreen suppresses error banner on popup closed / cancelled', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockAuthService.errorToThrowOnGoogle = const AuthException(
        'Google sign-in was cancelled.',
        code: 'cancelled',
      );

      await tester.pumpWidget(createTestApp(SignUpScreen(authService: mockAuthService)));
      await tester.pumpAndSettle();

      final googleButton = find.text('Sign up with Google');
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(find.text('Google sign-in was cancelled.'), findsNothing);
    });
  });

  group('Profile Idempotency & User Preservation Tests', () {
    test('UserProfile preserves existing UID and properties across serialization', () {
      final profile = UserProfile(
        id: 'uid_shreyas_123',
        username: 'shreyas',
        displayName: 'Shreyas S',
        email: 'shigwanshreyas4@gmail.com',
        authProvider: 'password',
        role: 'admin',
        createdAt: DateTime(2026, 1, 1),
        lastLoginAt: DateTime.now(),
      );

      final map = profile.toMap();
      expect(map['id'], equals('uid_shreyas_123'));
      expect(map['email'], equals('shigwanshreyas4@gmail.com'));
      expect(map['role'], equals('admin'));
      expect(map['authProvider'], equals('password'));

      final restored = UserProfile.fromMap(map);
      expect(restored.id, equals('uid_shreyas_123'));
      expect(restored.email, equals('shigwanshreyas4@gmail.com'));
      expect(restored.role, equals('admin'));
      expect(restored.authProvider, equals('password'));
    });
  });
}
