import 'package:flutter/material.dart';

class AppColors {
  // Light mode colors
  static const Color header = Color(0xFF393E46);
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

  // Dark mode colors
  static const Color darkHeader = Color(0xFF2C333A);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2A2A2A);
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFFBDBDBD);
  static const Color darkDivider = Color(0xFF424242);
  static const Color darkSectionHeader = Color(0xFF2A2A2A);

  // Slightly adjusted colors for better visibility on dark backgrounds
  static const Color darkIncome = Color(0xFF66BB6A);
  static const Color darkExpense = Color(0xFFEF5350);
  static const Color darkTransfer = Color(0xFF42A5F5);
  static const Color darkFabYellow = Color(0xFFFFCA28);

  static Color amountColor(double amount, {bool isDarkMode = false}) {
    if (isDarkMode) {
      if (amount > 0) return darkIncome;
      if (amount < 0) return darkExpense;
      return darkTextSecondary;
    }
    if (amount > 0) return income;
    if (amount < 0) return expense;
    return textSecondary;
  }

  static Color getAmountColor(double amount, bool isDarkMode) =>
      amountColor(amount, isDarkMode: isDarkMode);

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

  static const List<Color> darkAccountColors = [
    Color(0xFF78909C),
    Color(0xFF66BB6A),
    Color(0xFF42A5F5),
    Color(0xFFFFA726),
    Color(0xFFEC407A),
    Color(0xFFAB47BC),
    Color(0xFFEF5350),
    Color(0xFF26A69A),
    Color(0xFF8D6E63),
    Color(0xFFA1887F),
    Color(0xFF29B6F6),
    Color(0xFF9CCC65),
    Color(0xFFFF7043),
    Color(0xFF1E88E5),
    Color(0xFF26C6DA),
    Color(0xFFD4E157),
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
