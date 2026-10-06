import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_modal_bottom_sheet.dart';

void showRecurringTypePicker(
  BuildContext context,
  bool isDark, {
  required TransactionType selected,
  required ValueChanged<TransactionType> onSelected,
}) {
  final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;
  final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  final dividerColor = AppColors.borderFor(isDark);
  final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AppDraggableSheet(
      builder: (_, sc) => Column(
        children: [
          const AppModalBottomSheetHeader(title: 'เลือกประเภทรายการ'),
          Expanded(
            child: ListView(
              controller: sc,
              children: TransactionType.values
                  .map(
                    (t) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          tileColor: bgColor,
                          title: Text(
                            t.label,
                            style: TextStyle(color: textColor),
                          ),
                          trailing: selected == t
                              ? Icon(Icons.check, color: selectedColor)
                              : null,
                          onTap: () {
                            onSelected(t);
                            Navigator.pop(context);
                          },
                        ),
                        Divider(height: 1, color: dividerColor),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    ),
  );
}

void showRecurringCategoryPicker(
  BuildContext context,
  List<Category> categories,
  bool isDark, {
  required String? selectedCategoryId,
  required ValueChanged<String?> onSelected,
}) {
  final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;
  final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AppDraggableSheet(
      builder: (_, sc) => Column(
        children: [
          const AppModalBottomSheetHeader(title: 'เลือกหมวดหมู่'),
          // Clear option
          ListTile(
            tileColor: bgColor,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.do_not_disturb, color: Colors.grey, size: 18),
            ),
            title: Text('ไม่ได้เลือก', style: TextStyle(color: textColor)),
            trailing: selectedCategoryId == null
                ? Icon(Icons.check, color: selectedColor)
                : null,
            onTap: () {
              onSelected(null);
              Navigator.pop(context);
            },
          ),
          const AppCardDivider(),
          Expanded(
            child: ListView.separated(
              controller: sc,
              itemCount: categories.length,
              separatorBuilder: (context, i) =>
                  Divider(height: 1, color: AppColors.listDividerFor(isDark)),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final isSelected = selectedCategoryId == cat.id;
                return ListTile(
                  tileColor: bgColor,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 18),
                  ),
                  title: Text(cat.name, style: TextStyle(color: textColor)),
                  trailing: isSelected
                      ? Icon(Icons.check, color: selectedColor)
                      : null,
                  onTap: () {
                    onSelected(cat.id);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

void showRecurringDayOfMonthPicker(
  BuildContext context,
  bool isDark, {
  required int selectedDay,
  required ValueChanged<int> onSelected,
}) {
  final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;
  final textPrimary = isDark
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AppDraggableSheet(
      builder: (_, sc) => Column(
        children: [
          const AppModalBottomSheetHeader(title: 'วันที่ในเดือน'),
          Expanded(
            child: GridView.builder(
              controller: sc,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: 32, // 1-31 + 0 (สิ้นเดือน)
              itemBuilder: (_, i) {
                final day = i; // 0 = สิ้นเดือน, 1-31 = actual day
                final isSelected = selectedDay == day;
                return Material(
                  color: isSelected ? selectedColor : bgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isSelected
                        ? BorderSide.none
                        : BorderSide(
                            color: isDark
                                ? AppColors.darkDivider
                                : AppColors.divider,
                          ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      onSelected(day);
                      Navigator.pop(context);
                    },
                    child: Center(
                      child: Text(
                        day == 0 ? 'สิ้น' : '$day',
                        style: TextStyle(
                          fontSize: day == 0 ? 10 : 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isSelected ? Colors.white : textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Future<TimeOfDay?> showRecurringNotificationTimePicker(
  BuildContext context,
  bool isDark, {
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) {
      final actionColor = isDark ? AppColors.darkIncome : AppColors.header;
      final pickerBg = isDark ? AppColors.darkSurface : AppColors.surface;
      final textColor = isDark
          ? AppColors.darkTextPrimary
          : AppColors.textPrimary;
      final secondaryTextColor = isDark
          ? AppColors.darkTextSecondary
          : AppColors.textSecondary;
      final selectedBg = isDark
          ? AppColors.darkSurfaceVariant
          : AppColors.background;
      final dialTextColor = WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return textColor;
      });
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: isDark ? AppColors.darkHeader : AppColors.header,
            surface: pickerBg,
            onSurface: textColor,
            onPrimary: Colors.white,
          ),
          dialogTheme: DialogThemeData(backgroundColor: pickerBg),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: actionColor),
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: pickerBg,
            hourMinuteColor: selectedBg,
            hourMinuteTextColor: textColor,
            dayPeriodColor: selectedBg,
            dayPeriodTextColor: textColor,
            dayPeriodBorderSide: BorderSide(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
            ),
            dialHandColor: actionColor,
            dialBackgroundColor: selectedBg,
            dialTextColor: dialTextColor,
            entryModeIconColor: actionColor,
            helpTextStyle: TextStyle(color: secondaryTextColor),
            hourMinuteShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? AppColors.darkDivider : AppColors.divider,
              ),
            ),
            dayPeriodShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? AppColors.darkDivider : AppColors.divider,
              ),
            ),
          ),
        ),
        child: child!,
      );
    },
  );
}

const _thaiMonthsShort = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

Future<DateTime?> showRecurringMonthYearPicker(
  BuildContext context,
  DateTime initialDate,
  DateTime firstDate, {
  required bool isEnd,
}) async {
  final isDark = context.read<SettingsProvider>().isDarkMode;
  final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;
  final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

  int selectedYear = initialDate.year;

  return showAppModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setModalState) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with year navigator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setModalState(() => selectedYear--),
                    color: textColor,
                  ),
                  Expanded(
                    child: Text(
                      '${selectedYear + 543}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setModalState(() => selectedYear++),
                    color: textColor,
                  ),
                ],
              ),
            ),
            // Month grid
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.5,
                ),
                itemCount: 12,
                itemBuilder: (_, i) {
                  final month = i + 1;
                  final isSelected =
                      selectedYear == initialDate.year &&
                      month == initialDate.month;
                  return Material(
                    color: isSelected ? selectedColor : bgColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: isSelected
                          ? BorderSide.none
                          : BorderSide(
                              color: isDark
                                  ? AppColors.darkDivider
                                  : AppColors.divider,
                            ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        // For start date, use day 1; for end date, use last day
                        final day = isEnd
                            ? DateTime(selectedYear, month + 1, 0).day
                            : 1;
                        Navigator.pop(
                          context,
                          DateTime(selectedYear, month, day),
                        );
                      },
                      child: Center(
                        child: Text(
                          _thaiMonthsShort[month - 1],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isSelected ? Colors.white : textColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
