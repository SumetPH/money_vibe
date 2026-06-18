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
        title: const Text('รายงานประจำปี (Broker)'),
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
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ปี ${report.year}',
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'เงินทุน ${currencyFormat.format(report.inflowUsd)} USD'
                                  ' / ${currencyFormat.format(report.inflowThb)} THB'
                                  '\n • โอนกลับ ${currencyFormat.format(report.remittedUsd)} USD'
                                  '\n • ปันผลสุทธิ ${currencyFormat.format(report.dividendNetUsd)} USD'
                                  '\n • ภาษี ${currencyFormat.format(report.dividendTaxWithheldUsd)} USD',
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: secondaryTextColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${currencyFormat.format(report.inflowUsd)} USD',
                                style: TextStyle(
                                  color: incomeColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${currencyFormat.format(report.inflowThb)} THB',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'เงินทุน',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 11,
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: incomeColor,
        foregroundColor: AppColors.darkTextPrimary,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BrokerReportFormScreen(portfolioId: portfolioId),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
