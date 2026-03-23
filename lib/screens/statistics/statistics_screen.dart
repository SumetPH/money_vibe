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
        final headerColor = isDarkMode
            ? AppColors.darkHeader
            : AppColors.header;
        final backgroundColor = isDarkMode
            ? AppColors.darkBackground
            : AppColors.background;

        return Scaffold(
          drawer: const AppDrawer(currentRoute: '/statistics'),
          appBar: AppBar(
            leading: Builder(
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
                Tab(text: 'ทรัพย์สิน', icon: Icon(Icons.show_chart)),
                Tab(text: 'รายปี', icon: Icon(Icons.bar_chart)),
                Tab(text: 'รายจ่าย', icon: Icon(Icons.trending_down)),
                Tab(text: 'รายรับ', icon: Icon(Icons.trending_up)),
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
              // Year Selector
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: textColor),
                      onPressed: () => onYearChanged(selectedYear - 1),
                    ),
                    Text(
                      '$selectedYear',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: textColor),
                      onPressed: () => onYearChanged(selectedYear + 1),
                    ),
                  ],
                ),
              ),

              // Summary Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'รายรับรวม',
                            amount: currentYearData['income'] ?? 0,
                            color: incomeColor,
                            isDarkMode: isDarkMode,
                            isCenter: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'รายจ่ายรวม',
                            amount: currentYearData['expense'] ?? 0,
                            color: expenseColor,
                            isDarkMode: isDarkMode,
                            isCenter: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SummaryCard(
                      title: 'คงเหลือสุทธิ',
                      amount: netWorthYear,
                      color: netWorthYearColor,
                      isDarkMode: isDarkMode,
                      isCenter: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Bar Chart
              Container(
                height: 320,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
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
                    const SizedBox(height: 8),
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
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Monthly breakdown list
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
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                    vertical: 10,
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

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final bool isDarkMode;
  final bool isCenter;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.isDarkMode,
    required this.isCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isCenter
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatAmount(amount),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
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
                  // Total Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${type == CategoryType.income ? 'รายรับ' : 'รายจ่าย'}รวมทั้งหมด',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatAmount(total),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Pie Chart
                  Container(
                    height: 220,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
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

                  // Category List
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'แยกตามหมวดหมู่',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatAmount(data.amount),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 13, color: secondaryTextColor),
              ),
            ],
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
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
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
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
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Toggle: include excluded accounts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'รวม account ที่ซ่อนจาก Net Worth',
                    style: TextStyle(fontSize: 13, color: secondaryTextColor),
                  ),
                  Switch(
                    value: _includeExcluded,
                    onChanged: (v) => setState(() => _includeExcluded = v),
                    activeThumbColor: lineColor,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Line Chart
              Container(
                height: 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
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
                      'ตั้งแต่ ${_formatDate(netWorthData.first.date)} - ${_formatDate(netWorthData.last.date)}',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: _getHorizontalInterval(
                              netWorthData,
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
                                  if (value == meta.min || value == meta.max) {
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
                                  netWorthData,
                                ).toDouble(),
                                getTitlesWidget: (value, meta) {
                                  final idx = value.round();
                                  if (value != idx.toDouble()) {
                                    return const SizedBox.shrink();
                                  }
                                  if (idx < 0 || idx >= netWorthData.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _formatMonthYear(netWorthData[idx].date),
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
                              spots: netWorthData.asMap().entries.map((entry) {
                                return FlSpot(
                                  entry.key.toDouble(),
                                  entry.value.netWorth,
                                );
                              }).toList(),
                              isCurved: true,
                              color: lineColor,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: netWorthData.length <= 30,
                                getDotPainter: (spot, percent, barData, index) {
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
                                  final data = netWorthData[spot.x.toInt()];
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
                          maxY: _getMaxY(netWorthData),
                          minY: _getMinY(netWorthData),
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
        portfolioValue += accountProvider.getBalance(a.id, transactions);
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

        if (tx.type == TransactionType.income) {
          if (fromIncluded) runningTotal += tx.amount;
        } else if (tx.type == TransactionType.expense) {
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

  int _getBottomInterval(List<_NetWorthData> data) {
    final length = data.length;
    if (length <= 12) return 1;
    if (length <= 24) return 2;
    if (length <= 36) return 3;
    return 12;
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
