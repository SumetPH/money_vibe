import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';

class TransactionListHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDarkMode;

  const TransactionListHeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          side: BorderSide(color: AppColors.borderFor(isDarkMode), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            color: isDarkMode
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class TransactionCashFlowSummary extends StatelessWidget {
  final double income;
  final double expense;
  final String periodLabel;
  final bool isDarkMode;
  final bool hidePeriodSelector;
  final VoidCallback? onSelectPeriod;

  const TransactionCashFlowSummary({
    super.key,
    required this.income,
    required this.expense,
    required this.periodLabel,
    required this.isDarkMode,
    required this.hidePeriodSelector,
    required this.onSelectPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final surface = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;
    final net = income - expense;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(color: AppColors.borderFor(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'กระแสเงินสด',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!hidePeriodSelector)
                InkWell(
                  onTap: onSelectPeriod,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        periodLabel,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: textSecondary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TransactionSummaryAmount(
                  label: 'รายรับ',
                  amount: income,
                  color: incomeColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TransactionSummaryAmount(
                  label: 'รายจ่าย',
                  amount: expense,
                  color: expenseColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'สุทธิ',
                style: TextStyle(color: textSecondary, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Text(
                '${net < 0 ? '-' : ''}฿ ${formatAmount(net.abs())}',
                style: TextStyle(
                  color: AppColors.getAmountColor(net, isDarkMode),
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

class TransactionSummaryAmount extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const TransactionSummaryAmount({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '฿ ${formatAmount(amount)}',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
