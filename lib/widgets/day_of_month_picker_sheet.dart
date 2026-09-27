import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import 'app_modal_bottom_sheet.dart';

/// ผลการเลือกวันของเดือน: `day == null` หมายถึงผู้ใช้กดล้างค่า
typedef DayOfMonthPick = ({int? day});

const _daysInLongestMonth = 31;
const _gridColumns = 7;

/// Sheet เลือกวันที่ 1-31; คืน null เมื่อปิดโดยไม่เลือก
/// [clearLabel] แสดงปุ่มล้างค่าเมื่อมีค่าเดิมอยู่
Future<DayOfMonthPick?> showDayOfMonthPickerSheet({
  required BuildContext context,
  required String title,
  required int? selectedDay,
  String? clearLabel,
}) {
  return showAppModalBottomSheet<DayOfMonthPick>(
    context: context,
    builder: (sheetContext) => Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final surfaceColor = AppColors.surfaceFor(isDarkMode);
        final textPrimaryColor = AppColors.textPrimaryFor(isDarkMode);
        final textSecondaryColor = AppColors.textSecondaryFor(isDarkMode);
        final selectedColor = isDarkMode
            ? AppColors.darkIncome
            : AppColors.header;
        final clearColor = AppColors.expenseFor(isDarkMode);

        return SafeArea(
          child: Container(
            color: surfaceColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppModalBottomSheetHeader(title: title),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _gridColumns,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: _daysInLongestMonth,
                    itemBuilder: (_, i) {
                      final day = i + 1;
                      final isSelected = selectedDay == day;
                      return Material(
                        color: isSelected
                            ? selectedColor.withValues(alpha: 0.2)
                            : surfaceColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                          side: isSelected
                              ? BorderSide(color: selectedColor, width: 2)
                              : BorderSide(
                                  color: textSecondaryColor.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.pop(sheetContext, (day: day)),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? selectedColor
                                    : textPrimaryColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (clearLabel != null && selectedDay != null)
                  ListTile(
                    tileColor: surfaceColor,
                    title: Text(
                      clearLabel,
                      style: TextStyle(color: clearColor),
                    ),
                    leading: Icon(Icons.delete_outline, color: clearColor),
                    onTap: () => Navigator.pop(sheetContext, (day: null)),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
