import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/stock_holding.dart';
import '../../theme/app_colors.dart';

class HoldingSellNumberFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isDarkMode;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const HoldingSellNumberFieldRow({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    required this.isDarkMode,
    this.errorText,
    this.inputFormatters,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: inputFormatters,
                  textAlign: TextAlign.right,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: labelColor.withValues(alpha: 0.6),
                    ),
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
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  errorText!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.darkExpense
                        : AppColors.expense,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HoldingSellSummaryCard extends StatelessWidget {
  final StockHolding holding;
  final String currencyCode;
  final bool isDarkMode;
  final double sharesSold;
  final double cashReceivedUsd;

  const HoldingSellSummaryCard({
    super.key,
    required this.holding,
    required this.currencyCode,
    required this.isDarkMode,
    required this.sharesSold,
    required this.cashReceivedUsd,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    final estimatedCost = holding.costBasisUsd * sharesSold;
    final estimatedPnl = cashReceivedUsd - estimatedCost;
    final isProfit = estimatedPnl >= 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ราคาทุนเฉลี่ย',
                style: TextStyle(color: secondaryColor, fontSize: 14),
              ),
              Text(
                '${formatStockHoldingCostBasis(holding.costBasisUsd)} $currencyCode/หุ้น',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'กำไร/ขาดทุนโดยประมาณ',
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                sharesSold > 0
                    ? '${isProfit ? '+' : ''}${formatStockHoldingCostBasis(estimatedPnl)} $currencyCode'
                    : '-',
                style: TextStyle(
                  color: sharesSold > 0
                      ? (isProfit
                            ? (isDarkMode
                                  ? AppColors.darkIncome
                                  : AppColors.income)
                            : (isDarkMode
                                  ? AppColors.darkExpense
                                  : AppColors.expense))
                      : secondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
