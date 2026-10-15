/// Represents the operational and permission state of ARC's local transaction listener.
enum MoneyAutomationListenerStatus {
  /// Automatic spending tracking is turned OFF by the user.
  disabled,

  /// Automation is enabled by the user, but necessary Android permission is missing or revoked.
  permissionRequired,

  /// Automation is enabled, permission is granted, and the local listener is active and ready.
  ready,

  /// The current device/platform does not support local SMS/notification listening (e.g. Web, iOS).
  unavailable,

  /// An unexpected error occurred while configuring the local platform listener.
  error,
}

extension MoneyAutomationListenerStatusX on MoneyAutomationListenerStatus {
  String get label {
    switch (this) {
      case MoneyAutomationListenerStatus.disabled:
        return 'Disabled';
      case MoneyAutomationListenerStatus.permissionRequired:
        return 'Permission required';
      case MoneyAutomationListenerStatus.ready:
        return 'Listener ready';
      case MoneyAutomationListenerStatus.unavailable:
        return 'Service unavailable';
      case MoneyAutomationListenerStatus.error:
        return 'Listener error';
    }
  }

  bool get isOperational => this == MoneyAutomationListenerStatus.ready;
  bool get needsPermission => this == MoneyAutomationListenerStatus.permissionRequired;
}
