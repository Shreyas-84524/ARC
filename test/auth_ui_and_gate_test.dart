import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/user_management/views/signup_screen.dart';
import 'package:arc/features/user_management/views/forgot_password_screen.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/routes/app_router.dart';

void main() {
  group('SignUpScreen Widget Tests', () {
    testWidgets('Renders all fields, placeholders, icons, and buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const SignUpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create an Account'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Enter your full name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('name@example.com'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('At least 6 characters'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Re-enter your password'), findsOneWidget);

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Sign Up');
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull); // Disabled when fields are empty

      expect(find.text('Already have an account? '), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('Validates password mismatch and activates button when valid', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SignUpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Sign Up');

      // Fill name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your full name'),
        'Test User',
      );
      await tester.pump();

      // Fill email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'name@example.com'),
        'test@example.com',
      );
      await tester.pump();

      // Fill password
      await tester.enterText(
        find.widgetWithText(TextFormField, 'At least 6 characters'),
        'password123',
      );
      await tester.pump();

      // Mismatched confirm password
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Re-enter your password'),
        'different_pass',
      );
      await tester.pump();

      // Button should still be disabled because passwords don't match
      var button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull);

      // Now enter matching password
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Re-enter your password'),
        'password123',
      );
      await tester.pump();

      // Button is now enabled!
      button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Password visibility toggle updates obscure state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const SignUpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially obscured
      final editableTexts = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
      // Password is index 2, Confirm Password is index 3
      expect(editableTexts[2].obscureText, isTrue);
      expect(editableTexts[3].obscureText, isTrue);

      // Toggle first password field
      final iconButtons = find.byType(IconButton);
      await tester.tap(iconButtons.at(0));
      await tester.pump();

      final updatedTexts = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
      expect(updatedTexts[2].obscureText, isFalse);
      expect(updatedTexts[3].obscureText, isTrue);
    });
  });

  group('ForgotPasswordScreen Widget Tests', () {
    testWidgets('Renders form and validates email input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('name@example.com'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.text('Back to Sign In'), findsOneWidget);

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Send Reset Link');
      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull); // Disabled when email is empty

      // Enter valid email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'name@example.com'),
        'user@example.com',
      );
      await tester.pump();

      final enabledButton = tester.widget<ElevatedButton>(buttonFinder);
      expect(enabledButton.onPressed, isNotNull);
    });
  });

  group('Authentication Gate & Router Redirection Tests', () {
    test('Signed-out user attempting to access protected route is redirected to /login', () {
      final container = ProviderContainer(
        overrides: [
          userContextProvider.overrideWith((ref) => UserContextNotifierTestHelper(UserContext.legacy)),
        ],
      );

      final routerNotifier = container.read(routerNotifierProvider);
      final fakeState = FakeGoRouterState('/');

      final redirectResult = routerNotifier.redirect(FakeBuildContext(), fakeState);
      expect(redirectResult, equals('/login'));

      final taskState = FakeGoRouterState('/tasks');
      expect(routerNotifier.redirect(FakeBuildContext(), taskState), equals('/login'));
    });

    test('Signed-out user CAN access /login, /signup, and /forgot-password', () {
      final container = ProviderContainer(
        overrides: [
          userContextProvider.overrideWith((ref) => UserContextNotifierTestHelper(UserContext.legacy)),
        ],
      );

      final routerNotifier = container.read(routerNotifierProvider);

      expect(routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/login')), isNull);
      expect(routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/signup')), isNull);
      expect(routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/forgot-password')), isNull);
    });

    test('Initializing state redirects non-splash routes to /splash', () {
      final container = ProviderContainer(
        overrides: [
          userContextProvider.overrideWith((ref) => UserContextNotifierTestHelper(UserContext.initializing)),
        ],
      );

      final routerNotifier = container.read(routerNotifierProvider);

      expect(routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/')), equals('/splash'));
      expect(routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/splash')), isNull);
    });

    test('Authenticated normal user on auth routes is redirected to Dashboard', () {
      final normalContext = UserContext(
        userId: 'test_uid_123',
        profile: UserProfile(
          id: 'test_uid_123',
          username: 'TestUser',
          displayName: 'Test User',
          email: 'test@arc.app',
          role: 'user',
          createdAt: DateTime.now(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          userContextProvider.overrideWith((ref) => UserContextNotifierTestHelper(normalContext)),
        ],
      );

      final routerNotifier = container.read(routerNotifierProvider);

      expect(routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/login')), equals('/'));
      expect(routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/signup')), equals('/'));
      expect(routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/forgot-password')), equals('/'));
      expect(routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/admin')), equals('/'));
      expect(routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/')), isNull);
    });

    test('Authenticated Administrator is redirected to /admin', () {
      final adminContext = UserContext(
        userId: 'admin_uid_999',
        profile: UserProfile(
          id: 'admin_uid_999',
          username: 'Admin',
          displayName: 'Administrator',
          email: 'admin@arc.app',
          role: 'admin',
          createdAt: DateTime.now(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          userContextProvider.overrideWith((ref) => UserContextNotifierTestHelper(adminContext)),
        ],
      );

      final routerNotifier = container.read(routerNotifierProvider);

      expect(routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/login')), equals('/admin'));
      expect(routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/admin')), isNull);
    });
  });
}

class FakeGoRouterState extends Fake implements GoRouterState {
  final String _path;
  FakeGoRouterState(this._path);

  @override
  Uri get uri => Uri.parse(_path);

  @override
  String get matchedLocation => _path;
}

class UserContextNotifierTestHelper extends UserContextNotifier {
  UserContextNotifierTestHelper(UserContext initialState) : super() {
    state = initialState;
  }
}

class FakeBuildContext extends Fake implements BuildContext {}
