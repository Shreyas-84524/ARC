import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/user_management/views/login_screen.dart';

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const LoginScreen(),
      ),
    );
  }

  testWidgets('LoginScreen displays title, placeholders, green Sign In button, and no Remember Me / Forgot Password', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. Verify Title and Subtitle
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Enter your email and password to access your account'), findsOneWidget);

    // 2. Verify Username Label and Placeholder
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Enter your username'), findsOneWidget);

    // 3. Verify Password Label and Placeholder
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    // 4. Verify Remember me and Forgot Password options are completely absent
    expect(find.text('Remember me'), findsNothing);
    expect(find.text('Forgot Password'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    // 5. Verify Sign In Button is present and uses AppColors.accent green background
    final buttonFinder = find.widgetWithText(ElevatedButton, 'Sign In');
    expect(buttonFinder, findsOneWidget);
    final buttonWidget = tester.widget<ElevatedButton>(buttonFinder);
    expect(buttonWidget.style?.backgroundColor?.resolve({}), AppColors.accent);

    // 6. Verify both fields are empty initially
    final usernameField = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Enter your username'),
        matching: find.byType(EditableText),
      ),
    );
    expect(usernameField.controller.text, isEmpty);

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

    // Fill Username
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your username'),
      'Shreyas',
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

  testWidgets('Invalid username entry displays ONLY "Invalid username"', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Enter invalid username and password
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your username'),
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

    // Verify ONLY "Invalid username" is displayed
    expect(find.text('Invalid username'), findsOneWidget);
    // Verify list of allowed usernames is NOT revealed anywhere
    expect(find.textContaining('Allowed users:'), findsNothing);
    expect(find.textContaining('Shreyas, Aman'), findsNothing);
  });
}
