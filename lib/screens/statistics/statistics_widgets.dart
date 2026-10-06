import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../utils/monthly_cycle.dart';
import '../../main.dart';

class StatisticsYearSelector extends StatelessWidget {
  final int selectedYear;
  final ValueChanged<int> onYearChanged;
  final int startDay;
  final bool isDarkMode;

  const StatisticsYearSelector({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
    required this.startDay,
    required this.isDarkMode,
  });

  String _getYearPeriodLabel() {
    const thaiMonths = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    final start = monthlyCyclePeriod(DateTime(selectedYear, 1), startDay).start;
    final end = monthlyCyclePeriod(
      DateTime(selectedYear, 12),
      startDay,
    ).endExclusive.subtract(const Duration(days: 1));
    return 'รอบ ${start.day} ${thaiMonths[start.month - 1]} ${start.year} - '
        '${end.day} ${thaiMonths[end.month - 1]} ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
      child: Column(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
                child: IconButton(
                  tooltip: 'ปีก่อนหน้า',
                  icon: Icon(Icons.chevron_left, color: secondaryColor),
                  onPressed: () => onYearChanged(selectedYear - 1),
                ),
              ),
              Expanded(
                child: Text(
                  '$selectedYear',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                child: IconButton(
                  tooltip: 'ปีถัดไป',
                  icon: Icon(Icons.chevron_right, color: secondaryColor),
                  onPressed: () => onYearChanged(selectedYear + 1),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: secondaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getYearPeriodLabel(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryColor,
                    ),
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

class StatisticsYearlySummaryPanel extends StatelessWidget {
  final double income;
  final double expense;
  final double net;
  final Color incomeColor;
  final Color expenseColor;
  final Color netColor;
  final bool isDarkMode;

  const StatisticsYearlySummaryPanel({
    super.key,
    required this.income,
    required this.expense,
    required this.net,
    required this.incomeColor,
    required this.expenseColor,
    required this.netColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คงเหลือสุทธิ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${net >= 0 ? '+' : ''}${formatAmount(net)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: netColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatisticsSummaryMetric(
                  label: 'รายรับ',
                  value: formatAmount(income),
                  color: incomeColor,
                  isDarkMode: isDarkMode,
                ),
              ),
              Expanded(
                child: StatisticsSummaryMetric(
                  label: 'รายจ่าย',
                  value: formatAmount(expense),
                  color: expenseColor,
                  alignEnd: true,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatisticsSummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;
  final bool isDarkMode;

  const StatisticsSummaryMetric({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.isDarkMode,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Container(
      margin: EdgeInsets.only(left: alignEnd ? 6 : 0, right: alignEnd ? 0 : 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurfaceVariant : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class StatisticsLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;

  const StatisticsLegendItem({
    super.key,
    required this.color,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
