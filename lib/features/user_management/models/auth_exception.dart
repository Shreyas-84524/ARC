import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

/// Structured, user-friendly exception for authentication operations.
class AuthException implements Exception {
  final String message;
  final String? code;
  final String? diagnostic;

  const AuthException(this.message, {this.code, this.diagnostic});

  /// Translates FirebaseAuthException, PlatformException, or general errors into human-readable messages.
  factory AuthException.fromFirebase(dynamic error) {
    if (error is AuthException) {
      return error;
    }

    // 1. Handle PlatformException (e.g. from GoogleSignIn on Android / iOS)
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final msg = (error.message ?? '').toLowerCase();
      final details = (error.details?.toString() ?? '').toLowerCase();
      final combined = '$code $msg $details';

      // ApiException: 10 / DEVELOPER_ERROR (misconfiguration)
      if (combined.contains('10') &&
          (combined.contains('apiexception') ||
              combined.contains('developer_error') ||
              combined.contains(': 10'))) {
        return const AuthException(
          "Google sign-in isn't configured correctly for this app build. Please update ARC or contact support.",
          code: 'configuration-error',
          diagnostic:
              'Google Sign-In configuration error: verify package name and SHA certificate.',
        );
      }

      // User cancellation (12501, 16, sign_in_canceled, popup closed, etc.)
      if (code == 'sign_in_canceled' ||
          code == 'canceled' ||
          code == 'cancelled' ||
          combined.contains('12501') ||
          combined.contains('16') ||
          combined.contains('closed by user')) {
        return const AuthException(
          'Google sign-in was cancelled.',
          code: 'cancelled',
          diagnostic: 'Google Sign-In was cancelled by the user.',
        );
      }

      // Network issues (code 7, network_error, etc.)
      if (code == 'network_error' ||
          combined.contains('network') ||
          combined.contains('connection') ||
          combined.contains('apiexception: 7')) {
        return const AuthException(
          'Unable to connect to Google. Check your internet connection and try again.',
          code: 'network-error',
          diagnostic: 'Google Sign-In network error.',
        );
      }

      // Google Play Services unavailable / outdated (code 1, 2, 3, 9, etc.)
      if (combined.contains('service_missing') ||
          combined.contains('service_version_update_required') ||
          combined.contains('service_disabled') ||
          combined.contains('service_invalid') ||
          combined.contains('apiexception: 1') ||
          combined.contains('apiexception: 2') ||
          combined.contains('apiexception: 3') ||
          combined.contains('apiexception: 9')) {
        return const AuthException(
          'Google Play Services is unavailable or needs to be updated.',
          code: 'play-services-unavailable',
          diagnostic:
              'Google Play Services is missing, disabled, or requires an update.',
        );
      }

      // Popup blocked (Web)
      if (combined.contains('popup') &&
          (combined.contains('block') || combined.contains('closed'))) {
        return const AuthException(
          'Sign-in popup was blocked by your browser. Please allow popups and try again.',
          code: 'popup-blocked',
          diagnostic: 'Web browser blocked or closed the sign-in popup.',
        );
      }

      // Generic developer error
      if (combined.contains('developer_error') ||
          combined.contains('misconfigured')) {
        return const AuthException(
          "Google sign-in isn't configured correctly for this app build. Please update ARC or contact support.",
          code: 'configuration-error',
          diagnostic: 'Google Sign-In configuration error: developer error.',
        );
      }

      // Fallback for PlatformException - never display raw PlatformException(...) to user
      return const AuthException(
        "Google sign-in couldn't be completed. Please try again.",
        code: 'google-sign-in-failed',
        diagnostic: 'PlatformException during Google Sign-In.',
      );
    }

