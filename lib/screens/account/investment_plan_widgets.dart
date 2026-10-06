import 'investment_plan_rebalance_row.dart';
import '../../models/account.dart';
import '../../models/investment_plan.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_switch.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

class InvestmentPlanSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool isDarkMode;

  const InvestmentPlanSection({
    super.key,
    required this.title,
    required this.child,
    required this.isDarkMode,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: secondaryColor,
                  ),
                ),
              ),
              if (trailing case final Widget trailingWidget) trailingWidget,
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(AppRadii.xLarge),
            border: Border.all(
              color: dividerColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ],
    );
  }
}

class InvestmentPlanTargetTotalBadge extends StatelessWidget {
  final double total;
  final bool isBalanced;
  final bool isDarkMode;

  const InvestmentPlanTargetTotalBadge({
    super.key,
    required this.total,
    required this.isBalanced,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final color = isBalanced
        ? (isDarkMode ? AppColors.darkIncome : AppColors.income)
        : (isDarkMode ? AppColors.darkDebtRepay : AppColors.debtRepay);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBalanced
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${total.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class InvestmentPlanMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color secondaryColor;

  const InvestmentPlanMetricTile({
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
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

Widget buildInvestmentPlanDcaChecklist({
  required bool dcaCompleted,
  required bool isDarkMode,
  required ValueChanged<bool> onDcaChanged,
  required Color textColor,
  required Color secondaryColor,
  required Color dividerColor,
  required Color activeColor,
}) {
  final monthLabel = formatInvestmentMonthLabel(currentInvestmentMonthKey());

  return Column(
    children: [
      InkWell(
        onTap: () => onDcaChanged(!dcaCompleted),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: dcaCompleted
                      ? activeColor.withValues(alpha: 0.15)
                      : (isDarkMode
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(
                  dcaCompleted
                      ? Icons.check_circle_rounded
                      : Icons.calendar_month_rounded,
                  color: dcaCompleted ? activeColor : secondaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DCA $monthLabel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dcaCompleted
                          ? 'ซื้อครบตามแผนแล้ว'
                          : 'ยังไม่ได้ติ๊กว่าซื้อครบ',
                      style: TextStyle(
                        fontSize: 12,
                        color: dcaCompleted ? activeColor : secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              AppSwitch(value: dcaCompleted, onChanged: onDcaChanged),
            ],
          ),
        ),
      ),
      const AppCardDivider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: secondaryColor.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'สถานะนี้เป็น checklist รายเดือนของพอร์ตนี้เท่านั้น',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget buildInvestmentPlanRebalanceRows({
  required Account account,
  required bool isDarkMode,
  required AllocationAnalysis analysis,
  required Color textColor,
  required Color secondaryColor,
  required Color dividerColor,
}) {
  final rows = analysis.rows.where((row) => row.isEnabled).toList();
  if (rows.isEmpty) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Text(
          'เปิดหุ้นในแผนและใส่เปอร์เซ็นต์เป้าหมายเพื่อดูบาลานซ์',
          textAlign: TextAlign.center,
          style: TextStyle(color: secondaryColor, fontSize: 13),
        ),
      ),
    );
  }

  return Column(
    children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const AppCardDivider(),
        InvestmentPlanRebalanceRow(
          row: rows[i],
          currencyCode: account.currencyCodeLabel,
          isDarkMode: isDarkMode,
          textColor: textColor,
          secondaryColor: secondaryColor,
          dividerColor: dividerColor,
        ),
      ],
    ],
  );
}

String formatInvestmentMonthLabel(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  const monthNames = [
    '',
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];
  final month = int.tryParse(parts[1]) ?? 0;
  final year = parts[0];
  if (month < 1 || month > 12) return monthKey;
  return '${monthNames[month]} $year';
}

String formatInvestmentEditablePct(double value) {
  if (value == 0) return '';
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

bool investmentTextEqualsNumber(String text, double value) {
  final parsed = double.tryParse(text.trim());
  if (parsed == null) return value == 0;
  return (parsed - value).abs() < 0.0001;
}
