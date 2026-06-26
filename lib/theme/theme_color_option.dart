import 'package:flutter/material.dart';

class ThemeColorOption {
  final String id;
  final String label;
  final Color lightHeader;
  final Color lightAccent;
  final Color lightFab;
  final Color lightOnFab;
  final Color darkHeader;
  final Color darkAccent;
  final Color darkFab;
  final Color darkOnFab;

  const ThemeColorOption({
    required this.id,
    required this.label,
    required this.lightHeader,
    required this.lightAccent,
    required this.lightFab,
    required this.lightOnFab,
    required this.darkHeader,
    required this.darkAccent,
    required this.darkFab,
    required this.darkOnFab,
  });

  Color header(bool isDarkMode) => isDarkMode ? darkHeader : lightHeader;

  Color accent(bool isDarkMode) => isDarkMode ? darkAccent : lightAccent;

  Color fab(bool isDarkMode) => isDarkMode ? darkFab : lightFab;

  Color onFab(bool isDarkMode) => isDarkMode ? darkOnFab : lightOnFab;

  static const classic = ThemeColorOption(
    id: 'classic',
    label: 'Classic',
    lightHeader: Color(0xFF393E46),
    lightAccent: Color(0xFF393E46),
    lightFab: Color(0xFFFB8C00),
    lightOnFab: Colors.white,
    darkHeader: Color(0xFF2C333A),
    darkAccent: Color(0xFF66BB6A),
    darkFab: Color(0xFFFFB74D),
    darkOnFab: Colors.black,
  );

  static const teal = ThemeColorOption(
    id: 'teal',
    label: 'Teal',
    lightHeader: Color(0xFF00695C),
    lightAccent: Color(0xFF00796B),
    lightFab: Color(0xFF00897B),
    lightOnFab: Colors.white,
    darkHeader: Color(0xFF123A36),
    darkAccent: Color(0xFF4DB6AC),
    darkFab: Color(0xFF4DB6AC),
    darkOnFab: Colors.black,
  );

  static const blue = ThemeColorOption(
    id: 'blue',
    label: 'Blue',
    lightHeader: Color(0xFF1E3A8A),
    lightAccent: Color(0xFF2563EB),
    lightFab: Color(0xFF2563EB),
    lightOnFab: Colors.white,
    darkHeader: Color(0xFF172554),
    darkAccent: Color(0xFF60A5FA),
    darkFab: Color(0xFF60A5FA),
    darkOnFab: Colors.black,
  );

  static const violet = ThemeColorOption(
    id: 'violet',
    label: 'Violet',
    lightHeader: Color(0xFF5B21B6),
    lightAccent: Color(0xFF7C3AED),
    lightFab: Color(0xFF7C3AED),
    lightOnFab: Colors.white,
    darkHeader: Color(0xFF2E1065),
    darkAccent: Color(0xFFC084FC),
    darkFab: Color(0xFFC084FC),
    darkOnFab: Colors.black,
  );

  static const values = [classic, teal, blue, violet];

  static ThemeColorOption byId(String? id) {
    for (final option in values) {
      if (option.id == id) return option;
    }
    return classic;
  }
}
