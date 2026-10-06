import '../../widgets/app_inset_card.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/stock_trade.dart';
import '../../theme/app_colors.dart';
import '../../widgets/group_header.dart';
import 'trade_tracker_models.dart';
import 'trade_summary_panel.dart';
import 'trade_list_item.dart';
import 'trade_tracker_widgets.dart';

class TradeSaleHistoryTab extends StatelessWidget {
  final Widget header;
  final List<StockTrade> trades;
  final bool isDarkMode;
  final String Function(StockTrade trade) portfolioNameOf;
  final ValueChanged<StockTrade> onEdit;
  final ValueChanged<StockTrade> onDelete;

  const TradeSaleHistoryTab({
    super.key,
    required this.header,
    required this.trades,
    required this.isDarkMode,
    required this.portfolioNameOf,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final sections = groupTradesByMonth(trades);
    final feeSummary = TradeFeeSummary.fromTrades(trades);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverToBoxAdapter(child: SizedBox(height: 6)),
        SliverToBoxAdapter(
          child: TradeFeeSummaryPanel(
            summary: feeSummary,
            isDarkMode: isDarkMode,
          ),
        ),
        if (trades.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: TradeEmptyState(
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => TradeMonthSection(
                section: sections[index],
                isDarkMode: isDarkMode,
                portfolioNameOf: portfolioNameOf,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
              childCount: sections.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class TradeMonthSection extends StatelessWidget {
  final TradeMonthGroup section;
  final bool isDarkMode;
  final String Function(StockTrade trade) portfolioNameOf;
  final ValueChanged<StockTrade> onEdit;
  final ValueChanged<StockTrade> onDelete;

  const TradeMonthSection({
    super.key,
    required this.section,
    required this.isDarkMode,
    required this.portfolioNameOf,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupHeader(
          title: '${tradeMonthFullLabel(section.month)} ${section.year}',
          isDarkMode: isDarkMode,
          trailing: [
            Text(
              '${section.trades.length} รายการ',
              style: TextStyle(
                color: secondaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        AppInsetCard(
          margin: AppInsetCard.stackedMargin,
          children: [
            Column(
              children: section.trades.asMap().entries.map((entry) {
                final index = entry.key;
                final trade = entry.value;

                return Column(
                  children: [
                    TradeListItem(
                      trade: trade,
                      portfolioName: portfolioNameOf(trade),
                      isDarkMode: isDarkMode,
                      onEdit: () => onEdit(trade),
                      onDelete: () => onDelete(trade),
                    ),
                    if (index != section.trades.length - 1)
                      Divider(
                        height: 1,
                        color: AppColors.listDividerFor(isDarkMode),
                      ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }
}

class TradeMonthlyTable extends StatelessWidget {
  final List<TradeMonthlySummary> summaries;
  final bool isDarkMode;

  const TradeMonthlyTable({
    super.key,
    required this.summaries,
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
    final profitColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final lossColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    return AppInsetCard(
      margin: AppInsetCard.stackedMargin,
      children: [
        Column(
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
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'จำนวน',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'กำไร',
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
                      'ขาดทุน',
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
                      'สุทธิ',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.listDividerFor(isDarkMode)),
            ...summaries.asMap().entries.map((entry) {
              final index = entry.key;
              final monthSummary = entry.value;
              final summary = monthSummary.summary;
              final hasData = summary.tradeCount > 0;
              final pnl = summary.realizedPnlUsd;
              final pnlColor = AppColors.getAmountColor(pnl, isDarkMode);

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
                            tradeMonthShortLabel(monthSummary.month),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            hasData ? '${summary.tradeCount}' : '-',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              color: hasData ? textColor : secondaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            hasData && summary.profitUsd > 0
                                ? formatAmount(summary.profitUsd)
                                : '-',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              color: summary.profitUsd > 0
                                  ? profitColor
                                  : secondaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            hasData && summary.lossUsd < 0
                                ? formatAmount(summary.lossUsd.abs())
                                : '-',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              color: summary.lossUsd < 0
                                  ? lossColor
                                  : secondaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            hasData
                                ? '${pnl >= 0 ? '+' : ''}${formatAmount(pnl)}'
                                : '-',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: hasData ? pnlColor : secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index != summaries.length - 1)
                    Divider(
                      height: 1,
                      color: AppColors.listDividerFor(isDarkMode),
                    ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}
