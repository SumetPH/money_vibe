import '../../widgets/app_year_selector.dart';
import '../../widgets/app_inset_card.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

class TradeYearSelector extends StatelessWidget {
  final int selectedYear;
  final ValueChanged<int> onYearChanged;

  const TradeYearSelector({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppInsetCard(
      margin: AppInsetCard.stackedMargin,
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
      children: [
        AppYearSelector(
          selectedYear: selectedYear,
          onYearChanged: onYearChanged,
        ),
      ],
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
