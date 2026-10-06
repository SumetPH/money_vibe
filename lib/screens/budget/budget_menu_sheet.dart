import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/budget.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import 'budget_form_screen.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/app_inset_card.dart';

void openBudgetForm(BuildContext context, Budget? budget) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => BudgetFormScreen(budget: budget)),
  );
}

void showBudgetMenuSheet(
  BuildContext context,
  bool isDarkMode, {
  required bool isReorderMode,
  required ValueChanged<bool> onReorderModeChanged,
}) {
  showAppModalBottomSheet(
    context: context,
    builder: (_) => Consumer2<SettingsProvider, BudgetProvider>(
      builder: (context, settingsProvider, budgetProvider, _) {
        final isDark = settingsProvider.isDarkMode;
        final textColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondary = isDark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;
        final incomeColor = isDark ? AppColors.darkIncome : AppColors.income;
        final yellowColor = isDark
            ? AppColors.darkFabYellow
            : AppColors.fabYellow;

        return StatefulBuilder(
          builder: (context, setStateModal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppModalBottomSheetHeader(title: 'ตัวเลือกงบประมาณ'),
                    const SizedBox(height: 8),
                    Material(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.xLarge),
                        side: BorderSide(
                          color: dividerColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: yellowColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.medium,
                                ),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: yellowColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'เพิ่มงบประมาณ',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'ตั้งเป้างบประมาณรายจ่ายตามหมวดหมู่',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: textSecondary.withValues(alpha: 0.5),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              openBudgetForm(context, null);
                            },
                          ),
                          const AppCardDivider(),
                          ListTile(
                            leading: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: incomeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.medium,
                                ),
                              ),
                              child: Icon(
                                Icons.reorder_rounded,
                                color: incomeColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'จัดเรียงลำดับ',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'เปิดโหมดลากสลับตำแหน่งงบประมาณ',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: AppSwitch(
                              value: isReorderMode,
                              onChanged: (v) {
                                onReorderModeChanged(v);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          const AppCardDivider(),
                          ListTile(
                            leading: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: textColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.medium,
                                ),
                              ),
                              child: Icon(
                                Icons.visibility_outlined,
                                color: textColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'แสดงงบประมาณที่ซ่อน',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'แสดงงบประมาณที่ถูกตั้งค่าซ่อนไว้',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: AppSwitch(
                              value: budgetProvider.showHiddenBudgets,
                              onChanged: (_) {
                                budgetProvider.toggleShowHiddenBudgets();
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
