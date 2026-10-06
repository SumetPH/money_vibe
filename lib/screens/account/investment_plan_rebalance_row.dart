import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/investment_plan.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_inset_card.dart';
import 'investment_plan_widgets.dart';

class InvestmentPlanRebalanceRow extends StatelessWidget {
  final AllocationAnalysisRow row;
  final String currencyCode;
  final bool isDarkMode;
  final Color textColor;
  final Color secondaryColor;
  final Color dividerColor;

  const InvestmentPlanRebalanceRow({
    super.key,
    required this.row,
    required this.currencyCode,
    required this.isDarkMode,
    required this.textColor,
    required this.secondaryColor,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final diffColor = row.diffPercent > 0
        ? (isDarkMode ? AppColors.darkDebtRepay : AppColors.debtRepay)
        : row.diffPercent < 0
        ? (isDarkMode ? AppColors.darkTransfer : AppColors.transfer)
        : (isDarkMode ? AppColors.darkIncome : AppColors.income);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                alignment: Alignment.center,
                child: Text(
                  row.ticker.isNotEmpty ? row.ticker[0].toUpperCase() : 'S',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.ticker,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  color: statusColor.withValues(alpha: 0.12),
                ),
                child: Text(
                  row.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(AppRadii.large),
              border: Border.all(color: dividerColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InvestmentPlanMetricTile(
                        label: 'เป้าหมาย',
                        value: '${row.targetPercent.toStringAsFixed(2)}%',
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                    Expanded(
                      child: InvestmentPlanMetricTile(
                        label: 'ปัจจุบัน',
                        value: '${row.currentPercent.toStringAsFixed(2)}%',
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                    Expanded(
                      child: InvestmentPlanMetricTile(
                        label: 'ส่วนต่าง %',
                        value:
                            '${row.diffPercent >= 0 ? '+' : ''}${row.diffPercent.toStringAsFixed(2)}%',
                        textColor: diffColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: AppCardDivider(),
                ),
                Row(
                  children: [
                    Expanded(
                      child: InvestmentPlanMetricTile(
                        label: 'มูลค่าเป้า',
                        value: formatAmount(row.targetValue),
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                    Expanded(
                      child: InvestmentPlanMetricTile(
                        label: 'มูลค่าปัจจุบัน',
                        value: formatAmount(row.currentValue),
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                    Expanded(
                      child: InvestmentPlanMetricTile(
                        label: 'ขาด / เกิน',
                        value:
                            '${row.diffAmount >= 0 ? '+' : ''}${formatAmount(row.diffAmount)}',
                        textColor: diffColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor() {
    if (row.isUnderweight) {
      return isDarkMode ? AppColors.darkTransfer : AppColors.transfer;
    }
    if (row.isOverweight) {
      return isDarkMode ? AppColors.darkDebtRepay : AppColors.debtRepay;
    }
    return isDarkMode ? AppColors.darkIncome : AppColors.income;
  }
}
