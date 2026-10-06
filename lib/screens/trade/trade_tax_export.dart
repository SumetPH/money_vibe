import 'package:csv/csv.dart';

import '../../models/portfolio_annual_report.dart';
import '../../models/stock_trade.dart';
import 'trade_tracker_models.dart';

Map<String, String> buildYearlyTaxExportFiles({
  required int year,
  required List<StockTrade> trades,
  required List<PortfolioAnnualReport> annualReports,
  required double principalAvailableForYearUsd,
  required String Function(String portfolioId) portfolioNameOf,
}) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;

  return {
    'tax_summary_${year}_$timestamp.csv': buildTaxSummaryCsv(
      year: year,
      trades: trades,
      annualReports: annualReports,
      principalAvailableForYearUsd: principalAvailableForYearUsd,
    ),
    'tax_stock_trades_${year}_$timestamp.csv': buildTaxStockTradesCsv(
      trades: trades,
      portfolioNameOf: portfolioNameOf,
    ),
    'tax_broker_reports_${year}_$timestamp.csv': buildTaxBrokerReportsCsv(
      annualReports: annualReports,
      portfolioNameOf: portfolioNameOf,
    ),
  };
}

String buildTaxSummaryCsv({
  required int year,
  required List<StockTrade> trades,
  required List<PortfolioAnnualReport> annualReports,
  required double principalAvailableForYearUsd,
}) {
  final tradeSummary = TradeSummary.fromTrades(trades);
  final annualReportSummary = TradePortfolioAnnualReportSummary.fromReports(
    annualReports,
  );
  final annualTaxSummary = TradeAnnualTaxSummary.fromReports(
    reports: annualReports,
    principalAvailableForYearUsd: principalAvailableForYearUsd,
  );
  final totalGrossProceeds = trades.fold(
    0.0,
    (sum, trade) => sum + (trade.grossProceedsUsd ?? trade.proceedsUsd),
  );
  final totalCost = trades.fold(
    0.0,
    (sum, trade) => sum + (trade.costBasisUsd * trade.sharesSold),
  );
  final totalFees = trades.fold(0.0, (sum, trade) => sum + trade.totalFeesUsd);

  final rows = <List<dynamic>>[
    ['หัวข้อ', 'ค่า', 'สกุลเงิน/หน่วย'],
    ['ปีภาษี', year, ''],
    ['จำนวนรายการขายหุ้น', tradeSummary.tradeCount, 'รายการ'],
    ['ยอดขายรับเงินสดรวม', tradeSummary.cashReceivedUsd, 'USD'],
    ['Gross proceeds รวม', totalGrossProceeds, 'USD'],
    ['ต้นทุนรวม', totalCost, 'USD'],
    ['ค่าธรรมเนียมและภาษีจากรายการขายรวม', totalFees, 'USD'],
    ['กำไรรวม', tradeSummary.profitUsd, 'USD'],
    ['ขาดทุนรวม', tradeSummary.lossUsd, 'USD'],
    ['กำไร/ขาดทุนสุทธิ', tradeSummary.realizedPnlUsd, 'USD'],
    ['จำนวนรายงาน Broker', annualReportSummary.reportCount, 'รายการ'],
    ['เงินทุนเติมเข้า Broker', annualReportSummary.inflowUsd, 'USD'],
    ['เงินทุนเติมเข้า Broker', annualReportSummary.inflowThb, 'THB'],
    ['ปันผลรวม', annualReportSummary.dividendGrossUsd, 'USD'],
    [
      'ภาษีปันผลหัก ณ ที่จ่าย',
      annualReportSummary.dividendTaxWithheldUsd,
      'USD',
    ],
    ['ปันผลสุทธิ', annualReportSummary.dividendNetUsd, 'USD'],
    ['จำนวนรายงานที่มียอดโอนกลับไทย', annualTaxSummary.reportCount, 'รายการ'],
    ['ยอดโอนกลับรวม', annualTaxSummary.remittedUsd, 'USD'],
    ['ยอดโอนกลับรวม', annualTaxSummary.remittedThb, 'THB'],
    ['เงินต้นที่ใช้ได้', principalAvailableForYearUsd, 'USD'],
    ['เงินต้นที่ใช้แล้ว', annualTaxSummary.principalUsedUsd, 'USD'],
    ['เงินได้ที่นำกลับไทย', annualTaxSummary.taxableUsd, 'USD'],
    ['เงินได้ที่นำกลับไทย', annualTaxSummary.taxableThb, 'THB'],
  ];

  return const ListToCsvConverter().convert(rows);
}

