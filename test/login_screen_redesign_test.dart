import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/user_management/views/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget() {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const LoginScreen(),
      ),
    );
  }

  testWidgets('LoginScreen displays title, placeholders, green Sign In button, Forgot Password and Sign Up links', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. Verify Title and Subtitle
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Enter your email and password to access your account'), findsOneWidget);

    // 2. Verify Email Label and Placeholder
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('name@example.com'), findsOneWidget);

    // 3. Verify Password Label and Placeholder
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    // 4. Verify Remember me is absent and Forgot Password link is present
    expect(find.text('Remember me'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Forgot Password?'), findsOneWidget);

    // 5. Verify Sign Up link is present
    expect(find.text('Sign Up'), findsOneWidget);

    // 6. Verify Sign In Button is present and uses AppColors.accent green background
    final buttonFinder = find.widgetWithText(ElevatedButton, 'Sign In');
    expect(buttonFinder, findsOneWidget);
    final buttonWidget = tester.widget<ElevatedButton>(buttonFinder);
    expect(buttonWidget.style?.backgroundColor?.resolve({}), AppColors.accent);

    // 7. Verify both fields are empty initially
    final emailField = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'name@example.com'),
        matching: find.byType(EditableText),
      ),
    );
    expect(emailField.controller.text, isEmpty);

    final passwordField = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Enter your password'),
        matching: find.byType(EditableText),
      ),
    );
    expect(passwordField.controller.text, isEmpty);
  });

  testWidgets('Sign In button activates only when both fields are filled', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final buttonFinder = find.widgetWithText(ElevatedButton, 'Sign In');
    ElevatedButton button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNull); // Disabled when fields are empty

    // Fill Email
    await tester.enterText(
      find.widgetWithText(TextFormField, 'name@example.com'),
      'shreyas@example.com',
    );
    await tester.pump();

    button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNull); // Still disabled (password empty)

    // Fill Password
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      '123456',
    );
    await tester.pump();

    button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNotNull); // Enabled when both fields are filled!
  });

  testWidgets('Invalid credential entry displays error message', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Enter invalid email and password
    await tester.enterText(
      find.widgetWithText(TextFormField, 'name@example.com'),
      'UnknownUser99',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'password123',
    );
    await tester.pump();

    // Tap Sign In
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    // Verify error message is displayed
    expect(find.text('Invalid username'), findsOneWidget);
    // Verify list of allowed usernames is NOT revealed anywhere
    expect(find.textContaining('Allowed users:'), findsNothing);
  });
}
