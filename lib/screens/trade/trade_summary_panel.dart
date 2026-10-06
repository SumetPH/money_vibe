import 'package:flutter/material.dart';

import '../../main.dart';
import '../../theme/app_colors.dart';
import 'trade_tracker_models.dart';
import 'trade_tracker_widgets.dart';

class TradeSummaryPanel extends StatelessWidget {
  final TradeSummary summary;
  final bool isDarkMode;

  const TradeSummaryPanel({
    super.key,
    required this.summary,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final profitColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final lossColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final pnlColor = AppColors.getAmountColor(
      summary.realizedPnlUsd,
      isDarkMode,
    );
    return TradeInsetCard(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Realized P/L (Est. / Broker)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: secondaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '${summary.tradeCount} รายการ',
                style: TextStyle(fontSize: 12, color: secondaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.realizedPnlUsd >= 0 ? '+' : ''}${formatAmount(summary.realizedPnlUsd)} USD',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: pnlColor,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TradeSummaryMetric(
                  label: 'เงินสดรับจากการขาย',
                  value: '${formatAmount(summary.cashReceivedUsd)} USD',
                  color: textColor,
                ),
              ),
              Expanded(
                child: TradeSummaryMetric(
                  label: 'กำไร',
                  value: '${formatAmount(summary.profitUsd)} USD',
                  color: profitColor,
                  alignEnd: true,
                ),
              ),
              Expanded(
                child: TradeSummaryMetric(
                  label: 'ขาดทุน',
                  value: '${formatAmount(summary.lossUsd.abs())} USD',
                  color: lossColor,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Win/Loss ${summary.winCount}/${summary.lossCount}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class TradeFeeSummaryPanel extends StatelessWidget {
  final TradeFeeSummary summary;
  final bool isDarkMode;

  const TradeFeeSummaryPanel({
    super.key,
    required this.summary,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return TradeInsetCard(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: TradeFeeSummaryBreakdown(summary: summary, isDarkMode: isDarkMode),
    );
  }
}

class TradeFeeSummaryBreakdown extends StatelessWidget {
  final TradeFeeSummary summary;
  final bool isDarkMode;

  const TradeFeeSummaryBreakdown({
    super.key,
    required this.summary,
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
    final feeColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'สรุปค่าธรรมเนียม',
          style: TextStyle(
            color: secondaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${formatAmount(summary.totalFeesUsd)} USD',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: feeColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TradeSummaryMetric(
                label: 'Broker',
                value: '${formatAmount(summary.brokerFeeUsd)} USD',
                color: textColor,
              ),
            ),
            Expanded(
              child: TradeSummaryMetric(
                label: 'VAT',
                value: '${formatAmount(summary.taxFeeUsd)} USD',
                color: textColor,
                alignEnd: true,
              ),
            ),
            Expanded(
              child: TradeSummaryMetric(
                label: 'SEC/TAF',
                value: '${formatAmount(summary.exchangeFeeUsd)} USD',
                color: textColor,
                alignEnd: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TradeSummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  const TradeSummaryMetric({
    super.key,
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
    );
  }
}
