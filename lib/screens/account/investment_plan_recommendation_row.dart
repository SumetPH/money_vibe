import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/investment_plan.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

class InvestmentPlanRecommendationRow extends StatelessWidget {
  final AllocationAnalysisRow row;
  final double plannedTotalAfterBuy;
  final String currencyCode;
  final bool isDarkMode;
  final Color textColor;
  final Color secondaryColor;
  final Color dividerColor;

  const InvestmentPlanRecommendationRow({
    super.key,
    required this.row,
    required this.plannedTotalAfterBuy,
    required this.currencyCode,
    required this.isDarkMode,
    required this.textColor,
    required this.secondaryColor,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final targetValueAfterBuy = plannedTotalAfterBuy * row.targetPercent / 100;
    final gapBeforeBuy = (targetValueAfterBuy - row.currentValue).clamp(
      0.0,
      double.infinity,
    );
    final gapAfterBuy = (gapBeforeBuy - row.buyAmount).clamp(
      0.0,
      double.infinity,
    );
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;

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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                  color: incomeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Text(
                  '+${formatAmount(row.buyAmount)} $currencyCode',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: incomeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(AppRadii.medium),
              border: Border.all(color: dividerColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'หลังซื้อประมาณ',
                        style: TextStyle(fontSize: 11, color: secondaryColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${row.projectedPercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ขาดจากเป้า',
                        style: TextStyle(fontSize: 11, color: secondaryColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatAmount(gapBeforeBuy),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'หลังซื้อยังขาด',
                        style: TextStyle(fontSize: 11, color: secondaryColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatAmount(gapAfterBuy),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: gapAfterBuy > 0 ? secondaryColor : incomeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
