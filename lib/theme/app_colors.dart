import 'package:flutter/material.dart';

class AppColors {
  static const Color header = Color(0xFF1B3548);
  static const Color income = Color(0xFF4CAF50);
  static const Color expense = Color(0xFFF44336);
  static const Color transfer = Color(0xFF2196F3);
  static const Color background = Color(0xFFF0F0F0);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color fabYellow = Color(0xFFFFC107);
  static const Color sectionHeader = Color(0xFFEEEEEE);

  static Color amountColor(double amount) {
    if (amount > 0) return income;
    if (amount < 0) return expense;
    return textSecondary;
  }

  static const List<Color> accountColors = [
    Color(0xFF607D8B),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFFF44336),
    Color(0xFF009688),
    Color(0xFF795548),
    Color(0xFF8D6E63),
    Color(0xFF03A9F4),
    Color(0xFF8BC34A),
    Color(0xFFFF5722),
    Color(0xFF1565C0),
    Color(0xFF00BCD4),
    Color(0xFFCDDC39),
  ];

  static const List<IconData> accountIcons = [
    Icons.account_balance_wallet,
    Icons.account_balance,
    Icons.credit_card,
    Icons.savings,
    Icons.directions_car,
    Icons.home,
    Icons.phone_iphone,
    Icons.show_chart,
    Icons.shopping_bag,
    Icons.local_hospital,
    Icons.school,
    Icons.work,
    Icons.shield,
    Icons.weekend,
    Icons.restaurant,
    Icons.flight,
    Icons.pets,
    Icons.sports_esports,
    Icons.music_note,
    Icons.fitness_center,
  ];
}