    // 2. Handle FirebaseAuthException
    if (error is auth.FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return const AuthException(
            'No account found with this email address.',
            code: 'user-not-found',
          );
        case 'wrong-password':
          return const AuthException(
            'Incorrect password. Please try again.',
            code: 'wrong-password',
          );
        case 'invalid-credential':
          return const AuthException(
            'Invalid email or password. Please verify your credentials.',
            code: 'invalid-credential',
          );
        case 'email-already-in-use':
          return const AuthException(
            'An account already exists with this email address.',
            code: 'email-already-in-use',
          );
        case 'account-exists-with-different-credential':
        case 'credential-already-in-use':
          return const AuthException(
            'This email is already associated with another sign-in method.',
            code: 'account-exists-with-different-credential',
          );
        case 'weak-password':
          return const AuthException(
            'Password is too weak. Please use at least 6 characters.',
            code: 'weak-password',
          );
        case 'invalid-email':
          return const AuthException(
            'The email address is invalid. Please check the format.',
            code: 'invalid-email',
          );
        case 'user-disabled':
          return const AuthException(
            'This user account has been disabled by an administrator.',
            code: 'user-disabled',
          );
        case 'too-many-requests':
          return const AuthException(
            'Too many failed attempts. Please wait a few moments and try again.',
            code: 'too-many-requests',
          );
        case 'network-request-failed':
          return const AuthException(
            'Network connection error. Check your internet connection and try again.',
            code: 'network-request-failed',
          );
        case 'operation-not-allowed':
          return const AuthException(
            'This authentication method is not enabled in Firebase Console.',
            code: 'operation-not-allowed',
          );
        case 'requires-recent-login':
          return const AuthException(
            'This action requires recent authentication. Please sign in again to continue.',
            code: 'requires-recent-login',
          );
        case 'popup-closed-by-user':
          return const AuthException(
            'Google sign-in was cancelled.',
            code: 'popup-closed-by-user',
          );
        case 'popup-blocked':
          return const AuthException(
            'Sign-in popup was blocked by your browser. Please allow popups and try again.',
            code: 'popup-blocked',
          );
        case 'cancelled':
          return const AuthException(
            'Google sign-in was cancelled.',
            code: 'cancelled',
          );
        case 'auth-limit-reached':
          return const AuthException(
            'Too many login attempts. For security and reliability, ARC allows up to 10 password login attempts every 6 hours.',
            code: 'auth-limit-reached',
          );
        default:
          final cleanMsg = error.message?.trim();
          if (cleanMsg != null &&
              cleanMsg.isNotEmpty &&
              !cleanMsg.contains('Exception') &&
              !cleanMsg.contains('com.google')) {
            return AuthException(cleanMsg, code: error.code);
          }
          return AuthException(
            'Authentication failed. Please try again.',
            code: error.code,
          );
      }
    }

    if (error is ArgumentError) {
      return AuthException(error.message?.toString() ?? 'Invalid argument.');
    }

    // 3. Fallback for strings or general exceptions - inspect for raw platform leak
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('10') &&
        (errorStr.contains('apiexception') ||
            errorStr.contains('developer_error') ||
            errorStr.contains(': 10'))) {
      return const AuthException(
        "Google sign-in isn't configured correctly for this app build. Please update ARC or contact support.",
        code: 'configuration-error',
        diagnostic:
            'Google Sign-In configuration error: verify package name and SHA certificate.',
      );
    }

    if (errorStr.contains('network') || errorStr.contains('socketexception')) {
      return const AuthException(
        'Unable to connect to Google. Check your internet connection and try again.',
        code: 'network-error',
      );
    }

    if (errorStr.contains('cancel')) {
      return const AuthException(
        'Google sign-in was cancelled.',
        code: 'cancelled',
      );
    }

    // Never expose raw exception strings or stack traces
    if (errorStr.contains('platformexception') ||
        errorStr.contains('apiexception') ||
        errorStr.contains('firebaseauthexception') ||
        errorStr.contains('com.google')) {
      return const AuthException(
        "Google sign-in couldn't be completed. Please try again.",
        code: 'google-sign-in-failed',
      );
    }

    final cleaned = error
        .toString()
        .replaceAll('Exception:', '')
        .replaceAll('ArgumentError:', '')
        .replaceAll('StateError:', '')
        .trim();

    if (cleaned.isEmpty ||
        cleaned.contains('Exception') ||
        cleaned.contains('com.')) {
      return const AuthException(
        'Authentication failed. Please try again.',
        code: 'unknown',
      );
    }

    return AuthException(cleaned);
  }

  @override
  String toString() => message;
}
