import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../main.dart';
import '../../widgets/app_switch.dart';
import 'statistics_models.dart';
import 'statistics_net_worth_calculator.dart';
import 'statistics_widgets.dart';

class StatisticsNetWorthLineChart extends StatefulWidget {
  const StatisticsNetWorthLineChart({super.key});

  @override
  State<StatisticsNetWorthLineChart> createState() => _NetWorthLineChartState();
}

class _NetWorthLineChartState extends State<StatisticsNetWorthLineChart> {
  bool _includeExcluded = false;
  StatisticsNetWorthPeriodFilter _selectedFilter =
      StatisticsNetWorthPeriodFilter.all;

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

        final netWorthData = calculateNetWorthData(
          txProvider.transactions,
          accountProvider.accounts,
          accountProvider,
          includeExcluded: _includeExcluded,
        );
        final filteredNetWorthData = filterNetWorthData(
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

        final startNetWorth = filteredNetWorthData.first.netWorth;
        final endNetWorth = filteredNetWorthData.last.netWorth;
        final showsPeriodComparison =
            _selectedFilter != StatisticsNetWorthPeriodFilter.all;
        final change = endNetWorth - startNetWorth;
        final changePercent = startNetWorth != 0
            ? (change / startNetWorth.abs()) * 100
            : 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              StatisticsInsetCard(
                isDarkMode: isDarkMode,
                child: Container(
                  width: double.infinity,
                  color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showsPeriodComparison
                            ? 'ทรัพย์สินสุทธิในช่วง ${_selectedFilter.label}'
                            : 'ทรัพย์สินสุทธิปัจจุบัน',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!showsPeriodComparison)
                        Text(
                          formatAmount(endNetWorth),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: endNetWorth >= 0
                                ? (isDarkMode
                                      ? AppColors.darkIncome
                                      : AppColors.income)
                                : (isDarkMode
                                      ? AppColors.darkExpense
                                      : AppColors.expense),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ต้นช่วง',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                  Text(
                                    formatAmount(startNetWorth),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward,
                              color: secondaryTextColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'ปลายช่วง',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                  Text(
                                    formatAmount(endNetWorth),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: endNetWorth >= 0
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
                          ],
                        ),
                      if (showsPeriodComparison) ...[
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
                                borderRadius: BorderRadius.circular(
                                  AppRadii.small,
                                ),
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
                    ],
                  ),
                ),
              ),
              StatisticsInsetCard(
                isDarkMode: isDarkMode,
                child: Container(
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
                            fontWeight: FontWeight.w600,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                      AppSwitch(
                        value: _includeExcluded,
                        onChanged: (v) => setState(() => _includeExcluded = v),
                      ),
                    ],
                  ),
                ),
              ),
              StatisticsInsetCard(
                isDarkMode: isDarkMode,
                child: SizedBox(
                  height: 300,
                  child: Padding(
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
                                      fontWeight: FontWeight.w600,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: isDarkMode
                                  ? AppColors.darkSurfaceVariant
                                  : AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.full,
                                ),
                                side: BorderSide(
                                  color:
                                      (isDarkMode
                                              ? AppColors.darkDivider
                                              : AppColors.divider)
                                          .withValues(alpha: 0.5),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () =>
                                    _showFilterSheet(context, isDarkMode),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _selectedFilter.label,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        color: secondaryTextColor,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
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
                                      horizontalInterval:
                                          _getHorizontalInterval(
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
                                                  filteredNetWorthData[idx]
                                                      .date,
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
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
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
                                          show:
                                              filteredNetWorthData.length <= 30,
                                          getDotPainter:
                                              (spot, percent, barData, index) {
                                                return FlDotCirclePainter(
                                                  radius: 4,
                                                  color: isDarkMode
                                                      ? AppColors.darkSurface
                                                      : AppColors.surface,
                                                  strokeWidth: 2,
                                                  strokeColor: lineColor,
                                                );
                                              },
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: lineColor.withValues(
                                            alpha: 0.1,
                                          ),
                                        ),
                                      ),
                                    ],
                                    lineTouchData: LineTouchData(
                                      enabled: true,
                                      touchTooltipData: LineTouchTooltipData(
                                        tooltipRoundedRadius: AppRadii.medium,
                                        getTooltipColor: (_) => isDarkMode
                                            ? AppColors.darkSurface
                                            : AppColors.surface,
                                        getTooltipItems: (touchedSpots) {
                                          return touchedSpots.map((spot) {
                                            final data =
                                                filteredNetWorthData[spot.x
                                                    .toInt()];
                                            return LineTooltipItem(
                                              '${_formatTooltipDate(data.date)}\n',
                                              TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text: formatAmount(
                                                    data.netWorth,
                                                  ),
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.amountColor(
                                                          data.netWorth,
                                                          isDarkMode:
                                                              isDarkMode,
                                                        ),
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showFilterSheet(BuildContext context, bool isDarkMode) async {
    final selected =
        await showAppModalBottomSheet<StatisticsNetWorthPeriodFilter>(
          context: context,
          builder: (sheetContext) {
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
            final accent = AppColors.accentFor(
              isDarkMode,
              context.read<SettingsProvider>().themeColor,
            );

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppModalBottomSheetHeader(title: 'ช่วงเวลาที่แสดง'),
                    Material(
                      color: surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.xLarge),
                        side: BorderSide(
                          color: dividerColor.withValues(alpha: 0.4),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: StatisticsNetWorthPeriodFilter.values.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: AppColors.listDividerFor(isDarkMode),
                        ),
                        itemBuilder: (_, index) {
                          final filter =
                              StatisticsNetWorthPeriodFilter.values[index];
                          final isSelected = filter == _selectedFilter;
                          return ListTile(
                            onTap: () => Navigator.pop(sheetContext, filter),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: isSelected ? accent : secondaryColor,
                              size: 22,
                            ),
                            title: Text(
                              filter.label,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
    if (selected != null && mounted) {
      setState(() => _selectedFilter = selected);
    }
  }

  double _getMaxY(List<StatisticsNetWorthData> data) {
    if (data.isEmpty) return 100;
    final max = data.map((d) => d.netWorth).reduce((a, b) => a > b ? a : b);
    final min = data.map((d) => d.netWorth).reduce((a, b) => a < b ? a : b);
    final range = max - min;
    return max + (range * 0.15);
  }

  double _getMinY(List<StatisticsNetWorthData> data) {
    if (data.isEmpty) return 0;
    final max = data.map((d) => d.netWorth).reduce((a, b) => a > b ? a : b);
    final min = data.map((d) => d.netWorth).reduce((a, b) => a < b ? a : b);
    final range = max - min;
    return min - (range * 0.15);
  }

  double _getHorizontalInterval(List<StatisticsNetWorthData> data) {
    if (data.isEmpty) return 1000;
    final max = data.map((d) => d.netWorth).reduce((a, b) => a > b ? a : b);
    final min = data.map((d) => d.netWorth).reduce((a, b) => a < b ? a : b);
    final range = max - min;
    if (range == 0) return (max.abs() > 0 ? max.abs() / 5 : 1000);
    return range / 5;
  }

  int _getBottomInterval(
    List<StatisticsNetWorthData> data,
    StatisticsNetWorthPeriodFilter filter,
  ) {
    if (filter == StatisticsNetWorthPeriodFilter.oneYear) {
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
    List<StatisticsNetWorthData> data,
    StatisticsNetWorthPeriodFilter filter,
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

  String _formatTooltipDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '$month/${date.year}';
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
