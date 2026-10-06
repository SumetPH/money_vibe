import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import 'transaction_list_models.dart';

void showTransactionPeriodPicker(
  BuildContext context,
  bool isDarkMode, {
  required TransactionPeriodFilter selected,
  required DateTimeRange? customRange,
  required VoidCallback onPickCustomRange,
  required ValueChanged<TransactionPeriodFilter> onSelected,
}) {
  final textColor = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final textSecondary = isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;
  final checkColor = isDarkMode ? AppColors.darkIncome : AppColors.income;

  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppModalBottomSheetHeader(title: 'เลือกช่วงเวลา'),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: TransactionPeriodFilter.values
                    .map(
                      (f) => ListTile(
                        title: Text(
                          f.label,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: selected == f
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle:
                            f == TransactionPeriodFilter.custom &&
                                customRange != null
                            ? Text(
                                formatTransactionRange(
                                  customRange,
                                  withYear: true,
                                ),
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: f == TransactionPeriodFilter.custom
                            ? Icon(
                                selected == f
                                    ? Icons.check_circle_rounded
                                    : Icons.date_range_rounded,
                                color: selected == f
                                    ? checkColor
                                    : textSecondary,
                                size: 22,
                              )
                            : selected == f
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: checkColor,
                                size: 22,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          if (f == TransactionPeriodFilter.custom) {
                            onPickCustomRange();
                            return;
                          }
                          onSelected(f);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
