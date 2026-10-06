import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';

class AccountSummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isDarkMode;
  final double fontSize;
  final bool isBold;

  const AccountSummaryRow({
    super.key,
    required this.label,
    required this.amount,
    required this.isDarkMode,
    this.fontSize = 15,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textPrimary,
          ),
        ),
        Text(
          '${formatAmount(amount)} บาท',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: AppColors.getAmountColor(amount, isDarkMode),
          ),
        ),
      ],
    );
  }
}
