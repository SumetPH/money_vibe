import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/account.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_modal_bottom_sheet.dart';

Future<String?> showStockTradePortfolioPickerSheet({
  required BuildContext context,
  required List<Account> portfolios,
  required String? selectedPortfolioId,
  required bool isDarkMode,
}) {
  final textColor = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final secondaryColor = isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;

  return showAppModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppModalBottomSheetHeader(title: 'เลือกพอร์ต'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: portfolios
                    .map(
                      (portfolio) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          portfolio.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textColor),
                        ),
                        trailing: portfolio.id == selectedPortfolioId
                            ? Icon(Icons.check, color: secondaryColor)
                            : null,
                        onTap: () => Navigator.pop(sheetContext, portfolio.id),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class StockTradeAdvancedDetailsSection extends StatelessWidget {
  final bool isDarkMode;
  final Color textColor;
  final Color secondaryColor;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const StockTradeAdvancedDetailsSection({
    super.key,
    required this.isDarkMode,
    required this.textColor,
    required this.secondaryColor,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
          child: ListTile(
            title: Text(
              'รายละเอียดเพิ่มเติม',
              style: TextStyle(color: textColor, fontSize: 15),
            ),
            subtitle: Text(
              'ค่าธรรมเนียม ภาษี และข้อมูลจาก statement',
              style: TextStyle(color: secondaryColor, fontSize: 13),
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: secondaryColor,
            ),
            onTap: onToggle,
          ),
        ),
        if (isExpanded) ...[
          Divider(
            height: 1,
            color: isDarkMode ? AppColors.darkDivider : AppColors.divider,
          ),
          ...children,
        ],
      ],
    );
  }
}

class StockTradeTextFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isDarkMode;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextInputType keyboardType;

  const StockTradeTextFieldRow({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    required this.isDarkMode,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return Container(
      color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              width: 140,
              child: Text(
                label,
                style: TextStyle(color: labelColor, fontSize: 15),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              inputFormatters: inputFormatters,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: labelColor),
                errorText: errorText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              style: TextStyle(color: textColor, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
