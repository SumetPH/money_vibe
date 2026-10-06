import '../../models/portfolio_annual_report.dart';
import '../../models/stock_trade.dart';
import '../../models/stock_purchase.dart';

enum TradePnlFilter { all, profit, loss }

String formatTradeDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String formatTradeShares(double value) =>
    value.toStringAsFixed(7).replaceFirst(RegExp(r'\.?0+$'), '');

class TradePurchaseMonthGroup {
  final int year;
  final int month;
  final List<StockPurchase> purchases;

  const TradePurchaseMonthGroup({
    required this.year,
    required this.month,
    required this.purchases,
  });
}

List<TradePurchaseMonthGroup> groupTradePurchasesByMonth(
  List<StockPurchase> purchases,
) {
  final groups = <TradePurchaseMonthGroup>[];
  for (final purchase in purchases) {
    final index = groups.indexWhere(
      (group) =>
          group.year == purchase.boughtAt.year &&
          group.month == purchase.boughtAt.month,
    );
    if (index == -1) {
      groups.add(
        TradePurchaseMonthGroup(
          year: purchase.boughtAt.year,
          month: purchase.boughtAt.month,
          purchases: [purchase],
        ),
      );
    } else {
      groups[index].purchases.add(purchase);
    }
  }
  return groups;
}

class TradeAnnualTaxSummary {
  final double remittedUsd;
  final double remittedThb;
  final double principalUsedUsd;
  final double taxableUsd;
  final double taxableThb;
  final int reportCount;

  const TradeAnnualTaxSummary({
    required this.remittedUsd,
    required this.remittedThb,
    required this.principalUsedUsd,
    required this.taxableUsd,
    required this.taxableThb,
    required this.reportCount,
  });

  factory TradeAnnualTaxSummary.fromReports({
    required List<PortfolioAnnualReport> reports,
    required double principalAvailableForYearUsd,
  }) {
    var remittedUsd = 0.0;
    var remittedThb = 0.0;
    var reportCount = 0;
    for (final report in reports) {
      remittedUsd += report.remittedUsd;
      remittedThb += report.remittedThb;
      if (report.remittedUsd > 0) reportCount++;
    }
    final principalUsedUsd = remittedUsd <= principalAvailableForYearUsd
        ? remittedUsd
        : principalAvailableForYearUsd;
    final taxableUsd = remittedUsd > principalAvailableForYearUsd
        ? remittedUsd - principalAvailableForYearUsd
        : 0.0;
    final effectiveFxRate = remittedUsd > 0 ? remittedThb / remittedUsd : 0.0;

    return TradeAnnualTaxSummary(
      remittedUsd: remittedUsd,
      remittedThb: remittedThb,
      principalUsedUsd: principalUsedUsd,
      taxableUsd: taxableUsd,
      taxableThb: taxableUsd * effectiveFxRate,
      reportCount: reportCount,
    );
  }
}

class TradePortfolioAnnualReportSummary {
  final double inflowUsd;
  final double inflowThb;
  final double dividendGrossUsd;
  final double dividendTaxWithheldUsd;
  final double dividendNetUsd;
  final double remittedUsd;
  final double remittedThb;
  final int reportCount;

  const TradePortfolioAnnualReportSummary({
    required this.inflowUsd,
    required this.inflowThb,
    required this.dividendGrossUsd,
    required this.dividendTaxWithheldUsd,
    required this.dividendNetUsd,
    required this.remittedUsd,
    required this.remittedThb,
    required this.reportCount,
  });

  factory TradePortfolioAnnualReportSummary.fromReports(
    List<PortfolioAnnualReport> reports,
  ) {
    var inflowUsd = 0.0;
    var inflowThb = 0.0;
    var dividendGrossUsd = 0.0;
    var dividendTaxWithheldUsd = 0.0;
    var dividendNetUsd = 0.0;
    var remittedUsd = 0.0;
    var remittedThb = 0.0;

    for (final report in reports) {
      inflowUsd += report.inflowUsd;
      inflowThb += report.inflowThb;
      dividendGrossUsd += report.dividendGrossUsd;
      dividendTaxWithheldUsd += report.dividendTaxWithheldUsd;
      dividendNetUsd += report.dividendNetUsd;
      remittedUsd += report.remittedUsd;
      remittedThb += report.remittedThb;
    }

    return TradePortfolioAnnualReportSummary(
      inflowUsd: inflowUsd,
      inflowThb: inflowThb,
      dividendGrossUsd: dividendGrossUsd,
      dividendTaxWithheldUsd: dividendTaxWithheldUsd,
      dividendNetUsd: dividendNetUsd,
      remittedUsd: remittedUsd,
      remittedThb: remittedThb,
      reportCount: reports.length,
    );
  }
}

