import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Delivers consistent app haptics while preserving each existing call site's
/// original feedback strength.
abstract final class AppHaptics {
  static const MethodChannel _channel = MethodChannel('com.arc.arc/haptics');

  static Future<void> selectionClick() =>
      _trigger(type: 'selectionClick', fallback: HapticFeedback.selectionClick);

  static Future<void> lightImpact() =>
      _trigger(type: 'lightImpact', fallback: HapticFeedback.lightImpact);

  static Future<void> mediumImpact() =>
      _trigger(type: 'mediumImpact', fallback: HapticFeedback.mediumImpact);

  static Future<void> heavyImpact() =>
      _trigger(type: 'heavyImpact', fallback: HapticFeedback.heavyImpact);

  static Future<void> _trigger({
    required String type,
    required Future<void> Function() fallback,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      await fallback();
      return;
    }

    try {
      // A false result means Android deliberately suppressed the pulse because
      // system haptics are disabled or no vibrator is present. Do not override
      // that user/device decision with the Flutter fallback.
      final handled = await _channel.invokeMethod<bool>('vibrate', {
        'type': type,
      });
      if (handled != null) return;
    } on MissingPluginException {
      // Keeps tests and non-standard Android embeddings functional.
    } on PlatformException {
      // Fall back to Flutter's system feedback if the native pulse fails.
    }

    await fallback();
  }
}
