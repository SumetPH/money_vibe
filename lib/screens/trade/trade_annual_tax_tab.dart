import '../../widgets/app_metric_text.dart';
import '../../widgets/app_inset_card.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/portfolio_annual_report.dart';
import '../../models/stock_trade.dart';
import '../../theme/app_colors.dart';
import 'trade_tracker_models.dart';
import 'trade_tracker_widgets.dart';

class TradeAnnualTaxTab extends StatelessWidget {
  final Widget header;
  final List<StockTrade> trades;
  final List<PortfolioAnnualReport> annualReports;
  final int selectedYear;
  final double principalAvailableForYearUsd;
  final double principalQuotaRemainingUsd;
  final ValueChanged<int> onYearChanged;
  final bool isDarkMode;

  const TradeAnnualTaxTab({
    super.key,
    required this.header,
    required this.trades,
    required this.annualReports,
    required this.selectedYear,
    required this.principalAvailableForYearUsd,
    required this.principalQuotaRemainingUsd,
    required this.onYearChanged,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final yearTrades = trades
        .where((trade) => trade.soldAt.year == selectedYear)
        .toList();
    final yearAnnualReports = annualReports
        .where((report) => report.year == selectedYear)
        .toList();
    final tradeSummary = TradeSummary.fromTrades(yearTrades);
    final annualReportSummary = TradePortfolioAnnualReportSummary.fromReports(
      yearAnnualReports,
    );
    final annualTaxSummary = TradeAnnualTaxSummary.fromReports(
      reports: yearAnnualReports,
      principalAvailableForYearUsd: principalAvailableForYearUsd,
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverToBoxAdapter(child: SizedBox(height: 6)),
        SliverToBoxAdapter(
          child: TradeYearSelector(
            selectedYear: selectedYear,
            onYearChanged: onYearChanged,
          ),
        ),
        SliverToBoxAdapter(
          child: TradeAnnualTaxSummaryPanel(
            tradeSummary: tradeSummary,
            annualReportSummary: annualReportSummary,
            annualTaxSummary: annualTaxSummary,
            isDarkMode: isDarkMode,
          ),
        ),
        SliverToBoxAdapter(
          child: TradeAnnualPrincipalSummarySection(
            annualTaxSummary: annualTaxSummary,
            principalQuotaRemainingUsd: principalQuotaRemainingUsd,
            isDarkMode: isDarkMode,
          ),
        ),
        if (yearAnnualReports.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: TradeEmptyState(
              isDarkMode: isDarkMode,
              textColor: secondaryColor,
              icon: Icons.receipt_long_outlined,
              message: 'ยังไม่มีรายงาน Broker ปีนี้',
              description:
                  'กรอกยอดเงินทุน ปันผล และยอดโอนกลับไทยในรายงานประจำปีของพอร์ต',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final report = yearAnnualReports[index];
              return TradeAnnualReportTaxListItem(
                report: report,
                isDarkMode: isDarkMode,
              );
            }, childCount: yearAnnualReports.length),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class TradeAnnualTaxSummaryPanel extends StatelessWidget {
  final TradeSummary tradeSummary;
  final TradePortfolioAnnualReportSummary annualReportSummary;
  final TradeAnnualTaxSummary annualTaxSummary;
  final bool isDarkMode;

  const TradeAnnualTaxSummaryPanel({
    super.key,
    required this.tradeSummary,
    required this.annualReportSummary,
    required this.annualTaxSummary,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final taxableColor = AppColors.getAmountColor(
      annualTaxSummary.taxableUsd,
      isDarkMode,
    );

    return AppInsetCard(
      margin: AppInsetCard.stackedMargin,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'ยอดโอนกลับส่วนเกินเงินต้น',
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatAmount(annualTaxSummary.taxableThb)} THB',
                      style: TextStyle(
                        color: taxableColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatAmount(annualTaxSummary.taxableUsd)} USD',
                      style: TextStyle(
                        color: secondaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                AppMetricText(
                  label: 'โอนกลับรวม',
                  value: '${formatAmount(annualTaxSummary.remittedUsd)} USD',
                  valueColor: secondaryColor,
                  alignEnd: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppMetricText(
                    label: 'กำไรขายหุ้น',
                    value: '${formatAmount(tradeSummary.profitUsd)} USD',
                    valueColor: AppColors.getAmountColor(
                      tradeSummary.profitUsd,
                      isDarkMode,
                    ),
                  ),
                ),
                Expanded(
                  child: AppMetricText(
                    label: 'ปันผลรวม',
                    value:
                        '${formatAmount(annualReportSummary.dividendGrossUsd)} USD',
                    valueColor: AppColors.getAmountColor(
                      annualReportSummary.dividendGrossUsd,
                      isDarkMode,
                    ),
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppMetricText(
                    label: 'ภาษีปันผลหักไว้',
                    value:
                        '${formatAmount(annualReportSummary.dividendTaxWithheldUsd)} USD',
                    valueColor: isDarkMode
                        ? AppColors.darkExpense
                        : AppColors.expense,
                  ),
                ),
                Expanded(
                  child: AppMetricText(
                    label: 'ปันผลสุทธิ',
                    value:
                        '${formatAmount(annualReportSummary.dividendNetUsd)} USD',
                    valueColor: secondaryColor,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'ถ้ายอดโอนกลับเกินเงินต้น ยอดเกินทุนคือเงินได้ที่นำกลับไทยและเป็นตัวเลขหลักที่ต้องเอาไปดูภาษี',
              style: TextStyle(color: secondaryColor, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class TradeAnnualPrincipalSummarySection extends StatelessWidget {
  final TradeAnnualTaxSummary annualTaxSummary;
  final double principalQuotaRemainingUsd;
  final bool isDarkMode;

  const TradeAnnualPrincipalSummarySection({
    super.key,
    required this.annualTaxSummary,
    required this.principalQuotaRemainingUsd,
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

    return AppInsetCard(
      margin: AppInsetCard.stackedMargin,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'โควต้าเงินต้นปีที่เลือก',
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppMetricText(
                    label: 'โอนกลับรวม',
                    value: '${formatAmount(annualTaxSummary.remittedUsd)} USD',
                    valueColor: textColor,
                  ),
                ),
                Expanded(
                  child: AppMetricText(
                    label: 'เงินต้นใช้แล้ว',
                    value:
                        '${formatAmount(annualTaxSummary.principalUsedUsd)} USD',
                    valueColor: textColor,
                    alignEnd: true,
                  ),
                ),
                Expanded(
                  child: AppMetricText(
                    label: 'โควต้าคงเหลือ',
                    value: '${formatAmount(principalQuotaRemainingUsd)} USD',
                    valueColor: textColor,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'คำนวณจากเงินต้นสะสมถึงปีที่เลือก หักเงินต้นที่โอนกลับแล้ว',
              style: TextStyle(color: secondaryColor, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class TradeAnnualReportTaxListItem extends StatelessWidget {
  final PortfolioAnnualReport report;
  final bool isDarkMode;

  const TradeAnnualReportTaxListItem({
    super.key,
    required this.report,
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

    return AppInsetCard(
      margin: AppInsetCard.stackedMargin,
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${formatAmount(report.remittedUsd)} USD',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${formatAmount(report.remittedThb)} THB',
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TradeCompactTaxMetric(
                          label: 'เงินทุน',
                          value:
                              '${formatAmount(report.inflowUsd)} USD \n${formatAmount(report.inflowThb)} THB',
                          color: secondaryColor,
                        ),
                      ),
                      Expanded(
                        child: TradeCompactTaxMetric(
                          label: 'ปันผลรวม',
                          value: '${formatAmount(report.dividendGrossUsd)} USD',
                          color: secondaryColor,
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TradeCompactTaxMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  const TradeCompactTaxMetric({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