class TradeMonthlySummary {
  final int month;
  final TradeSummary summary;

  const TradeMonthlySummary({required this.month, required this.summary});
}

class TradeMonthGroup {
  final int year;
  final int month;
  final List<StockTrade> trades;

  const TradeMonthGroup({
    required this.year,
    required this.month,
    required this.trades,
  });
}

List<TradeMonthGroup> groupTradesByMonth(List<StockTrade> trades) {
  final sortedTrades = [...trades]
    ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
  final groups = <TradeMonthGroup>[];

  for (final trade in sortedTrades) {
    final existingIndex = groups.indexWhere(
      (group) =>
          group.year == trade.soldAt.year && group.month == trade.soldAt.month,
    );

    if (existingIndex == -1) {
      groups.add(
        TradeMonthGroup(
          year: trade.soldAt.year,
          month: trade.soldAt.month,
          trades: [trade],
        ),
      );
      continue;
    }

    groups[existingIndex].trades.add(trade);
  }

  return groups;
}

String tradeMonthShortLabel(int month) {
  const labels = [
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
  return labels[month - 1];
}

String tradeMonthFullLabel(int month) {
  const labels = [
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
  return labels[month - 1];
}

class TradeSummary {
  final double cashReceivedUsd;
  final double realizedPnlUsd;
  final double profitUsd;
  final double lossUsd;
  final int tradeCount;
  final int winCount;
  final int lossCount;

  const TradeSummary({
    required this.cashReceivedUsd,
    required this.realizedPnlUsd,
    required this.profitUsd,
    required this.lossUsd,
    required this.tradeCount,
    required this.winCount,
    required this.lossCount,
  });

  factory TradeSummary.fromTrades(List<StockTrade> trades) {
    var cashReceivedUsd = 0.0;
    var realizedPnlUsd = 0.0;
    var profitUsd = 0.0;
    var lossUsd = 0.0;
    var winCount = 0;
    var lossCount = 0;

    for (final trade in trades) {
      cashReceivedUsd += trade.cashReceivedUsd;
      realizedPnlUsd += trade.realizedPnlUsd;
      if (trade.realizedPnlUsd > 0) {
        profitUsd += trade.realizedPnlUsd;
        winCount++;
      } else if (trade.realizedPnlUsd < 0) {
        lossUsd += trade.realizedPnlUsd;
        lossCount++;
      }
    }

    return TradeSummary(
      cashReceivedUsd: cashReceivedUsd,
      realizedPnlUsd: realizedPnlUsd,
      profitUsd: profitUsd,
      lossUsd: lossUsd,
      tradeCount: trades.length,
      winCount: winCount,
      lossCount: lossCount,
    );
  }
}

class TradeFeeSummary {
  final double brokerFeeUsd;
  final double exchangeFeeUsd;
  final double taxFeeUsd;

  const TradeFeeSummary({
    required this.brokerFeeUsd,
    required this.exchangeFeeUsd,
    required this.taxFeeUsd,
  });

  double get totalFeesUsd => brokerFeeUsd + exchangeFeeUsd + taxFeeUsd;

  factory TradeFeeSummary.fromTrades(List<StockTrade> trades) =>
      TradeFeeSummary._from(
        trades.map(
          (trade) => (
            broker: trade.brokerFeeUsd ?? 0,
            exchange: trade.exchangeFeeUsd ?? 0,
            tax: trade.taxFeeUsd ?? 0,
          ),
        ),
      );

  factory TradeFeeSummary.fromPurchases(List<StockPurchase> purchases) =>
      TradeFeeSummary._from(
        purchases.map(
          (purchase) => (
            broker: purchase.brokerFeeUsd ?? 0,
            exchange: purchase.exchangeFeeUsd ?? 0,
            tax: purchase.taxFeeUsd ?? 0,
          ),
        ),
      );

  factory TradeFeeSummary._from(
    Iterable<({double broker, double exchange, double tax})> fees,
  ) {
    var brokerFeeUsd = 0.0;
    var exchangeFeeUsd = 0.0;
    var taxFeeUsd = 0.0;
    for (final fee in fees) {
      brokerFeeUsd += fee.broker;
      exchangeFeeUsd += fee.exchange;
      taxFeeUsd += fee.tax;
    }
    return TradeFeeSummary(
      brokerFeeUsd: brokerFeeUsd,
      exchangeFeeUsd: exchangeFeeUsd,
      taxFeeUsd: taxFeeUsd,
    );
  }
}
