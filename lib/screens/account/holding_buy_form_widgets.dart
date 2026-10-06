import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/account.dart';
import '../../theme/app_colors.dart';

class HoldingBuyPortfolioFieldRow extends StatelessWidget {
  final Account? account;
  final bool isDarkMode;
  final VoidCallback onTap;

  const HoldingBuyPortfolioFieldRow({
    super.key,
    required this.account,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(
                'พอร์ต',
                style: TextStyle(fontSize: 15, color: labelColor),
              ),
            ),
            Expanded(
              child: Text(
                account?.name ?? 'เลือกพอร์ต',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: labelColor),
          ],
        ),
      ),
    );
  }
}

class HoldingBuyNumberFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isDarkMode;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String>? onChanged;

  const HoldingBuyNumberFieldRow({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    required this.isDarkMode,
    required this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: labelColor),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: labelColor.withValues(alpha: 0.6)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HoldingBuyTickerFieldRow extends StatelessWidget {
  final TextEditingController controller;
  final bool isDarkMode;

  const HoldingBuyTickerFieldRow({
    super.key,
    required this.controller,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              'Ticker',
              style: TextStyle(fontSize: 15, color: labelColor),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'เช่น AAPL',
                hintStyle: TextStyle(color: labelColor.withValues(alpha: 0.6)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
