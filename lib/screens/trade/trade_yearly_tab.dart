import 'package:flutter/material.dart';

import '../../models/stock_trade.dart';
import '../../theme/app_colors.dart';
import 'trade_tracker_models.dart';
import 'trade_sale_history_tab.dart';
import 'trade_summary_panel.dart';
import 'trade_tracker_widgets.dart';

class TradeYearlyTab extends StatelessWidget {
  final Widget header;
  final List<StockTrade> trades;
  final int selectedYear;
  final ValueChanged<int> onYearChanged;
  final bool isDarkMode;

  const TradeYearlyTab({
    super.key,
    required this.header,
    required this.trades,
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
    final yearTrades = trades
        .where((trade) => trade.soldAt.year == selectedYear)
        .toList();
    final summary = TradeSummary.fromTrades(yearTrades);
    final monthlySummaries = _monthlySummaries(yearTrades);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverToBoxAdapter(
          child: TradeYearSelector(
            selectedYear: selectedYear,
            onYearChanged: onYearChanged,
          ),
        ),
        SliverToBoxAdapter(
          child: TradeSummaryPanel(summary: summary, isDarkMode: isDarkMode),
        ),
        if (yearTrades.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: TradeEmptyState(
              isDarkMode: isDarkMode,
              textColor: secondaryColor,
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Container(
              height: 28.0,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
          ),
          SliverToBoxAdapter(
            child: TradeMonthlyTable(
              summaries: monthlySummaries,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  List<TradeMonthlySummary> _monthlySummaries(List<StockTrade> trades) {
    final tradesByMonth = List.generate(12, (_) => <StockTrade>[]);
    for (final trade in trades) {
      tradesByMonth[trade.soldAt.month - 1].add(trade);
    }

    return List.generate(12, (index) {
      return TradeMonthlySummary(
        month: index + 1,
        summary: TradeSummary.fromTrades(tradesByMonth[index]),
      );
    });
  }
}
