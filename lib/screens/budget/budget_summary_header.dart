import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import 'budget_item_card.dart';

// ── Summary Header (Inset Grouped Card & Metric Grid) ──────────────────────────

class BudgetSummaryHeader extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final double totalAvailable;
  final double totalOverspent;
  final double progress;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;

  const BudgetSummaryHeader({
    super.key,
    required this.totalBudget,
    required this.totalSpent,
    required this.totalAvailable,
    required this.totalOverspent,
    required this.progress,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
  });

  Color get _progressColor {
    if (progress >= 1.0) {
      return isDarkMode ? AppColors.darkExpense : AppColors.expense;
    }
    if (progress >= 0.8) return Colors.orange;
    return isDarkMode ? AppColors.darkIncome : AppColors.income;
  }

  @override
  Widget build(BuildContext context) {
    final hasOverspent = totalOverspent > 0.001;
    final statusBgColor = hasOverspent
        ? (isDarkMode ? AppColors.darkExpense : AppColors.expense).withValues(
            alpha: 0.12,
          )
        : progress >= 0.8
        ? Colors.orange.withValues(alpha: 0.12)
        : (isDarkMode ? AppColors.darkIncome : AppColors.income).withValues(
            alpha: 0.12,
          );

    final statusTextColor = hasOverspent
        ? (isDarkMode ? AppColors.darkExpense : AppColors.expense)
        : progress >= 0.8
        ? Colors.orange
        : (isDarkMode ? AppColors.darkIncome : AppColors.income);

    final statusLabel = hasOverspent
        ? 'เกินงบรวม'
        : progress >= 0.8
        ? 'ใกล้เต็มงบ'
        : 'ปกติ';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Status Capsule
          Row(
            children: [
              Text(
                'สรุปงบประมาณ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasOverspent
                          ? Icons.error_outline_rounded
                          : progress >= 0.8
                          ? Icons.timelapse_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 13,
                      color: statusTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Structured Metric Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.large),
            ),
            child: Row(
              children: [
                Expanded(
                  child: BudgetMetricTile(
                    label: 'งบทั้งหมด',
                    value: formatAmount(totalBudget),
                    textColor: textPrimary,
                    secondaryColor: textSecondary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: dividerColor.withValues(alpha: 0.4),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: BudgetMetricTile(
                      label: 'ใช้ไปแล้ว',
                      value: formatAmount(totalSpent),
                      textColor: isDarkMode
                          ? AppColors.darkExpense
                          : AppColors.expense,
                      secondaryColor: textSecondary,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: dividerColor.withValues(alpha: 0.4),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: BudgetMetricTile(
                      label: 'ยังใช้ได้',
                      value: formatAmount(totalAvailable),
                      textColor: isDarkMode
                          ? AppColors.darkIncome
                          : AppColors.income,
                      secondaryColor: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Overspent alert row if applicable
          if (hasOverspent) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isDarkMode ? AppColors.darkExpense : AppColors.expense)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 15,
                    color: isDarkMode
                        ? AppColors.darkExpense
                        : AppColors.expense,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'เกินงบรวม ${formatAmount(totalOverspent)} บาท',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? AppColors.darkExpense
                          : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // iOS Progress Bar
          BudgetProgressBar(
            progress: progress,
            color: _progressColor,
            backgroundColor: isDarkMode
                ? AppColors.darkDivider.withValues(alpha: 0.6)
                : AppColors.divider.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ใช้ไป ${(progress * 100).toStringAsFixed(1)}% ของงบประมาณ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
              Text(
                hasOverspent
                    ? 'เกินเป้า'
                    : 'เหลือ ${formatAmount(totalAvailable)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasOverspent
                      ? (isDarkMode ? AppColors.darkExpense : AppColors.expense)
                      : (isDarkMode ? AppColors.darkIncome : AppColors.income),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BudgetMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color secondaryColor;

  const BudgetMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.textColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: secondaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
