import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../models/account.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_drawer.dart';
import '../../main.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final headerColor = AppColors.headerFor(
          isDarkMode,
          settingsProvider.themeColor,
        );
        final backgroundColor = isDarkMode
            ? AppColors.darkBackground
            : AppColors.background;

        final isLargeScreen = MediaQuery.of(context).size.width >= 800;

        return Scaffold(
          drawer: isLargeScreen
              ? null
              : const AppDrawer(currentRoute: '/statistics'),
          appBar: AppBar(
            leading: isLargeScreen
                ? null
                : Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
            title: const Text('สถิติ'),
            backgroundColor: headerColor,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'ทรัพย์สิน'),
                Tab(text: 'รายปี'),
                Tab(text: 'รายจ่าย'),
                Tab(text: 'รายรับ'),
              ],
            ),
          ),
          body: SafeArea(
            child: Container(
              color: backgroundColor,
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  _NetWorthLineChart(),
                  _YearlyBarChart(
                    selectedYear: _selectedYear,
                    onYearChanged: (year) =>
                        setState(() => _selectedYear = year),
                  ),
                  _CategoryPieChart(type: CategoryType.expense),
                  _CategoryPieChart(type: CategoryType.income),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==================== Yearly Bar Chart ====================

class _YearlyBarChart extends StatelessWidget {
  final int selectedYear;
  final ValueChanged<int> onYearChanged;

  const _YearlyBarChart({
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
        final surfaceColor = isDarkMode
            ? AppColors.darkSurface
            : AppColors.surface;
        final dividerColor = isDarkMode
            ? AppColors.darkDivider
            : AppColors.divider;

        final accounts = accountProvider.accounts;
        final yearlyData = _calculateYearlyData(
          txProvider.transactions,
          accounts,
        );
        final currentYearData = yearlyData[selectedYear] ?? {};

        final netWorthYear =
            (currentYearData['income'] ?? 0) -
            (currentYearData['expense'] ?? 0);

        final incomeColor = isDarkMode
            ? AppColors.darkIncome
            : AppColors.income;
        final expenseColor = isDarkMode
            ? AppColors.darkExpense
            : AppColors.expense;
        final netWorthYearColor = netWorthYear >= -0.001
            ? incomeColor
            : expenseColor;

        final monthlyData = _calculateMonthlyData(
          txProvider.transactions,
          selectedYear,
          accounts,
        );

        return SingleChildScrollView(
          child: Column(
            children: [
              _StatsYearSelector(
                selectedYear: selectedYear,
                onYearChanged: onYearChanged,
                isDarkMode: isDarkMode,
              ),
              _YearlySummaryPanel(
                income: currentYearData['income'] ?? 0,
                expense: currentYearData['expense'] ?? 0,
                net: netWorthYear,
                incomeColor: incomeColor,
                expenseColor: expenseColor,
                netColor: netWorthYearColor,
                isDarkMode: isDarkMode,
              ),

              Container(
                height: 320,
                color: surfaceColor,
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
                        _LegendItem(color: incomeColor, label: 'รายรับ'),
                        const SizedBox(width: 16),
                        _LegendItem(color: expenseColor, label: 'รายจ่าย'),
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
                    Divider(height: 1, color: dividerColor),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'รายเดือน',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              _buildMonthlyList(
                monthlyData,
                incomeColor,
                expenseColor,
                textColor,
                isDarkMode,
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Map<int, Map<String, double>> _calculateYearlyData(
    List<AppTransaction> transactions,
    List<Account> accounts,
  ) {
    final data = <int, Map<String, double>>{};

    for (final tx in transactions) {
      final year = tx.dateTime.year;
      data.putIfAbsent(year, () => {'income': 0, 'expense': 0});

      if (tx.type == TransactionType.income) {
        data[year]!['income'] = (data[year]!['income'] ?? 0) + tx.amount;
      } else if (TransactionProvider.isActualExpense(tx, accounts)) {
        data[year]!['expense'] = (data[year]!['expense'] ?? 0) + tx.amount;
      }
    }

    return data;
  }

  Widget _buildBarChart(
    List<_MonthlyData> monthlyData,
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
            tooltipRoundedRadius: 8,
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
                  top: Radius.circular(4),
                ),
              ),
              BarChartRodData(
                toY: data.expense,
                color: expenseColor,
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMonthlyList(
    List<_MonthlyData> monthlyData,
    Color incomeColor,
    Color expenseColor,
    Color textColor,
    bool isDarkMode,
  ) {
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Container(
      color: surfaceColor,
      child: Column(
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
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'รายรับ',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: incomeColor,
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
                      color: expenseColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'คงเหลือ',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),
          ...monthlyData.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            final net = d.income - d.expense;
            final hasData = d.income > 0 || d.expense > 0;
            final netColor = net >= 0 ? incomeColor : expenseColor;
            return Column(
              children: [
                Padding(
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
                if (i < 11) Divider(height: 1, color: dividerColor),
              ],
            );
          }),
        ],
      ),
    );
  }

  List<_MonthlyData> _calculateMonthlyData(
    List<AppTransaction> transactions,
    int year,
    List<Account> accounts,
  ) {
    final monthlyData = List.generate(
      12,
      (index) => _MonthlyData(
        month: index + 1,
        monthName: _getMonthName(index + 1),
        monthShort: _getMonthShort(index + 1),
      ),
    );

    for (final tx in transactions) {
      if (tx.dateTime.year != year) continue;

      final monthIndex = tx.dateTime.month - 1;
      if (tx.type == TransactionType.income) {
        monthlyData[monthIndex].income += tx.amount;
      } else if (TransactionProvider.isActualExpense(tx, accounts)) {
        monthlyData[monthIndex].expense += tx.amount;
      }
    }

    return monthlyData;
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

class _MonthlyData {
  final int month;
  final String monthName;
  final String monthShort;
  double income = 0;
  double expense = 0;

  _MonthlyData({
    required this.month,
    required this.monthName,
    required this.monthShort,
  });
}

class _StatsYearSelector extends StatelessWidget {
  final int selectedYear;
  final ValueChanged<int> onYearChanged;
  final bool isDarkMode;

  const _StatsYearSelector({
    required this.selectedYear,
    required this.onYearChanged,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: secondaryColor),
                onPressed: () => onYearChanged(selectedYear - 1),
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
              IconButton(
                icon: Icon(Icons.chevron_right, color: secondaryColor),
                onPressed: () => onYearChanged(selectedYear + 1),
              ),
            ],
          ),
          Divider(height: 1, color: dividerColor),
        ],
      ),
    );
  }
}

class _YearlySummaryPanel extends StatelessWidget {
  final double income;
  final double expense;
  final double net;
  final Color incomeColor;
  final Color expenseColor;
  final Color netColor;
  final bool isDarkMode;

  const _YearlySummaryPanel({
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
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Container(
      color: surfaceColor,
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
                child: _StatSummaryMetric(
                  label: 'รายรับ',
                  value: formatAmount(income),
                  color: incomeColor,
                ),
              ),
              Expanded(
                child: _StatSummaryMetric(
                  label: 'รายจ่าย',
                  value: formatAmount(expense),
                  color: expenseColor,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: dividerColor),
        ],
      ),
    );
  }
}

class _StatSummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  const _StatSummaryMetric({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = DefaultTextStyle.of(
      context,
    ).style.color?.withValues(alpha: 0.62);

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: secondaryColor),
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
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

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
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

// ==================== Category Pie Chart ====================

class _CategoryPieChart extends StatelessWidget {
  final CategoryType type;

  const _CategoryPieChart({required this.type});

  @override
  Widget build(BuildContext context) {
    return Consumer4<
      TransactionProvider,
      CategoryProvider,
      AccountProvider,
      SettingsProvider
    >(
      builder:
          (
            context,
            txProvider,
            catProvider,
            accountProvider,
            settingsProvider,
            _,
          ) {
            final isDarkMode = settingsProvider.isDarkMode;
            final textColor = isDarkMode
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary;
            final secondaryColor = isDarkMode
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary;
            final surfaceColor = isDarkMode
                ? AppColors.darkSurface
                : AppColors.surface;
            final dividerColor = isDarkMode
                ? AppColors.darkDivider
                : AppColors.divider;

            final categoryData = _calculateCategoryData(
              txProvider.transactions,
              catProvider.categories,
              type,
              accountProvider.accounts,
            );

            final total = categoryData.fold<double>(
              0,
              (sum, item) => sum + item.amount,
            );

            final color = type == CategoryType.income
                ? (isDarkMode ? AppColors.darkIncome : AppColors.income)
                : (isDarkMode ? AppColors.darkExpense : AppColors.expense);

            if (categoryData.isEmpty) {
              return Center(
                child: Text(
                  'ไม่มีข้อมูล${type == CategoryType.income ? 'รายรับ' : 'รายจ่าย'}',
                  style: TextStyle(
                    color: isDarkMode
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: surfaceColor,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${type == CategoryType.income ? 'รายรับ' : 'รายจ่าย'}รวมทั้งหมด',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatAmount(total),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Divider(height: 1, color: dividerColor),
                      ],
                    ),
                  ),

                  Container(
                    height: 220,
                    color: surfaceColor,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 16,
                        sections: categoryData.map((data) {
                          final percentage = total > 0
                              ? (data.amount / total) * 100
                              : 0.0;
                          final showLabel = percentage >= 4;
                          return PieChartSectionData(
                            color: data.color,
                            value: data.amount,
                            title: '',
                            radius: 52,
                            badgeWidget: showLabel
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? AppColors.darkSurface
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: data.color,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          data.icon,
                                          color: data.color,
                                          size: 11,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${percentage.toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: data.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
                            badgePositionPercentageOffset: 1.50,
                          );
                        }).toList(),
                        pieTouchData: PieTouchData(
                          enabled: true,
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {},
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'แยกตามหมวดหมู่',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  Container(
                    color: surfaceColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: categoryData.length,
                          itemBuilder: (context, index) {
                            final data = categoryData[index];
                            final percentage = total > 0
                                ? (data.amount / total) * 100
                                : 0.0;
                            return _CategoryListItem(
                              data: data,
                              percentage: percentage.toDouble(),
                              isDarkMode: isDarkMode,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
    );
  }

  List<_CategoryData> _calculateCategoryData(
    List<AppTransaction> transactions,
    List<Category> categories,
    CategoryType type,
    List<Account> accounts,
  ) {
    final Map<String, double> categoryAmounts = {};

    for (final tx in transactions) {
      final isIncome = tx.type == TransactionType.income;
      final shouldInclude = type == CategoryType.income
          ? isIncome
          : TransactionProvider.isActualExpense(tx, accounts);

      if (!shouldInclude) continue;

      final categoryId = tx.categoryId;
      if (categoryId != null) {
        categoryAmounts[categoryId] =
            (categoryAmounts[categoryId] ?? 0) + tx.amount;
      }
    }

    final result = <_CategoryData>[];
    for (final entry in categoryAmounts.entries) {
      final category = categories.firstWhere(
        (c) => c.id == entry.key,
        orElse: () => Category(
          id: entry.key,
          name: 'ไม่ระบุหมวดหมู่',
          icon: Icons.help_outline,
          color: Colors.grey,
          type: type,
        ),
      );

      result.add(
        _CategoryData(
          category: category,
          amount: entry.value.toDouble(),
          color: category.color,
          icon: category.icon,
        ),
      );
    }

    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }
}

class _CategoryData {
  final Category category;
  final double amount;
  final Color color;
  final IconData icon;

  _CategoryData({
    required this.category,
    required this.amount,
    required this.color,
    required this.icon,
  });
}

class _CategoryListItem extends StatelessWidget {
  final _CategoryData data;
  final double percentage;
  final bool isDarkMode;

  const _CategoryListItem({
    required this.data,
    required this.percentage,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryTextColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: isDarkMode
                        ? AppColors.darkDivider
                        : AppColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(data.color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatAmount(data.amount),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Net Worth Line Chart ====================

class _NetWorthLineChart extends StatefulWidget {
  @override
  State<_NetWorthLineChart> createState() => _NetWorthLineChartState();
}

class _NetWorthLineChartState extends State<_NetWorthLineChart> {
  bool _includeExcluded = false;
  _NetWorthPeriodFilter _selectedFilter = _NetWorthPeriodFilter.all;

  @override
  Widget build(BuildContext context) {
    return Consumer3<TransactionProvider, AccountProvider, SettingsProvider>(
      builder: (context, txProvider, accountProvider, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final textColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final secondaryTextColor = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final lineColor = isDarkMode ? AppColors.darkIncome : AppColors.income;

        final netWorthData = _calculateNetWorth(
          txProvider.transactions,
          accountProvider.visibleAccounts,
          accountProvider,
          includeExcluded: _includeExcluded,
        );
        final filteredNetWorthData = _filterNetWorthData(
          netWorthData,
          _selectedFilter,
        );

        if (netWorthData.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.show_chart, size: 64, color: secondaryTextColor),
                const SizedBox(height: 16),
                Text(
                  'ยังไม่มีข้อมูล',
                  style: TextStyle(fontSize: 16, color: secondaryTextColor),
                ),
              ],
            ),
          );
        }

        final currentNetWorth = netWorthData.last.netWorth;
        final startNetWorth = netWorthData.first.netWorth;
        final change = currentNetWorth - startNetWorth;
        final changePercent = startNetWorth != 0
            ? (change / startNetWorth.abs()) * 100
            : 0;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              Container(
                width: double.infinity,
                color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ทรัพย์สินสุทธิปัจจุบัน',
                      style: TextStyle(fontSize: 14, color: secondaryTextColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatAmount(currentNetWorth),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: currentNetWorth >= 0
                            ? (isDarkMode
                                  ? AppColors.darkIncome
                                  : AppColors.income)
                            : (isDarkMode
                                  ? AppColors.darkExpense
                                  : AppColors.expense),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: change >= 0
                                ? (isDarkMode
                                          ? AppColors.darkIncome
                                          : AppColors.income)
                                      .withValues(alpha: 0.1)
                                : (isDarkMode
                                          ? AppColors.darkExpense
                                          : AppColors.expense)
                                      .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                change >= 0
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: change >= 0
                                    ? (isDarkMode
                                          ? AppColors.darkIncome
                                          : AppColors.income)
                                    : (isDarkMode
                                          ? AppColors.darkExpense
                                          : AppColors.expense),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${change >= 0 ? "+" : ""}${formatAmount(change)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: change >= 0
                                      ? (isDarkMode
                                            ? AppColors.darkIncome
                                            : AppColors.income)
                                      : (isDarkMode
                                            ? AppColors.darkExpense
                                            : AppColors.expense),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${changePercent >= 0 ? "+" : ""}${changePercent.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                  ],
                ),
              ),
              Container(
                color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'รวมบัญชีที่ซ่อนจาก Net Worth',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                    Switch(
                      value: _includeExcluded,
                      onChanged: (v) => setState(() => _includeExcluded = v),
                      activeThumbColor: lineColor,
                    ),
                  ],
                ),
              ),
              Container(
                height: 300,
                color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'แนวโน้มทรัพย์สินสุทธิ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                filteredNetWorthData.isEmpty
                                    ? ''
                                    : 'ตั้งแต่ ${_formatDate(filteredNetWorthData.first.date)} - ${_formatDate(filteredNetWorthData.last.date)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<_NetWorthPeriodFilter>(
                            value: _selectedFilter,
                            icon: Icon(
                              Icons.keyboard_arrow_down,
                              color: secondaryTextColor,
                              size: 18,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontSize: 13, color: textColor),
                            dropdownColor: isDarkMode
                                ? AppColors.darkSurface
                                : Colors.white,
                            items: _NetWorthPeriodFilter.values.map((f) {
                              return DropdownMenuItem<_NetWorthPeriodFilter>(
                                value: f,
                                child: Text(
                                  f.label,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontSize: 13,
                                        color: textColor,
                                      ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedFilter = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    filteredNetWorthData.isEmpty
                        ? Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.show_chart,
                                    size: 48,
                                    color: secondaryTextColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'ยังไม่มีข้อมูลในช่วงเวลาที่เลือก',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Expanded(
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: _getHorizontalInterval(
                                    filteredNetWorthData,
                                  ),
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: isDarkMode
                                          ? AppColors.darkDivider
                                          : AppColors.divider,
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 32,
                                      getTitlesWidget: (value, meta) {
                                        if (value == meta.min ||
                                            value == meta.max) {
                                          return const SizedBox.shrink();
                                        }
                                        return SizedBox(
                                          width: 32,
                                          child: Text(
                                            _formatCompact(value),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 28,
                                      interval: _getBottomInterval(
                                        filteredNetWorthData,
                                        _selectedFilter,
                                      ).toDouble(),
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.round();
                                        if (value != idx.toDouble()) {
                                          return const SizedBox.shrink();
                                        }
                                        if (!_shouldShowBottomTitle(
                                          idx,
                                          filteredNetWorthData,
                                          _selectedFilter,
                                        )) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            _formatMonthYear(
                                              filteredNetWorthData[idx].date,
                                            ),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return SizedBox();
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: filteredNetWorthData
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                          return FlSpot(
                                            entry.key.toDouble(),
                                            entry.value.netWorth,
                                          );
                                        })
                                        .toList(),
                                    isCurved: true,
                                    color: lineColor,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(
                                      show: filteredNetWorthData.length <= 30,
                                      getDotPainter:
                                          (spot, percent, barData, index) {
                                            return FlDotCirclePainter(
                                              radius: 4,
                                              color: isDarkMode
                                                  ? AppColors.darkSurface
                                                  : Colors.white,
                                              strokeWidth: 2,
                                              strokeColor: lineColor,
                                            );
                                          },
                                    ),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: lineColor.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ],
                                lineTouchData: LineTouchData(
                                  enabled: true,
                                  touchTooltipData: LineTouchTooltipData(
                                    tooltipRoundedRadius: 8,
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((spot) {
                                        final data =
                                            filteredNetWorthData[spot.x
                                                .toInt()];
                                        return LineTooltipItem(
                                          '${_formatDate(data.date)}\n',
                                          TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: formatAmount(data.netWorth),
                                              style: TextStyle(
                                                color: lineColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                                maxY: _getMaxY(filteredNetWorthData),
                                minY: _getMinY(filteredNetWorthData),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_NetWorthData> _calculateNetWorth(
    List<AppTransaction> transactions,
    List<Account> accounts,
    AccountProvider accountProvider, {
    bool includeExcluded = false,
  }) {
    if (accounts.isEmpty) return [];

    // Apply excludeFromNetWorth filter unless user opted to include them
    final effectiveAccounts = includeExcluded
        ? accounts
        : accounts.where((a) => !a.excludeFromNetWorth).toList();

    // Portfolio accounts use cashBalance+holdings (not transaction-based),
    // so exclude them from the running total and add their current value as a static offset.
    final portfolioAccountIds = {
      for (final a in effectiveAccounts)
        if (a.type == AccountType.portfolio) a.id,
    };

    // Current portfolio value (constant offset added to all data points)
    double portfolioValue = 0;
    for (final a in effectiveAccounts) {
      if (a.type == AccountType.portfolio) {
        portfolioValue += accountProvider.getBalanceInThb(a.id, transactions);
      }
    }

    String monthKey(DateTime dt) =>
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

    // Collect initial balance injections per month based on account.startDate
    final Map<String, double> initialByMonth = {};
    for (final a in effectiveAccounts) {
      if (a.type != AccountType.portfolio) {
        final mk = monthKey(a.startDate);
        initialByMonth[mk] = (initialByMonth[mk] ?? 0) + a.initialBalance;
      }
    }

    // Sort transactions by date
    final sortedTx = List<AppTransaction>.from(transactions)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // Collect all months to show (account starts + transaction months)
    final allMonths = <String>{
      ...initialByMonth.keys,
      for (final tx in sortedTx) monthKey(tx.dateTime),
    };
    final sortedMonths = allMonths.toList()..sort();

    // Group transactions by month for quick lookup
    final Map<String, List<AppTransaction>> txByMonth = {};
    for (final tx in sortedTx) {
      txByMonth.putIfAbsent(monthKey(tx.dateTime), () => []).add(tx);
    }

    // Account IDs that are included (non-portfolio only, portfolio handled separately)
    final effectiveAccountIds = {
      for (final a in effectiveAccounts)
        if (a.type != AccountType.portfolio) a.id,
    };

    double runningTotal = 0;
    final Map<String, double> monthlyNetWorth = {};

    for (final mk in sortedMonths) {
      // Add initial balances of accounts that started this month
      runningTotal += initialByMonth[mk] ?? 0;

      // Apply transactions for this month
      for (final tx in txByMonth[mk] ?? []) {
        final fromIncluded = effectiveAccountIds.contains(tx.accountId);
        final toIncluded =
            tx.toAccountId != null &&
            effectiveAccountIds.contains(tx.toAccountId);
        final fromPortfolio = portfolioAccountIds.contains(tx.accountId);
        final toPortfolio =
            tx.toAccountId != null &&
            portfolioAccountIds.contains(tx.toAccountId);

        if (tx.type == TransactionType.income ||
            tx.type == TransactionType.increaseBalance) {
          if (fromIncluded) runningTotal += tx.amount;
        } else if (tx.type == TransactionType.expense ||
            tx.type == TransactionType.decreaseBalance) {
          if (fromIncluded) runningTotal -= tx.amount;
        } else if (tx.type.usesDestinationAccount) {
          if (!fromPortfolio && toPortfolio && fromIncluded) {
            runningTotal -= tx.amount;
          } else if (fromPortfolio && !toPortfolio && toIncluded) {
            runningTotal += tx.amount;
          } else if (!fromPortfolio && !toPortfolio) {
            if (fromIncluded && !toIncluded) runningTotal -= tx.amount;
            if (!fromIncluded && toIncluded) runningTotal += tx.amount;
            // both included or both excluded → neutral
          }
        }
      }

      monthlyNetWorth[mk] = runningTotal;
    }

    // Convert to list
    final now = DateTime.now();
    final currentMonthKey = monthKey(now);
    final result = monthlyNetWorth.entries.map((entry) {
      final parts = entry.key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final date = entry.key == currentMonthKey
          ? now
          : DateTime(year, month, 1);
      return _NetWorthData(date: date, netWorth: entry.value + portfolioValue);
    }).toList();

    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  List<_NetWorthData> _filterNetWorthData(
    List<_NetWorthData> data,
    _NetWorthPeriodFilter filter,
  ) {
    if (data.isEmpty || filter == _NetWorthPeriodFilter.all) return data;

    final now = DateTime.now();
    DateTime cutoff;

    switch (filter) {
      case _NetWorthPeriodFilter.threeMonths:
        cutoff = DateTime(now.year, now.month - 2, 1);
        break;
      case _NetWorthPeriodFilter.sixMonths:
        cutoff = DateTime(now.year, now.month - 5, 1);
        break;
      case _NetWorthPeriodFilter.oneYear:
        cutoff = DateTime(now.year, now.month - 11, 1);
        break;
      case _NetWorthPeriodFilter.thisYear:
        cutoff = DateTime(now.year, 1, 1);
        break;
      case _NetWorthPeriodFilter.all:
        return data;
    }

    return data
        .where((d) => d.date.isAfter(cutoff) || d.date.isAtSameMomentAs(cutoff))
        .toList();
  }

  double _getMaxY(List<_NetWorthData> data) {
    if (data.isEmpty) return 100;
    final max = data.map((d) => d.netWorth).reduce((a, b) => a > b ? a : b);
    final min = data.map((d) => d.netWorth).reduce((a, b) => a < b ? a : b);
    final range = max - min;
    return max + (range * 0.15);
  }

  double _getMinY(List<_NetWorthData> data) {
    if (data.isEmpty) return 0;
    final max = data.map((d) => d.netWorth).reduce((a, b) => a > b ? a : b);
    final min = data.map((d) => d.netWorth).reduce((a, b) => a < b ? a : b);
    final range = max - min;
    return min - (range * 0.15);
  }

  double _getHorizontalInterval(List<_NetWorthData> data) {
    if (data.isEmpty) return 1000;
    final max = data.map((d) => d.netWorth).reduce((a, b) => a > b ? a : b);
    final min = data.map((d) => d.netWorth).reduce((a, b) => a < b ? a : b);
    final range = max - min;
    if (range == 0) return (max.abs() > 0 ? max.abs() / 5 : 1000);
    return range / 5;
  }

  int _getBottomInterval(
    List<_NetWorthData> data,
    _NetWorthPeriodFilter filter,
  ) {
    if (filter == _NetWorthPeriodFilter.oneYear) {
      return 6;
    }
    final length = data.length;
    if (length <= 12) return 1;
    if (length <= 24) return 2;
    if (length <= 36) return 3;
    return 12;
  }

  bool _shouldShowBottomTitle(
    int idx,
    List<_NetWorthData> data,
    _NetWorthPeriodFilter filter,
  ) {
    if (idx < 0 || idx >= data.length) return false;

    final lastIdx = data.length - 1;
    if (idx == lastIdx) return true;

    final interval = _getBottomInterval(data, filter);
    final lastIntervalIdx = (lastIdx ~/ interval) * interval;
    final minGapFromLast = interval > 1 ? (interval / 2).ceil() : 1;

    if (idx == lastIntervalIdx && lastIdx - idx < minGapFromLast) {
      return false;
    }

    return idx % interval == 0;
  }

  String _formatCompact(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatMonthYear(DateTime date) {
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
    final shortYear = (date.year % 100).toString().padLeft(2, '0');
    return '${months[date.month - 1]} $shortYear';
  }
}

class _NetWorthData {
  final DateTime date;
  final double netWorth;

  _NetWorthData({required this.date, required this.netWorth});
}

enum _NetWorthPeriodFilter {
  all('ทั้งหมด'),
  threeMonths('3 เดือน'),
  sixMonths('6 เดือน'),
  oneYear('1 ปี'),
  thisYear('ปีนี้');

  final String label;
  const _NetWorthPeriodFilter(this.label);
}
