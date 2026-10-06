import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../utils/currency_utils.dart';

void showAccountTypePicker(
  BuildContext context, {
  required AccountType selected,
  required ValueChanged<AccountType> onSelected,
}) {
  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final textPrimaryColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final headerColor = isDarkMode
            ? AppColors.darkIncome
            : AppColors.header;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppModalBottomSheetHeader(title: 'เลือกชนิดบัญชี'),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: AccountType.values.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: AppColors.listDividerFor(isDarkMode),
                    ),
                    itemBuilder: (_, i) {
                      final type = AccountType.values[i];
                      final isSelected = selected == type;
                      return ListTile(
                        title: Text(
                          type.label,
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check, color: headerColor)
                            : null,
                        onTap: () {
                          onSelected(type);
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
      },
    ),
  );
}

void showAccountCurrencyPicker(
  BuildContext context, {
  required String selectedCurrency,
  required ValueChanged<String> onSelected,
}) {
  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final surfaceColor = isDarkMode
            ? AppColors.darkSurface
            : AppColors.surface;
        final textPrimaryColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondaryColor = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final headerColor = isDarkMode
            ? AppColors.darkIncome
            : AppColors.header;

        return AppDraggableSheet(
          builder: (context, scrollController) => SafeArea(
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: AppModalBottomSheetHeader(title: 'เลือกสกุลเงิน'),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final currency = CurrencyUtils.currencies[i];
                    final code = currency['code']!;
                    final symbol = currency['symbol']!;
                    final name = currency['name']!;
                    final selected = code == selectedCurrency;
                    return ListTile(
                      tileColor: surfaceColor,
                      title: Text(
                        '$code - $name',
                        style: TextStyle(color: textPrimaryColor, fontSize: 15),
                      ),
                      subtitle: Text(
                        'สัญลักษณ์: $symbol',
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 13,
                        ),
                      ),
                      trailing: selected
                          ? Icon(Icons.check, color: headerColor)
                          : null,
                      onTap: () {
                        onSelected(code);
                        Navigator.pop(context);
                      },
                    );
                  }, childCount: CurrencyUtils.currencies.length),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void showAccountIconSourceSheet(
  BuildContext context, {
  required bool canRemoveUploadedIcon,
  required VoidCallback onRemoveUploadedIcon,
  required VoidCallback onPickCustomIcon,
  required VoidCallback onPickFromGrid,
}) {
  showAppModalBottomSheet(
    context: context,
    builder: (_) => Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final textColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondary = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final dividerColor = isDarkMode
            ? AppColors.darkDivider
            : AppColors.divider;
        final incomeColor = isDarkMode
            ? AppColors.darkIncome
            : AppColors.income;
        final expenseColor = isDarkMode
            ? AppColors.darkExpense
            : AppColors.expense;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppModalBottomSheetHeader(title: 'รูปและไอคอน'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.xLarge),
                    border: Border.all(
                      color: dividerColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      if (canRemoveUploadedIcon) ...[
                        ListTile(
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: expenseColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppRadii.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: expenseColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'ลบรูปที่อัปโหลด',
                            style: TextStyle(
                              color: expenseColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            onRemoveUploadedIcon();
                            Navigator.pop(context);
                          },
                        ),
                        Divider(
                          height: 1,
                          indent: 58,
                          endIndent: 16,
                          color: dividerColor.withValues(alpha: 0.3),
                        ),
                      ],
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
                            Icons.image_outlined,
                            color: incomeColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'อัปโหลดรูปภาพ',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'เลือกรูปจากคลังภาพในเครื่อง',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onPickCustomIcon();
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 58,
                        endIndent: 16,
                        color: dividerColor.withValues(alpha: 0.3),
                      ),
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
                            Icons.grid_view_rounded,
                            color: textColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'เลือกไอคอน',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'เลือกจากชุดไอคอนมาตรฐาน',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onPickFromGrid();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
