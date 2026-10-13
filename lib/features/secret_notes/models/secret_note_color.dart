import 'package:flutter/material.dart';

/// Predefined color option for Secret Notes.
///
/// Stores only the string identifier in the database, avoiding storing UI framework objects.
class SecretNoteColorOption {
  final String id;
  final String name;
  final Color lightBackground;
  final Color darkBackground;
  final Color lightBorder;
  final Color darkBorder;
  final Color dotColor;

  const SecretNoteColorOption({
    required this.id,
    required this.name,
    required this.lightBackground,
    required this.darkBackground,
    required this.lightBorder,
    required this.darkBorder,
    required this.dotColor,
  });

  Color backgroundColor(bool isDark) => isDark ? darkBackground : lightBackground;
  Color borderColor(bool isDark) => isDark ? darkBorder : lightBorder;
}

/// Palette of 8 calm, readable note colors with high contrast in both themes.
class SecretNoteColors {
  SecretNoteColors._();

  static const String defaultColorId = 'default';

  static const List<SecretNoteColorOption> palette = [
    SecretNoteColorOption(
      id: 'default',
      name: 'Default',
      lightBackground: Color(0xFFF9FAFB),
      darkBackground: Color(0xFF1E222A),
      lightBorder: Color(0xFFE5E7EB),
      darkBorder: Color(0xFF333842),
      dotColor: Color(0xFF9CA3AF),
    ),
    SecretNoteColorOption(
      id: 'amber',
      name: 'Amber',
      lightBackground: Color(0xFFFEF3C7),
      darkBackground: Color(0xFF362B15),
      lightBorder: Color(0xFFFDE68A),
      darkBorder: Color(0xFF5E491F),
      dotColor: Color(0xFFF59E0B),
    ),
    SecretNoteColorOption(
      id: 'emerald',
      name: 'Emerald',
      lightBackground: Color(0xFFD1FAE5),
      darkBackground: Color(0xFF132F23),
      lightBorder: Color(0xFFA7F3D0),
      darkBorder: Color(0xFF1E523D),
      dotColor: Color(0xFF10B981),
    ),
    SecretNoteColorOption(
      id: 'sky',
      name: 'Sky',
      lightBackground: Color(0xFFE0F2FE),
      darkBackground: Color(0xFF152A3E),
      lightBorder: Color(0xFFBAE6FD),
      darkBorder: Color(0xFF1E486D),
      dotColor: Color(0xFF0284C7),
    ),
    SecretNoteColorOption(
      id: 'violet',
      name: 'Violet',
      lightBackground: Color(0xFFEDE9FE),
      darkBackground: Color(0xFF271C3D),
      lightBorder: Color(0xFFDDD6FE),
      darkBorder: Color(0xFF45306B),
      dotColor: Color(0xFF8B5CF6),
    ),
    SecretNoteColorOption(
      id: 'rose',
      name: 'Rose',
      lightBackground: Color(0xFFFFE4E6),
      darkBackground: Color(0xFF3B1B24),
      lightBorder: Color(0xFFFECDD3),
      darkBorder: Color(0xFF652939),
      dotColor: Color(0xFFF43F5E),
    ),
    SecretNoteColorOption(
      id: 'orange',
      name: 'Orange',
      lightBackground: Color(0xFFFFEDD5),
      darkBackground: Color(0xFF382314),
      lightBorder: Color(0xFFFED7AA),
      darkBorder: Color(0xFF613B1F),
      dotColor: Color(0xFFF97316),
    ),
    SecretNoteColorOption(
      id: 'teal',
      name: 'Teal',
      lightBackground: Color(0xFFCCFBF1),
      darkBackground: Color(0xFF112F2C),
      lightBorder: Color(0xFF99F6E4),
      darkBorder: Color(0xFF1C524C),
      dotColor: Color(0xFF14B8A6),
    ),
  ];

  static SecretNoteColorOption getById(String? id) {
    if (id == null || id.isEmpty) {
      return palette.first;
    }
    return palette.firstWhere(
      (opt) => opt.id == id,
      orElse: () => palette.first,
    );
  }
}
