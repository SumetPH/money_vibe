# 03 statistics_screen.dart (2,417 lines)

Status: ready-for-agent

Proposed files in `lib/screens/statistics/`:
- `statistics_screen.dart` — State, tabs, year selection
- `statistics_models.dart` — `_MonthlyData`, `_CategoryData`, `_NetWorthData`, `_NetWorthPeriodFilter`
- `statistics_yearly_bar_chart.dart` — `_YearlyBarChart` (incl. monthly list), `_YearlySummaryPanel`, `_StatSummaryMetric`, `_LegendItem`
- `statistics_category_pie_chart.dart` — `_CategoryPieChart`, `_CategoryListItem`
- `statistics_net_worth_chart.dart` — `_NetWorthLineChart` (~950 lines; extract its filter sheet into
  `statistics_net_worth_filter_sheet.dart` and the balance-delta calculation into the models file unchanged)
- `statistics_year_selector.dart` — `_StatsYearSelector`, `_StatisticsInsetCard`
