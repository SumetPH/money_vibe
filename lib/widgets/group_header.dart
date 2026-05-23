import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GroupHeader extends StatelessWidget {
  final String title;
  final bool isDarkMode;
  final List<Widget> trailing;

  const GroupHeader({
    super.key,
    required this.title,
    required this.isDarkMode,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.background;
    final textColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}
