import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_modal_bottom_sheet.dart';

Future<String?> showHoldingPortfolioPicker(
  BuildContext context, {
  required bool isDarkMode,
  required List<Account> portfolios,
  required String? selectedPortfolioId,
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
