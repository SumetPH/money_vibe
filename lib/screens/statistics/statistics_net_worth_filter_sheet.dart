import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import 'statistics_models.dart';

Future<StatisticsNetWorthPeriodFilter?> showStatisticsNetWorthFilterSheet(
  BuildContext context, {
  required bool isDarkMode,
  required StatisticsNetWorthPeriodFilter selectedFilter,
}) {
  return showAppModalBottomSheet<StatisticsNetWorthPeriodFilter>(
    context: context,
    builder: (sheetContext) {
      final textColor = isDarkMode
          ? AppColors.darkTextPrimary
          : AppColors.textPrimary;
      final secondaryColor = isDarkMode
          ? AppColors.darkTextSecondary
          : AppColors.textSecondary;
      final surfaceColor = isDarkMode
          ? AppColors.darkSurface
          : AppColors.surface;
      final dividerColor = isDarkMode
          ? AppColors.darkDivider
          : AppColors.divider;
      final accent = AppColors.accentFor(
        isDarkMode,
        context.read<SettingsProvider>().themeColor,
      );

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppModalBottomSheetHeader(title: 'ช่วงเวลาที่แสดง'),
              Material(
                color: surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.xLarge),
                  side: BorderSide(color: dividerColor.withValues(alpha: 0.4)),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: StatisticsNetWorthPeriodFilter.values.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: AppColors.listDividerFor(isDarkMode),
                  ),
                  itemBuilder: (_, index) {
                    final filter = StatisticsNetWorthPeriodFilter.values[index];
                    final isSelected = filter == selectedFilter;
                    return ListTile(
                      onTap: () => Navigator.pop(sheetContext, filter),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: isSelected ? accent : secondaryColor,
                        size: 22,
                      ),
                      title: Text(
                        filter.label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
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
    },
  );
}
