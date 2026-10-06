import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_color_option.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import 'settings_widgets.dart';

void showSettingsThemeColorSheet(BuildContext context) {
  showAppModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      final settings = ctx.watch<SettingsProvider>();
      final isDarkMode = settings.isDarkMode;
      final textColor = isDarkMode
          ? AppColors.darkTextPrimary
          : AppColors.textPrimary;
      final secondaryTextColor = isDarkMode
          ? AppColors.darkTextSecondary
          : AppColors.textSecondary;
      return SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: ThemeColorOption.values.length + 1,
          separatorBuilder: (_, index) => index == 0
              ? const SizedBox(height: 4)
              : Divider(height: 1, color: AppColors.listDividerFor(isDarkMode)),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const AppModalBottomSheetHeader(title: 'สีธีม');
            }

            final option = ThemeColorOption.values[index - 1];
            final selected = option.id == settings.themeColor.id;
            return ListTile(
              tileColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              minLeadingWidth: 44,
              leading: SettingsThemeColorSwatch(
                option: option,
                isDarkMode: isDarkMode,
                selected: selected,
              ),
              title: Text(option.label, style: TextStyle(color: textColor)),
              subtitle: selected
                  ? Text(
                      'กำลังใช้งาน',
                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                    )
                  : null,
              trailing: selected
                  ? Icon(
                      Icons.check_circle,
                      color: AppColors.accentFor(isDarkMode, option),
                    )
                  : null,
              onTap: () {
                settings.setThemeColor(option);
                Navigator.pop(ctx);
              },
            );
          },
        ),
      );
    },
  );
}

void showSettingsMonthlyCycleStartDaySheet(BuildContext context) {
  showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final settings = ctx.watch<SettingsProvider>();
      final isDarkMode = settings.isDarkMode;
      final textColor = isDarkMode
          ? AppColors.darkTextPrimary
          : AppColors.textPrimary;
      final dividerColor = isDarkMode
          ? AppColors.darkDivider
          : AppColors.divider;
      final surfaceColor = isDarkMode
          ? AppColors.darkSurface
          : AppColors.surface;
      final selectedColor = isDarkMode
          ? AppColors.darkIncome
          : AppColors.header;
      final sheetHeight = (MediaQuery.sizeOf(ctx).height * 0.8)
          .clamp(0.0, 480.0)
          .toDouble();

      return SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            const AppModalBottomSheetHeader(title: 'วันเริ่มรอบรายเดือน'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: 31,
                  itemBuilder: (_, index) {
                    final day = index + 1;
                    final selected = settings.monthlyCycleStartDay == day;
                    return Material(
                      color: selected ? selectedColor : surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: selected
                            ? BorderSide.none
                            : BorderSide(color: dividerColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          settings.setMonthlyCycleStartDay(day);
                          Navigator.pop(ctx);
                        },
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              color: selected ? Colors.white : textColor,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
