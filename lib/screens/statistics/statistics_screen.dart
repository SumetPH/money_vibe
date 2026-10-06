import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../utils/monthly_cycle.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_segmented_tabs.dart';
import 'statistics_yearly_bar_chart.dart';
import 'statistics_category_pie_chart.dart';
import 'statistics_net_worth_chart.dart';

class StatisticsScreen extends StatefulWidget {
  final bool showPrimaryNavigation;

  const StatisticsScreen({super.key, this.showPrimaryNavigation = true});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedTab = 0;
  int? _selectedYear;
  static const _tabLabels = ['ทรัพย์สิน', 'รายปี', 'รายจ่าย', 'รายรับ'];

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final selectedYear =
            _selectedYear ??
            monthlyCycleReportingMonth(
              DateTime.now(),
              settingsProvider.monthlyCycleStartDay,
            ).year;
        final isDarkMode = settingsProvider.isDarkMode;
        final backgroundColor = isDarkMode
            ? AppColors.darkBackground
            : AppColors.background;
        final surfaceColor = isDarkMode
            ? AppColors.darkSurface
            : AppColors.surface;
        final textColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;

        final isLargeScreen = MediaQuery.of(context).size.width >= 800;

        return Scaffold(
          backgroundColor: backgroundColor,
          drawer: isLargeScreen || !widget.showPrimaryNavigation
              ? null
              : const AppDrawer(currentRoute: '/statistics'),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: isLargeScreen || !widget.showPrimaryNavigation
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Material(
                      color: surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.full),
                        side: BorderSide(
                          color: AppColors.borderFor(isDarkMode),
                          width: 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Builder(
                        builder: (ctx) => IconButton(
                          icon: Icon(Icons.menu, color: textColor),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                    ),
                  ),
            leadingWidth: 64,
            toolbarHeight: 100,
            titleSpacing: isLargeScreen ? 24 : 16,
            centerTitle: false,
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'การวิเคราะห์การเงิน',
                  style: TextStyle(
                    color: isDarkMode
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'สถิติ',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            bottom: false,
            // แท็บเลื่อนไปพร้อมเนื้อหา (ไม่ sticky)
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: AppSegmentedTabs(
                      segments: [
                        for (final (index, label) in _tabLabels.indexed)
                          AppSegment(
                            label: label,
                            isSelected: _selectedTab == index,
                            onTap: () => setState(() => _selectedTab = index),
                          ),
                      ],
                    ),
                  ),
                  // ใช้ Visibility + maintainState แทน IndexedStack เพื่อให้ความสูง
                  // เท่ากับแท็บที่เลือก และยังคง state ของแต่ละแท็บไว้
                  ...[
                    StatisticsNetWorthLineChart(),
                    StatisticsYearlyBarChart(
                      selectedYear: selectedYear,
                      onYearChanged: (year) =>
                          setState(() => _selectedYear = year),
                    ),
                    StatisticsCategoryPieChart(type: CategoryType.expense),
                    StatisticsCategoryPieChart(type: CategoryType.income),
                  ].indexed.map(
                    (entry) => Visibility(
                      visible: entry.$1 == _selectedTab,
                      maintainState: true,
                      child: entry.$2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
