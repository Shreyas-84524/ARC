import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color darkBg = Color(0xff141414);
  static const Color darkBgSecondary = Color(0xff1B1B1B);
  static const Color darkSurface = Color(0xff202020);
  static const Color darkCard = Color(0xff242424);
  static const Color darkElevated = Color(0xff2A2A2A);
  static const Color darkModal = Color(0xff1E1E1E);

  // Backgrounds - Light (designlight.md: Primary #F9FAFB, Secondary #F3F4F6, Surface/Card/Elevated/Modal #FFFFFF)
  static const Color lightBg = Color(0xFFF9FAFB);
  static const Color lightBgSecondary = Color(0xFFF3F4F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFFFFFFF);
  static const Color lightModal = Color(0xFFFFFFFF);

  // Accent
  static const Color accent = Color(0xffD7FF2F);
  static const Color accentHover = Color(0xffE5FF5C);
  static const Color accentPressed = Color(0xffBCD91F);
  static const Color accentGlow = Color(0x66D7FF2F);
  static const Color darkAccent = Color(0xFF5C7000); // designlight.md: Dark Accent #5C7000 for text/icons requiring contrast

  // Priorities
  static const Color priorityHigh = Color(0xffFF4D4F);
  static const Color priorityMust = Color(0xffFF9F43);
  static const Color priorityMuch = priorityMust;
  static const Color priorityLow = Color(0xffFFC857);

  // Status
  static const Color success = Color(0xff52C41A);
  static const Color info = Color(0xff1890FF);
  static const Color warning = Color(0xffFAAD14);
  static const Color danger = Color(0xffFF4D4F);
  static const Color income = Color(0xff52C41A);

  // Text
  static const Color textPrimaryDark = Color(0xffFFFFFF);
  static const Color textSecondaryDark = Color(0xffD6D6D6);
  static const Color textMutedDark = Color(0xff8A8A8A);
  static const Color textDisabledDark = Color(0xff5A5A5A);
  static const Color textPlaceholderDark = Color(0xff757575);

  // Text - Light (designlight.md: Primary #111827, Secondary #4B5563, Muted #9CA3AF, Disabled #D1D5DB, Placeholder #9CA3AF)
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF4B5563);
  static const Color textMutedLight = Color(0xFF9CA3AF);
  static const Color textDisabledLight = Color(0xFFD1D5DB);
  static const Color textPlaceholderLight = Color(0xFF9CA3AF);

  // Borders
  static const Color borderSubtle = Color(0x0dffffff);
  static const Color borderMedium = Color(0x14ffffff);
  static const Color borderStrong = Color(0x1effffff);

  // Borders - Light (designlight.md: Subtle rgba(0,0,0,0.05) = 0x0D000000, Medium rgba(0,0,0,0.08) = 0x14000000, Strong rgba(0,0,0,0.15) = 0x26000000)
  static const Color borderSubtleLight = Color(0x0D000000);
  static const Color borderMediumLight = Color(0x14000000);
  static const Color borderStrongLight = Color(0x26000000);

  // Shadows - Light (designlight.md)
  static const BoxShadow cardShadowLight = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 20,
    offset: Offset(0, 4),
  );
  static const BoxShadow fabShadowLight = BoxShadow(
    color: Color(0x66D7FF2F),
    blurRadius: 30,
    offset: Offset(0, 12),
  );
  static const BoxShadow modalShadowLight = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 50,
    offset: Offset(0, 20),
  );
  static const BoxShadow dropdownShadowLight = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 30,
    offset: Offset(0, 10),
  );
}

class AppTheme {
  static const double radiusScreen = 40.0;
  static const double radiusCard = 24.0;
  static const double radiusInput = 18.0;
  static const double radiusButton = 16.0;
  static const double radiusPill = 999.0;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: AppColors.accent,
      cardColor: AppColors.darkCard,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryDark,
          letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryDark,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryDark,
        ),
        titleMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark,
        ),
        titleSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimaryDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondaryDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondaryDark,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textMutedDark,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.normal,
          color: AppColors.textDisabledDark,
        ),
      ),
      buttonTheme: const ButtonThemeData(
        buttonColor: AppColors.accent,
        textTheme: ButtonTextTheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textPrimaryLight,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,
          side: const BorderSide(color: AppColors.borderStrong),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        hintStyle: const TextStyle(color: AppColors.textPlaceholderDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: AppColors.borderMedium),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard)),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      primaryColor: AppColors.accent,
      cardColor: AppColors.lightCard,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        onPrimary: AppColors.textPrimaryLight,
        secondary: AppColors.darkAccent,
        onSecondary: Colors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.danger,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryLight,
          letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryLight,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryLight,
        ),
        titleMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
        ),
        titleSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimaryLight,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondaryLight,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondaryLight,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textMutedLight,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.normal,
          color: AppColors.textDisabledLight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textPrimaryLight,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.lightSurface,
          foregroundColor: AppColors.textPrimaryLight,
          side: const BorderSide(color: AppColors.borderMediumLight),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondaryLight,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: AppColors.borderSubtleLight),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        hintStyle: const TextStyle(color: AppColors.textPlaceholderLight),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.borderMediumLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.borderMediumLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.textPrimaryLight, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: AppColors.borderMediumLight),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
      ),
    );
  }
}
