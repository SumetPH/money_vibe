import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/app_segmented_tabs.dart';

class TransactionTypeSegmentedControl extends StatelessWidget {
  final TransactionType selectedType;
  final ValueChanged<TransactionType> onChanged;
  final VoidCallback onShowMore;

  const TransactionTypeSegmentedControl({
    super.key,
    required this.selectedType,
    required this.onChanged,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    // Check if the current type is one of the 3 primary ones
    final isPrimary =
        selectedType == TransactionType.expense ||
        selectedType == TransactionType.income ||
        selectedType == TransactionType.transfer;

    final otherLabel = switch (selectedType) {
      TransactionType.debtRepay => 'ชำระหนี้ ▾',
      TransactionType.debtTransfer => 'โอนหนี้ ▾',
      TransactionType.increaseBalance => 'ปรับเพิ่ม ▾',
      TransactionType.decreaseBalance => 'ปรับลด ▾',
      _ => 'อื่นๆ ▾',
    };

    return AppSegmentedTabs(
      segments: [
        AppSegment(
          label: 'รายจ่าย',
          isSelected: selectedType == TransactionType.expense,
          onTap: () => onChanged(TransactionType.expense),
        ),
        AppSegment(
          label: 'รายรับ',
          isSelected: selectedType == TransactionType.income,
          onTap: () => onChanged(TransactionType.income),
        ),
        AppSegment(
          label: 'โอน',
          isSelected: selectedType == TransactionType.transfer,
          onTap: () => onChanged(TransactionType.transfer),
        ),
        AppSegment(
          label: otherLabel,
          isSelected: !isPrimary,
          onTap: onShowMore,
        ),
      ],
    );
  }
}

void showTransactionTypePicker(
  BuildContext context, {
  required TransactionType currentType,
  required ValueChanged<TransactionType> onSelected,
}) {
  final isDarkMode = context.read<SettingsProvider>().isDarkMode;
  final textPrimary = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final colorScheme = Theme.of(context).colorScheme;

  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AppDraggableSheet(
      builder: (_, scrollController) => Column(
        children: [
          const AppModalBottomSheetHeader(title: 'เลือกประเภทรายการ'),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: TransactionType.values.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: AppColors.listDividerFor(isDarkMode),
              ),
              itemBuilder: (context, index) {
                final type = TransactionType.values[index];
                final (icon, color) = transactionTypeStyle(type, isDarkMode);
                final isSelected = currentType == type;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadii.large),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  title: Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        )
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
}

(IconData, Color) transactionTypeStyle(TransactionType type, bool isDarkMode) {
  switch (type) {
    case TransactionType.income:
      return (
        Icons.arrow_downward_rounded,
        isDarkMode ? AppColors.darkIncome : AppColors.income,
      );
    case TransactionType.expense:
      return (
        Icons.arrow_upward_rounded,
        isDarkMode ? AppColors.darkExpense : AppColors.expense,
      );
    case TransactionType.transfer:
      return (
        Icons.swap_horiz_rounded,
        isDarkMode ? AppColors.darkTransfer : AppColors.transfer,
      );
    case TransactionType.debtRepay:
      return (
        Icons.payment_rounded,
        isDarkMode ? AppColors.darkDebtRepay : AppColors.debtRepay,
      );
    case TransactionType.debtTransfer:
      return (
        Icons.account_tree_rounded,
        isDarkMode ? AppColors.darkDebtTransfer : AppColors.debtTransfer,
      );
    case TransactionType.increaseBalance:
      return (
        Icons.add_rounded,
        isDarkMode ? AppColors.darkIncome : AppColors.income,
      );
    case TransactionType.decreaseBalance:
      return (
        Icons.remove_rounded,
        isDarkMode ? AppColors.darkExpense : AppColors.expense,
      );
  }
}
