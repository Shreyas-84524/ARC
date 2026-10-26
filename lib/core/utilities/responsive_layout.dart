import 'package:flutter/material.dart';

/// Centralized responsive layout utility for Project Arc.
/// Provides dynamic grid aspect ratios and horizontal screen padding helpers.
class ResponsiveLayout {
  // Breakpoints
  static const double smallPhoneThreshold = 360.0;
  static const double widePhoneThreshold = 600.0;

  /// Returns adaptive horizontal screen padding (16px on small screens, 20px on standard, 24px on wide screens).
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < smallPhoneThreshold) return 16.0;
    if (width >= widePhoneThreshold) return 24.0;
    return 20.0;
  }

  /// Returns adaptive grid aspect ratio for 2-column metric cards.
  /// On small screens (< 360px width), provides a taller ratio (1.05 - 1.15) to prevent vertical text overflow.
  static double gridAspectRatio(BuildContext context, {double defaultRatio = 1.25}) {
    final width = MediaQuery.of(context).size.width;
    if (width < 320) return 1.0;
    if (width < smallPhoneThreshold) return 1.1;
    if (width >= widePhoneThreshold) return 1.4;
    return defaultRatio;
  }
}
