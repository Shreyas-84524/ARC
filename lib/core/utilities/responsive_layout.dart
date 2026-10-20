import 'package:flutter/material.dart';

/// Centralized responsive layout utility for Project Arc.
/// Provides breakpoint checks, dynamic grid aspect ratios, screen padding,
/// and responsive font scaling helpers while preserving design token constraints.
class ResponsiveLayout {
  // Breakpoints
  static const double smallPhoneThreshold = 360.0;
  static const double widePhoneThreshold = 600.0;

  /// Returns true if screen width is less than 360px (small Android phones).
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < smallPhoneThreshold;
  }

  /// Returns true if screen width is 600px or larger (wide phones, foldables, tablets).
  static bool isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= widePhoneThreshold;
  }

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

  /// Clamps font size based on screen width and system accessibility scale factor
  /// to prevent text clipping and overflow on small devices while remaining readable.
  static double fontSize(BuildContext context, double baseSize, {double? min, double? max}) {
    final width = MediaQuery.of(context).size.width;
    final scale = width < smallPhoneThreshold ? 0.9 : (width >= widePhoneThreshold ? 1.1 : 1.0);
    final calculated = baseSize * scale;

    final minVal = min ?? baseSize * 0.8;
    final maxVal = max ?? baseSize * 1.2;

    return calculated.clamp(minVal, maxVal);
  }
}
