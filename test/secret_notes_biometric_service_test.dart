import 'dart:async';
import 'package:arc/features/secret_notes/services/secret_notes_biometric_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

class _FakeLocalAuthentication extends LocalAuthentication {
  _FakeLocalAuthentication({
    required this.canCheck,
    required this.enrolledBiometrics,
    this.authenticationResult = true,
  });

  final bool canCheck;
  final List<BiometricType> enrolledBiometrics;
  final bool authenticationResult;
  bool authenticateCalled = false;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      enrolledBiometrics;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object> authMessages = const <Object>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    authenticateCalled = true;
    return authenticationResult;
  }
}

void main() {
  group('SecretNotesBiometricService', () {
    test('is available when an enrolled biometric can be checked', () async {
      final auth = _FakeLocalAuthentication(
        canCheck: true,
        enrolledBiometrics: const <BiometricType>[BiometricType.fingerprint],
      );
      final service = SecretNotesBiometricService(auth: auth);

      expect(await service.isBiometricAvailable(), isTrue);
    });

    test(
      'is unavailable when hardware exists but nothing is enrolled',
      () async {
        final auth = _FakeLocalAuthentication(
          canCheck: true,
          enrolledBiometrics: const <BiometricType>[],
        );
        final service = SecretNotesBiometricService(auth: auth);

        expect(await service.isBiometricAvailable(), isFalse);
      },
    );

    test('does not authenticate when biometrics are unavailable', () async {
      final auth = _FakeLocalAuthentication(
        canCheck: false,
        enrolledBiometrics: const <BiometricType>[],
      );
      final service = SecretNotesBiometricService(auth: auth);

      expect(await service.authenticate(), isFalse);
      expect(auth.authenticateCalled, isFalse);
    });

    test('returns the biometric prompt result when available', () async {
      final auth = _FakeLocalAuthentication(
        canCheck: true,
        enrolledBiometrics: const <BiometricType>[BiometricType.strong],
        authenticationResult: true,
      );
      final service = SecretNotesBiometricService(auth: auth);

      expect(await service.authenticate(), isTrue);
      expect(auth.authenticateCalled, isTrue);
    });

    test('prevents concurrent or duplicate biometric prompts via in-progress guard', () async {
      final auth = _SlowFakeLocalAuthentication(
        canCheck: true,
        enrolledBiometrics: const <BiometricType>[BiometricType.strong],
      );
      final service = SecretNotesBiometricService(auth: auth);

      // Start first authentication
      final firstAuthFuture = service.authenticate();
      expect(service.isAuthenticating, isTrue);

      // Attempt second authentication while first is still pending
      final secondAuthResult = await service.authenticate();
      expect(secondAuthResult, isFalse); // Guarded!

      // Complete first authentication
      auth.complete();
      final firstAuthResult = await firstAuthFuture;
      expect(firstAuthResult, isTrue);
      expect(service.isAuthenticating, isFalse);
    });
  });
}

class _SlowFakeLocalAuthentication extends _FakeLocalAuthentication {
  _SlowFakeLocalAuthentication({
    required super.canCheck,
    required super.enrolledBiometrics,
  });

  final Completer<bool> _completer = Completer<bool>();

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object> authMessages = const <Object>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    authenticateCalled = true;
    return _completer.future;
  }

  void complete([bool result = true]) {
    if (!_completer.isCompleted) {
      _completer.complete(result);
    }
  }
}
