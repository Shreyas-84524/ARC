import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// Screen privacy protection dynamically flags the window as SECURE on Android
// to prevent screenshots, screen recording, and Recent Apps exposure of secret notes.

class SecretNotesWindowPrivacyService {
  static const MethodChannel _channel = MethodChannel('com.arc.arc/secure_window');

  bool _isSecure = false;
  bool get isSecure => _isSecure;

  /// Enables FLAG_SECURE on Android while inside Secret Notes.
  /// On Web or unsupported platforms, this fails gracefully without throwing.
  Future<void> enableSecureScreen() async {
    if (kIsWeb) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod<bool>('enableSecure');
        _isSecure = true;
      }
    } catch (e) {
      debugPrint('Secret Notes: secure screen enable notice: $e');
    }
  }

  /// Disables FLAG_SECURE restoring normal window behavior when exiting Secret Notes.
  Future<void> disableSecureScreen() async {
    if (kIsWeb) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod<bool>('disableSecure');
        _isSecure = false;
      }
    } catch (e) {
      debugPrint('Secret Notes: secure screen disable notice: $e');
    }
  }
}
