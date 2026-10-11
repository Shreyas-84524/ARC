import 'package:firebase_auth/firebase_auth.dart' as auth;

/// Structured, user-friendly exception for authentication operations.
class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  /// Translates FirebaseAuthException or general errors into human-readable messages.
  factory AuthException.fromFirebase(dynamic error) {
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
          return const AuthException(
            'An account already exists with a different sign-in provider. Please sign in with your original provider.',
            code: 'account-exists-with-different-credential',
          );
        case 'credential-already-in-use':
          return const AuthException(
            'This account credential is already linked to another user.',
            code: 'credential-already-in-use',
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
            'Network connection error. Please verify your internet connection.',
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
        case 'cancelled':
          return const AuthException(
            'Sign-in was cancelled.',
            code: 'cancelled',
          );
        case 'auth-limit-reached':
          return const AuthException(
            'Too many login attempts. For security and reliability, ARC allows up to 10 password login attempts every 6 hours.',
            code: 'auth-limit-reached',
          );
        default:
          final cleanMsg = error.message?.trim();
          if (cleanMsg != null && cleanMsg.isNotEmpty) {
            return AuthException(cleanMsg, code: error.code);
          }
          return AuthException(
            'Authentication failed (${error.code}). Please try again.',
            code: error.code,
          );
      }
    }

    if (error is ArgumentError) {
      return AuthException(error.message?.toString() ?? 'Invalid argument.');
    }

    return AuthException(
      error
          .toString()
          .replaceAll('Exception:', '')
          .replaceAll('ArgumentError:', '')
          .replaceAll('StateError:', '')
          .trim(),
    );
  }

  @override
  String toString() => message;
}
