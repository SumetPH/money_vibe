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

  static const forest = ThemeColorOption(
    id: 'forest',
    label: 'Forest',
    lightHeader: Color(0xFF315142),
    lightAccent: Color(0xFF527760),
    lightFab: Color(0xFF6F9B69),
    lightOnFab: Colors.white,
    darkHeader: Color(0xFF24332F),
    darkAccent: Color(0xFF7BAE8A),
    darkFab: Color(0xFF8FBF75),
    darkOnFab: Colors.black,
  );

  static const steel = ThemeColorOption(
    id: 'steel',
    label: 'Steel',
    lightHeader: Color(0xFF334A5B),
    lightAccent: Color(0xFF55758D),
    lightFab: Color(0xFF6F8EA5),
    lightOnFab: Colors.white,
    darkHeader: Color(0xFF26323C),
    darkAccent: Color(0xFF7FA6C2),
    darkFab: Color(0xFF8AAFC7),
    darkOnFab: Colors.black,
  );

  static const plum = ThemeColorOption(
    id: 'plum',
    label: 'Plum',
    lightHeader: Color(0xFF4D405B),
    lightAccent: Color(0xFF77628B),
    lightFab: Color(0xFF9279A7),
    lightOnFab: Colors.white,
    darkHeader: Color(0xFF302A3A),
    darkAccent: Color(0xFFA18AB8),
    darkFab: Color(0xFFB095C8),
    darkOnFab: Colors.black,
  );

  static const copper = ThemeColorOption(
    id: 'copper',
    label: 'Copper',
    lightHeader: Color(0xFF5B4433),
    lightAccent: Color(0xFF8A6548),
    lightFab: Color(0xFFB17A4F),
    lightOnFab: Colors.white,
    darkHeader: Color(0xFF352D26),
    darkAccent: Color(0xFFC08A62),
    darkFab: Color(0xFFD39A6A),
    darkOnFab: Colors.black,
  );

  static const values = [classic, forest, steel, plum, copper];

  static ThemeColorOption byId(String? id) {
    for (final option in values) {
      if (option.id == id) return option;
    }
    switch (id) {
      case 'teal':
        return forest;
      case 'blue':
        return steel;
      case 'violet':
        return plum;
    }
    return classic;
  }
}
