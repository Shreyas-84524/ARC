import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:arc/features/money_tracker/models/money_automation_listener_status.dart';
import 'package:arc/features/money_tracker/models/money_automation_raw_event.dart';
import 'package:arc/features/money_tracker/services/money_automation_platform_bridge.dart';

/// Service orchestrating the local Android listener lifecycle,
/// health verification, and transient event routing.
class MoneyAutomationListenerService {
  final MoneyAutomationPlatformBridge _bridge;
  StreamSubscription<MoneyAutomationRawEvent>? _subscription;

  MoneyAutomationListenerService({MoneyAutomationPlatformBridge? bridge})
      : _bridge = bridge ?? MethodChannelMoneyAutomationBridge();

  MoneyAutomationPlatformBridge get bridge => _bridge;

  /// Verifies current operational health and permission state.
  Future<MoneyAutomationListenerStatus> checkHealth({required bool isEnabled}) async {
    if (!_bridge.isPlatformSupported) {
      return MoneyAutomationListenerStatus.unavailable;
    }

    if (!isEnabled) {
      return MoneyAutomationListenerStatus.disabled;
    }

    try {
      final hasPermission = await _bridge.checkPermission();
      if (!hasPermission) {
        return MoneyAutomationListenerStatus.permissionRequired;
      }
      return MoneyAutomationListenerStatus.ready;
    } catch (e) {
      debugPrint('[MoneyAutomation] Health check exception: $e');
      return MoneyAutomationListenerStatus.error;
    }
  }

  /// Initiates live event capture when enabled and permitted.
  Future<MoneyAutomationListenerStatus> startListening({
    required void Function(MoneyAutomationRawEvent) onEvent,
  }) async {
    if (!_bridge.isPlatformSupported) {
      return MoneyAutomationListenerStatus.unavailable;
    }

    try {
      final hasPermission = await _bridge.checkPermission();
      if (!hasPermission) {
        return MoneyAutomationListenerStatus.permissionRequired;
      }

      await _bridge.setListenerEnabled(true);
      await _subscription?.cancel();

      _subscription = _bridge.eventStream.listen(
        (event) {
          // Sanitized debug logging: Never print full SMS body, OTPs, or financial details.
          debugPrint('[MoneyAutomation] Transaction event received at ${event.timestamp}');
          onEvent(event);
        },
        onError: (err) {
          debugPrint('[MoneyAutomation] Event stream error: $err');
        },
      );

      debugPrint('[MoneyAutomation] Listener started successfully');
      return MoneyAutomationListenerStatus.ready;
    } catch (e) {
      debugPrint('[MoneyAutomation] Failed to start listener: $e');
      return MoneyAutomationListenerStatus.error;
    }
  }

  /// Halts local listener processing and detaches native triggers.
  Future<MoneyAutomationListenerStatus> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;

    if (_bridge.isPlatformSupported) {
      await _bridge.setListenerEnabled(false);
    }

    debugPrint('[MoneyAutomation] Listener stopped');
    return MoneyAutomationListenerStatus.disabled;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
