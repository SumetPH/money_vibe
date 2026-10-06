import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// แถวเลือกปี: ลูกศรก่อนหน้า/ถัดไป และปีตรงกลาง (18sp w800)
class AppYearSelector extends StatelessWidget {
  final int selectedYear;
  final ValueChanged<int> onYearChanged;

  /// ระยะห่างของปุ่มลูกศรจากขอบซ้าย/ขวา
  final double buttonInset;

  const AppYearSelector({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
    this.buttonInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final secondaryColor = AppColors.textSecondaryFor(isDarkMode);

    return Row(
      children: [
        Padding(
          padding: EdgeInsets.only(left: buttonInset),
          child: IconButton(
            tooltip: 'ปีก่อนหน้า',
            icon: Icon(Icons.chevron_left, color: secondaryColor),
            onPressed: () => onYearChanged(selectedYear - 1),
          ),
        ),
        Expanded(
          child: Text(
            '$selectedYear',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimaryFor(isDarkMode),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(right: buttonInset),
          child: IconButton(
            tooltip: 'ปีถัดไป',
            icon: Icon(Icons.chevron_right, color: secondaryColor),
            onPressed: () => onYearChanged(selectedYear + 1),
          ),
        ),
      ],
    );
  }
}
