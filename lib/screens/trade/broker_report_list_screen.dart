import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import 'broker_report_form_screen.dart';

class BrokerReportListScreen extends StatelessWidget {
  final String portfolioId;

  const BrokerReportListScreen({super.key, required this.portfolioId});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final backgroundColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final headerColor = isDarkMode ? AppColors.darkHeader : AppColors.header;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryTextColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final transferColor = isDarkMode
        ? AppColors.darkTransfer
        : AppColors.transfer;
    final debtRepayColor = isDarkMode
        ? AppColors.darkDebtRepay
        : AppColors.debtRepay;

    final accountProvider = context.watch<AccountProvider>();
    final portfolio = accountProvider.findById(portfolioId);

    if (portfolio == null) {
      return const Scaffold(body: Center(child: Text('Portfolio not found')));
    }

    final reports = accountProvider.getPortfolioAnnualReportsForPortfolio(
      portfolioId,
    );
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 2);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: textColor,
        elevation: 0,
        title: const Text('รายงานประจำปี Broker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      BrokerReportFormScreen(portfolioId: portfolioId),
                ),
              );
            },
          ),
        ],
      ),
      body: reports.isEmpty
          ? Center(
              child: Text(
                'ยังไม่มีข้อมูลยอดสะสมรายปี\nกดปุ่ม + เพื่อเพิ่มรายงาน',
                textAlign: TextAlign.center,
                style: TextStyle(color: secondaryTextColor),
              ),
            )
          : ListView.separated(
              itemCount: reports.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: dividerColor),
              itemBuilder: (context, index) {
                final report = reports[index];
                return Material(
                  color: surfaceColor,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BrokerReportFormScreen(
                            portfolioId: portfolioId,
                            existingReport: report,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                'ปี ${report.year}',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                "เงินทุน USD",
                                style: TextStyle(fontSize: 14),
                              ),
                              Spacer(),
                              Text(
                                '${currencyFormat.format(report.inflowUsd)} USD',
                                style: TextStyle(
                                  color: incomeColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                "เงินทุน THB",
                                style: TextStyle(fontSize: 13),
                              ),
                              Spacer(),
                              Text(
                                '${currencyFormat.format(report.inflowThb)} THB',
                                style: TextStyle(
                                  color: incomeColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                "โอนกลับ USD",
                                style: TextStyle(fontSize: 13),
                              ),
                              Spacer(),
                              Text(
                                '${currencyFormat.format(report.remittedUsd)} USD',
                                style: TextStyle(
                                  color: transferColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                "โอนกลับ THB",
                                style: TextStyle(fontSize: 13),
                              ),
                              Spacer(),
                              Text(
                                '${currencyFormat.format(report.remittedThb)} THB',
                                style: TextStyle(
                                  color: transferColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text("ปันผลรวม", style: TextStyle(fontSize: 13)),
                              Spacer(),
                              Text(
                                '${currencyFormat.format(report.dividendGrossUsd)} USD',
                                style: TextStyle(
                                  color: debtRepayColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text("ภาษีปันผล", style: TextStyle(fontSize: 13)),
                              Spacer(),
                              Text(
                                '${currencyFormat.format(report.dividendTaxWithheldUsd)} USD',
                                style: TextStyle(
                                  color: debtRepayColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                "ปันผลสุทธิ",
                                style: TextStyle(fontSize: 13),
                              ),
                              Spacer(),
                              Text(
                                '${currencyFormat.format(report.dividendNetUsd)} USD',
                                style: TextStyle(
                                  color: debtRepayColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
