import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:arc/features/money_tracker/models/money_automation_raw_event.dart';

/// Platform bridge contract for local Android SMS listener capabilities.
abstract class MoneyAutomationPlatformBridge {
  /// Whether the host platform supports local SMS/notification listening.
  bool get isPlatformSupported;

  /// Checks if the runtime permission (RECEIVE_SMS) is granted.
  Future<bool> checkPermission();

  /// Requests the runtime permission from the user.
  /// Returns: 'granted', 'denied', or 'permanentlyDenied'.
  Future<String> requestPermission();

  /// Directs the user to the application's details settings page in Android OS.
  Future<void> openAppSettings();

  /// Informs the native bridge whether automation is enabled by the active user.
  Future<void> setListenerEnabled(bool enabled);

  /// Real-time stream of incoming eligible raw events.
  Stream<MoneyAutomationRawEvent> get eventStream;
}

/// Default implementation utilizing Flutter's [MethodChannel] and [EventChannel].
class MethodChannelMoneyAutomationBridge implements MoneyAutomationPlatformBridge {
  static const MethodChannel _methodChannel = MethodChannel('com.arc.arc/money_automation');
  static const EventChannel _eventChannel = EventChannel('com.arc.arc/money_automation_events');

  Stream<MoneyAutomationRawEvent>? _broadcastStream;

  @override
  bool get isPlatformSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> checkPermission() async {
    if (!isPlatformSupported) return false;
    try {
      final bool? granted = await _methodChannel.invokeMethod<bool>('checkPermission');
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('MethodChannelMoneyAutomationBridge: checkPermission error: $e');
      return false;
    }
  }

  @override
  Future<String> requestPermission() async {
    if (!isPlatformSupported) return 'unsupported';
    try {
      final String? result = await _methodChannel.invokeMethod<String>('requestPermission');
      return result ?? 'denied';
    } on MissingPluginException {
      return 'unsupported';
    } catch (e) {
      debugPrint('MethodChannelMoneyAutomationBridge: requestPermission error: $e');
      return 'error';
    }
  }

  @override
  Future<void> openAppSettings() async {
    if (!isPlatformSupported) return;
    try {
      await _methodChannel.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('MethodChannelMoneyAutomationBridge: openAppSettings error: $e');
    }
  }

  @override
  Future<void> setListenerEnabled(bool enabled) async {
    if (!isPlatformSupported) return;
    try {
      await _methodChannel.invokeMethod('setListenerEnabled', {'enabled': enabled});
    } on MissingPluginException {
      // Ignored on unsupported platforms
    } catch (e) {
      debugPrint('MethodChannelMoneyAutomationBridge: setListenerEnabled error: $e');
    }
  }

  @override
  Stream<MoneyAutomationRawEvent> get eventStream {
    if (!isPlatformSupported) {
      return const Stream.empty();
    }

    _broadcastStream ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) => MoneyAutomationRawEvent.fromMap(event as Map<dynamic, dynamic>))
        .asBroadcastStream();

    return _broadcastStream!;
  }
}
