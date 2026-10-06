import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

class TradeInsetCard extends StatelessWidget {
  final bool isDarkMode;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const TradeInsetCard({
    super.key,
    required this.isDarkMode,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xLarge),
          side: BorderSide(color: dividerColor.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class TradeYearSelector extends StatelessWidget {
  final int selectedYear;
  final ValueChanged<int> onYearChanged;
  final bool isDarkMode;

  const TradeYearSelector({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return TradeInsetCard(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: secondaryColor),
                onPressed: () => onYearChanged(selectedYear - 1),
              ),
              Expanded(
                child: Text(
                  '$selectedYear',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: secondaryColor),
                onPressed: () => onYearChanged(selectedYear + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TradeEmptyState extends StatelessWidget {
  final bool isDarkMode;
  final Color textColor;
  final IconData icon;
  final String message;
  final String description;

  const TradeEmptyState({
    super.key,
    required this.isDarkMode,
    required this.textColor,
    this.icon = Icons.show_chart,
    this.message = 'ยังไม่มีประวัติการขาย',
    this.description = 'เมื่อขายหุ้น รายการจะแสดงที่นี่พร้อมกำไร/ขาดทุน',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.darkSurfaceVariant
                    : AppColors.sectionHeader,
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Icon(
                icon,
                color: textColor.withValues(alpha: 0.9),
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
