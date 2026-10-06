import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../utils/monthly_cycle.dart';
import '../../widgets/app_inset_card.dart';
import '../../main.dart';
import '../transaction/transaction_list_screen.dart';
import 'statistics_models.dart';
import 'statistics_widgets.dart';

class StatisticsYearlyBarChart extends StatelessWidget {
  final int selectedYear;
  final ValueChanged<int> onYearChanged;

  const StatisticsYearlyBarChart({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer3<TransactionProvider, AccountProvider, SettingsProvider>(
      builder: (context, txProvider, accountProvider, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final textColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;

        final monthlyData = _calculateMonthlyStats(
          txProvider.transactions,
          selectedYear,
          accountProvider.accounts,
          settingsProvider.monthlyCycleStartDay,
        );
        final totalIncome = monthlyData.fold<double>(
          0,
          (sum, data) => sum + data.income,
        );
        final totalExpense = monthlyData.fold<double>(
          0,
          (sum, data) => sum + data.expense,
        );
        final netWorthYear = totalIncome - totalExpense;

        final incomeColor = isDarkMode
            ? AppColors.darkIncome
            : AppColors.income;
        final expenseColor = isDarkMode
            ? AppColors.darkExpense
            : AppColors.expense;
        final netWorthYearColor = netWorthYear >= -0.001
            ? incomeColor
            : expenseColor;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              AppInsetCard(
                margin: AppInsetCard.stackedMargin,
                children: [
                  StatisticsYearSelector(
                    selectedYear: selectedYear,
                    onYearChanged: onYearChanged,
                    startDay: settingsProvider.monthlyCycleStartDay,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
              AppInsetCard(
                margin: AppInsetCard.stackedMargin,
                children: [
                  StatisticsYearlySummaryPanel(
                    income: totalIncome,
                    expense: totalExpense,
                    net: netWorthYear,
                    incomeColor: incomeColor,
                    expenseColor: expenseColor,
                    netColor: netWorthYearColor,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
              AppInsetCard(
                margin: AppInsetCard.stackedMargin,
                children: [
                  SizedBox(
                    height: 320,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'รายรับ vs รายจ่าย รายเดือน',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              StatisticsLegendItem(
                                color: incomeColor,
                                label: 'รายรับ',
                                textColor: textColor,
                              ),
                              const SizedBox(width: 16),
                              StatisticsLegendItem(
                                color: expenseColor,
                                label: 'รายจ่าย',
                                textColor: textColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _buildBarChart(
                              monthlyData,
                              incomeColor,
                              expenseColor,
                              isDarkMode,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const AppCardDivider(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'รายเดือน',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              AppInsetCard(
                margin: AppInsetCard.stackedMargin,
                children: [
                  _buildMonthlyList(
                    context,
                    monthlyData,
                    incomeColor,
                    expenseColor,
                    textColor,
                    isDarkMode,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<StatisticsMonthlyData> _calculateMonthlyStats(
    List<AppTransaction> transactions,
    int selectedYear,
    List<Account> accounts,
    int startDay,
  ) {
    final monthlyData = List.generate(
      12,
      (index) => StatisticsMonthlyData(
        month: index + 1,
        monthName: _getMonthName(index + 1),
        monthShort: _getMonthShort(index + 1),
      ),
    );
    for (final tx in transactions) {
      final isIncome = tx.type == TransactionType.income;
      final isExpense = TransactionProvider.isActualExpense(tx, accounts);
      if (!isIncome && !isExpense) continue;

      final cycleMonth = monthlyCycleReportingMonth(tx.dateTime, startDay);
      if (cycleMonth.year != selectedYear) continue;

      final monthData = monthlyData[cycleMonth.month - 1];
      if (isIncome) {
        monthData.income += tx.amount;
      } else if (isExpense) {
        monthData.expense += tx.amount;
      }
      monthData.transactionIds.add(tx.id);
    }

    return monthlyData;
  }

  Widget _buildBarChart(
    List<StatisticsMonthlyData> monthlyData,
    Color incomeColor,
    Color expenseColor,
    bool isDarkMode,
  ) {
    if (monthlyData.every((d) => d.income == 0 && d.expense == 0)) {
      return Center(
        child: Text(
          'ไม่มีข้อมูล',
          style: TextStyle(
            color: isDarkMode
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      );
    }

    final maxValue = monthlyData
        .map((d) => d.income > d.expense ? d.income : d.expense)
        .reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: AppRadii.medium,
            getTooltipColor: (_) =>
                isDarkMode ? AppColors.darkSurface : AppColors.surface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final data = monthlyData[groupIndex];
              final isIncome = rodIndex == 0;
              final value = isIncome ? data.income : data.expense;
              return BarTooltipItem(
                '${data.monthName}\n',
                TextStyle(
                  color: isDarkMode
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text:
                        '${isIncome ? 'รายรับ' : 'รายจ่าย'}: ${formatAmount(value)}',
                    style: TextStyle(
                      color: isIncome ? incomeColor : expenseColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= monthlyData.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    monthlyData[value.toInt()].monthShort,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _formatCompact(value),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDarkMode ? AppColors.darkDivider : AppColors.divider,
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(12, (index) {
          final data = monthlyData[index];
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data.income,
                color: incomeColor,
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.small),
                ),
              ),
              BarChartRodData(
                toY: data.expense,
                color: expenseColor,
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.small),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMonthlyList(
    BuildContext context,
    List<StatisticsMonthlyData> monthlyData,
    Color incomeColor,
    Color expenseColor,
    Color textColor,
    bool isDarkMode,
  ) {
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'เดือน',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'รายรับ',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'รายจ่าย',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'คงเหลือ',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.listDividerFor(isDarkMode)),
        ...monthlyData.asMap().entries.map((entry) {
          final i = entry.key;
          final d = entry.value;
          final net = d.income - d.expense;
          final hasData = d.income > 0 || d.expense > 0;
          final netColor = net >= 0 ? incomeColor : expenseColor;
          return Column(
            children: [
              InkWell(
                onTap: hasData
                    ? () => _openMonthTransactions(context, d)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          d.monthShort,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          hasData && d.income > 0
                              ? formatAmount(d.income)
                              : '-',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: d.income > 0 ? incomeColor : secondaryColor,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          hasData && d.expense > 0
                              ? formatAmount(d.expense)
                              : '-',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: d.expense > 0
                                ? expenseColor
                                : secondaryColor,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          hasData
                              ? '${net >= 0 ? "+" : ""}${formatAmount(net)}'
                              : '-',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: hasData ? netColor : secondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < 11)
                Divider(height: 1, color: AppColors.listDividerFor(isDarkMode)),
            ],
          );
        }),
      ],
    );
  }

  void _openMonthTransactions(
    BuildContext context,
    StatisticsMonthlyData data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionListScreen(
          transactionIds: data.transactionIds,
          title: '${data.monthName} $selectedYear',
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
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
    return months[month - 1];
  }

  String _getMonthShort(int month) {
    const months = [
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
    return months[month - 1];
  }

  String _formatCompact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}
