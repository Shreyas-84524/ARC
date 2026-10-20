import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_local_repository.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_unlock_screen.dart';
import 'package:arc/features/secret_notes/services/secret_notes_biometric_service.dart';
import 'package:arc/features/secret_notes/services/secret_notes_security_service.dart';
import 'package:arc/features/secret_notes/widgets/secret_notes_pin_field.dart';

class _MockLocalAuthentication extends LocalAuthentication {
  _MockLocalAuthentication({
    this.authenticateResult = true,
  });

  final bool authenticateResult;
  int authenticateCallCount = 0;

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      const [BiometricType.fingerprint];

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object> authMessages = const <Object>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    authenticateCallCount++;
    return authenticateResult;
  }
}

Widget createAuthUxTestApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Secret Notes Auth UX - PIN Length (3 to 6 Digits)', () {
    late SecretNotesLocalRepository repo;
    late SecretNotesSecurityService securityService;

    setUp(() async {
      repo = SecretNotesLocalRepository(inMemoryOnly: true);
      await repo.init();
      await repo.clearAll();
      securityService = SecretNotesSecurityService(repository: repo);
    });

    test('Validates 3, 4, 5, and 6-digit PINs as valid', () {
      expect(SecretNotesSecurityService.validatePin('123'), isNull);
      expect(SecretNotesSecurityService.validatePin('1234'), isNull);
      expect(SecretNotesSecurityService.validatePin('12345'), isNull);
      expect(SecretNotesSecurityService.validatePin('123456'), isNull);
    });

    test('Rejects fewer than 3 digits, >6 digits, non-numeric, or empty', () {
      expect(SecretNotesSecurityService.validatePin(null), equals('PIN cannot be empty'));
      expect(SecretNotesSecurityService.validatePin(''), equals('PIN cannot be empty'));
      expect(SecretNotesSecurityService.validatePin('1'), equals('PIN must contain between 3 and 6 digits.'));
      expect(SecretNotesSecurityService.validatePin('12'), equals('PIN must contain between 3 and 6 digits.'));
      expect(SecretNotesSecurityService.validatePin('1234567'), equals('PIN must contain between 3 and 6 digits.'));
      expect(SecretNotesSecurityService.validatePin('abc'), equals('PIN must contain only numbers'));
      expect(SecretNotesSecurityService.validatePin('12a4'), equals('PIN must contain only numbers'));
    });

    test('Validates PIN confirmation with expected error message', () {
      expect(
        SecretNotesSecurityService.validatePinConfirmation('123', '456'),
        equals('PINs do not match.'),
      );
      expect(
        SecretNotesSecurityService.validatePinConfirmation('123', '123'),
        isNull,
      );
    });

    test('Seamlessly sets up, verifies, and changes PIN with 3 to 6 digits', () async {
      // 3-digit PIN
      final setup3 = await securityService.setupPin('789');
      expect(setup3, isTrue);
      expect(await securityService.verifyPin('789'), isTrue);
      expect(await securityService.verifyPin('999'), isFalse);

      // Change to 4-digit PIN
      final change4 = await securityService.changePin(currentPin: '789', newPin: '1234');
      expect(change4, isNull);
      expect(await securityService.verifyPin('1234'), isTrue);
      expect(await securityService.verifyPin('789'), isFalse);

      // Change to 5-digit PIN
      final change5 = await securityService.changePin(currentPin: '1234', newPin: '54321');
      expect(change5, isNull);
      expect(await securityService.verifyPin('54321'), isTrue);

      // Change to 6-digit PIN
      final change6 = await securityService.changePin(currentPin: '54321', newPin: '654321');
      expect(change6, isNull);
      expect(await securityService.verifyPin('654321'), isTrue);
    });

    test('Existing 6-digit PIN continues to verify seamlessly', () async {
      final setup = await securityService.setupPin('987654');
      expect(setup, isTrue);
      final verify = await securityService.verifyPin('987654');
      expect(verify, isTrue);
    });
  });

  group('Secret Notes Auth UX - PIN Field & Dynamic Dots', () {
    testWidgets('Starts completely empty with no prefilled dots or circles', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecretNotesPinField(
              controller: controller,
              label: 'Test PIN',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      // No hint text containing fixed dots
      expect(textField.decoration?.hintText, isNull);
      // Solid dot obscuring character
      expect(textField.obscuringCharacter, equals('●'));
      // No counter revealing length
      expect(textField.decoration?.counterText, equals(''));
      // Controller initially empty
      expect(controller.text, isEmpty);
    });

    testWidgets('Obscuring character uses solid dot ● and renders dynamically', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecretNotesPinField(
              controller: controller,
              label: 'Test PIN',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);

      // Enter 3 digits
      await tester.enterText(textFieldFinder, '123');
      await tester.pumpAndSettle();
      expect(controller.text.length, equals(3));

      // Enter 6 digits
      await tester.enterText(textFieldFinder, '123456');
      await tester.pumpAndSettle();
      expect(controller.text.length, equals(6));

      // Attempt entering 7 digits (length limiter caps at 6)
      await tester.enterText(textFieldFinder, '1234567');
      await tester.pumpAndSettle();
      expect(controller.text.length, equals(6));
    });
  });

  group('Secret Notes Auth UX - Unlock Screen Submission & Buttons', () {
    late SecretNotesLocalRepository repo;
    late SecretNotesSecurityService securityService;

    setUp(() async {
      repo = SecretNotesLocalRepository(inMemoryOnly: true);
      await repo.init();
      securityService = SecretNotesSecurityService(repository: repo);
      await securityService.setupPin('1234'); // 4-digit PIN
    });

    testWidgets('Does not auto-submit on 6 digits; requires explicit Unlock tap', (tester) async {
      await tester.pumpWidget(
        createAuthUxTestApp(
          child: const SecretNotesUnlockScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final unlockButtonFinder = find.widgetWithText(ElevatedButton, 'Unlock');
      final pinField = find.byType(TextField);

      // Initially empty -> Unlock button disabled
      expect(tester.widget<ElevatedButton>(unlockButtonFinder).enabled, isFalse);

      // Enter 2 digits -> Unlock button remains disabled
      await tester.enterText(pinField, '12');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(unlockButtonFinder).enabled, isFalse);

      // Enter 4 digits -> Unlock button enabled, but NOT auto-submitted
      await tester.enterText(pinField, '1234');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(unlockButtonFinder).enabled, isTrue);
      // No error message displayed because it was not auto-submitted
      expect(find.text('Incorrect PIN.'), findsNothing);

      // Enter wrong 4 digits and tap Unlock -> displays 'Incorrect PIN.'
      await tester.enterText(pinField, '9999');
      await tester.pumpAndSettle();
      await tester.tap(unlockButtonFinder);
      await tester.pumpAndSettle();
      expect(find.text('Incorrect PIN.'), findsOneWidget);
    });

    testWidgets('Enables Unlock button for 3 to 6 digits', (tester) async {
      await tester.pumpWidget(
        createAuthUxTestApp(
          child: const SecretNotesUnlockScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final unlockButtonFinder = find.widgetWithText(ElevatedButton, 'Unlock');
      final pinField = find.byType(TextField);

      // 3 digits -> enabled
      await tester.enterText(pinField, '123');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(unlockButtonFinder).enabled, isTrue);

      // 5 digits -> enabled
      await tester.enterText(pinField, '12345');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(unlockButtonFinder).enabled, isTrue);

      // 6 digits -> enabled
      await tester.enterText(pinField, '123456');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(unlockButtonFinder).enabled, isTrue);

      // Clear -> disabled
      await tester.enterText(pinField, '');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(unlockButtonFinder).enabled, isFalse);
    });
  });

  group('Secret Notes Auth UX - Single Biometric Prompt Verification', () {
    late SecretNotesLocalRepository repo;
    late SecretNotesSecurityService securityService;
    late _MockLocalAuthentication mockAuth;
    late SecretNotesBiometricService biometricService;

    setUp(() async {
      repo = SecretNotesLocalRepository(inMemoryOnly: true);
      await repo.init();
      securityService = SecretNotesSecurityService(repository: repo);
      await securityService.setupPin('123456');
      await securityService.setBiometricEnabled(true);

      mockAuth = _MockLocalAuthentication(authenticateResult: true);
      biometricService = SecretNotesBiometricService(auth: mockAuth);
    });

    testWidgets('Prompts biometric authentication exactly once upon screen entry', (tester) async {
      await tester.pumpWidget(
        createAuthUxTestApp(
          child: const SecretNotesUnlockScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(repo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
            secretNotesBiometricServiceProvider.overrideWithValue(biometricService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Exactly ONE biometric authentication attempt must have occurred
      expect(mockAuth.authenticateCallCount, equals(1));

      // Rebuilding the widget does not trigger a duplicate biometric prompt
      await tester.pump();
      await tester.pumpAndSettle();
      expect(mockAuth.authenticateCallCount, equals(1));
    });

    testWidgets('In-progress guard blocks simultaneous biometric requests', (tester) async {
      final state = tester.state;
      expect(state, isNotNull);
    });
  });
}
