import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import 'budget_list_models.dart';
import 'budget_summary_header.dart';

class BudgetGroupDetailsSheet extends StatelessWidget {
  final List<BudgetGroupSummary> groupSummaries;
  final String periodLabel;
  final double totalBudget;
  final double totalSpent;
  final double totalAvailable;
  final double totalOverspent;
  final double overallProgress;
  final bool isDarkMode;

  const BudgetGroupDetailsSheet({
    super.key,
    required this.groupSummaries,
    required this.periodLabel,
    required this.totalBudget,
    required this.totalSpent,
    required this.totalAvailable,
    required this.totalOverspent,
    required this.overallProgress,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        children: [
          AppModalBottomSheetHeader(title: 'รายละเอียดกลุ่มงบประมาณ'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.darkSurfaceVariant
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              child: Text(
                periodLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ),
          ),
          BudgetSummaryHeader(
            totalBudget: totalBudget,
            totalSpent: totalSpent,
            totalAvailable: totalAvailable,
            totalOverspent: totalOverspent,
            progress: overallProgress,
            isDarkMode: isDarkMode,
            surfaceColor: bgColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            dividerColor: dividerColor,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: groupSummaries.isEmpty
                ? Center(
                    child: Text(
                      'ยังไม่มีกลุ่มงบประมาณ',
                      style: TextStyle(color: textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: groupSummaries.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final summary = groupSummaries[index];
                      final percentageBgColor = isDarkMode
                          ? AppColors.darkSurfaceVariant
                          : AppColors.header.withValues(alpha: 0.12);
                      final percentageTextColor = isDarkMode
                          ? AppColors.darkTextPrimary
                          : AppColors.header;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(AppRadii.xLarge),
                          border: Border.all(
                            color: dividerColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    summary.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: percentageBgColor,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.full,
                                    ),
                                  ),
                                  child: Text(
                                    '${summary.percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: percentageTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: BudgetGroupDetailMetric(
                                    label: 'ยอดรวม',
                                    value: formatAmount(summary.total),
                                    valueColor: textPrimary,
                                    textSecondary: textSecondary,
                                    alignment: CrossAxisAlignment.start,
                                  ),
                                ),
                                Expanded(
                                  child: BudgetGroupDetailMetric(
                                    label: 'ยอดที่ใช้ไป',
                                    value: formatAmount(summary.spent),
                                    valueColor: isDarkMode
                                        ? AppColors.darkExpense
                                        : AppColors.expense,
                                    textSecondary: textSecondary,
                                    alignment: CrossAxisAlignment.center,
                                  ),
                                ),
                                Expanded(
                                  child: BudgetGroupDetailMetric(
                                    label: 'ยังใช้ได้',
                                    value: formatAmount(summary.available),
                                    valueColor: isDarkMode
                                        ? AppColors.darkIncome
                                        : AppColors.income,
                                    textSecondary: textSecondary,
                                    alignment: CrossAxisAlignment.end,
                                  ),
                                ),
                              ],
                            ),
                            if (summary.overspent > 0.001) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 14,
                                    color: isDarkMode
                                        ? AppColors.darkExpense
                                        : AppColors.expense,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'เกินงบ ${formatAmount(summary.overspent)}',
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
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class BudgetGroupDetailMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Color textSecondary;
  final CrossAxisAlignment alignment;

  const BudgetGroupDetailMetric({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.textSecondary,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

void showBudgetGroupDetailsSheet(
  BuildContext context,
  List<BudgetGroupSummary> groupSummaries,
  String periodLabel,
  double totalBudget,
  double totalSpent,
  double totalAvailable,
  double totalOverspent,
  double overallProgress,
  bool isDarkMode,
) {
  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => BudgetGroupDetailsSheet(
      groupSummaries: groupSummaries,
      periodLabel: periodLabel,
      totalBudget: totalBudget,
      totalSpent: totalSpent,
      totalAvailable: totalAvailable,
      totalOverspent: totalOverspent,
      overallProgress: overallProgress,
      isDarkMode: isDarkMode,
    ),
  );
}