String buildTaxBrokerReportsCsv({
  required List<PortfolioAnnualReport> annualReports,
  required String Function(String portfolioId) portfolioNameOf,
}) {
  final rows = <List<dynamic>>[
    [
      'ปี',
      'พอร์ต',
      'เงินทุนเติมเข้า Broker USD',
      'ยอดเงินบาทที่เติมเข้า Broker THB',
      'ปันผลรวม USD',
      'ภาษีปันผลหัก ณ ที่จ่าย USD',
      'ปันผลสุทธิ USD',
      'ยอดโอนกลับไทย USD',
      'ยอดเงินบาทที่ได้รับ THB',
      'หมายเหตุ',
    ],
  ];

  for (final report in annualReports) {
    rows.add([
      report.year,
      portfolioNameOf(report.portfolioId),
      report.inflowUsd,
      report.inflowThb,
      report.dividendGrossUsd,
      report.dividendTaxWithheldUsd,
      report.dividendNetUsd,
      report.remittedUsd,
      report.remittedThb,
      report.note,
    ]);
  }

  return const ListToCsvConverter().convert(rows);
}

String buildTaxStockTradesCsv({
  required List<StockTrade> trades,
  required String Function(String portfolioId) portfolioNameOf,
}) {
  final rows = <List<dynamic>>[
    [
      'วันที่ขาย',
      'วันที่ settle',
      'พอร์ต',
      'Ticker',
      'ชื่อ',
      'จำนวนหุ้น',
      'ราคาขายต่อหุ้น USD',
      'Gross proceeds USD',
      'เงินสดรับ USD',
      'ต้นทุนต่อหุ้น USD',
      'ต้นทุนรวม USD',
      'ค่าธรรมเนียม broker USD',
      'ค่าธรรมเนียม exchange USD',
      'Tax/VAT USD',
      'ค่าธรรมเนียมรวม USD',
      'กำไร/ขาดทุน USD',
      'วิธีต้นทุน',
      'แหล่งกำไรขาดทุน',
      'เลขอ้างอิง broker',
    ],
  ];

  for (final trade in trades) {
    rows.add([
      formatTaxCsvDate(trade.soldAt),
      trade.settledAt == null ? '' : formatTaxCsvDate(trade.settledAt!),
      portfolioNameOf(trade.portfolioId),
      trade.ticker,
      trade.name,
      trade.sharesSold,
      trade.sellPriceUsd,
      trade.grossProceedsUsd ?? trade.proceedsUsd,
      trade.cashReceivedUsd,
      trade.costBasisUsd,
      trade.costBasisUsd * trade.sharesSold,
      trade.brokerFeeUsd ?? 0,
      trade.exchangeFeeUsd ?? 0,
      trade.taxFeeUsd ?? 0,
      trade.totalFeesUsd,
      trade.realizedPnlUsd,
      tradeCostMethodLabel(trade.costMethod),
      tradePnlSourceLabel(trade.pnlSource),
      trade.brokerOrderRef ?? '',
    ]);
  }

  return const ListToCsvConverter().convert(rows);
}

String formatTaxCsvDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String tradeCostMethodLabel(CostMethod method) {
  switch (method) {
    case CostMethod.average:
      return 'Average';
    case CostMethod.fifo:
      return 'FIFO';
    case CostMethod.specific:
      return 'Specific';
  }
}

String tradePnlSourceLabel(PnlSource source) {
  switch (source) {
    case PnlSource.estimated:
      return 'Estimated';
    case PnlSource.manual:
      return 'Manual';
    case PnlSource.broker:
      return 'Broker';
  }
}
