import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/group_header.dart';
import 'broker_report_form_screen.dart';

class BrokerReportListScreen extends StatelessWidget {
  final String portfolioId;

  const BrokerReportListScreen({super.key, required this.portfolioId});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isDarkMode = settingsProvider.isDarkMode;
    final backgroundColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
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

    final totalInflowUsd = reports.fold<double>(
      0.0,
      (sum, item) => sum + item.inflowUsd,
    );
    final totalInflowThb = reports.fold<double>(
      0.0,
      (sum, item) => sum + item.inflowThb,
    );
    final totalRemittedUsd = reports.fold<double>(
      0.0,
      (sum, item) => sum + item.remittedUsd,
    );
    final totalRemittedThb = reports.fold<double>(
      0.0,
      (sum, item) => sum + item.remittedThb,
    );
    final totalDividendGrossUsd = reports.fold<double>(
      0.0,
      (sum, item) => sum + item.dividendGrossUsd,
    );
    final totalDividendTaxWithheldUsd = reports.fold<double>(
      0.0,
      (sum, item) => sum + item.dividendTaxWithheldUsd,
    );
    final totalDividendNetUsd = reports.fold<double>(
      0.0,
      (sum, item) => sum + item.dividendNetUsd,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Material(
            color: surfaceColor,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: isDarkMode
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'รายงานประจำปี Broker',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDarkMode
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: surfaceColor,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: isDarkMode
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
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
            ),
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
          : Column(
              children: [
                // Summary of all years
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(AppRadii.xLarge),
                    border: Border.all(
                      color: dividerColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics, color: textColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'ผลรวมทุกปี',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            "เงินทุน USD",
                            style: TextStyle(fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            '${currencyFormat.format(totalInflowUsd)} USD',
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
                          const Text(
                            "เงินทุน THB",
                            style: TextStyle(fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            '${currencyFormat.format(totalInflowThb)} THB',
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
                          const Text(
                            "โอนกลับ USD",
                            style: TextStyle(fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            '${currencyFormat.format(totalRemittedUsd)} USD',
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
                          const Text(
                            "โอนกลับ THB",
                            style: TextStyle(fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            '${currencyFormat.format(totalRemittedThb)} THB',
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
                          const Text(
                            "ปันผลรวม",
                            style: TextStyle(fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            '${currencyFormat.format(totalDividendGrossUsd)} USD',
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
                          const Text(
                            "ภาษีปันผล",
                            style: TextStyle(fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            '${currencyFormat.format(totalDividendTaxWithheldUsd)} USD',
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
                          const Text(
                            "ปันผลสุทธิ",
                            style: TextStyle(fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            '${currencyFormat.format(totalDividendNetUsd)} USD',
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
                GroupHeader(title: 'แยกตามรายปี', isDarkMode: isDarkMode),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(AppRadii.xLarge),
                      border: Border.all(
                        color: dividerColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: ListView.separated(
                      itemCount: reports.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: AppColors.listDividerFor(isDarkMode),
                      ),
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
                                      const Text(
                                        "เงินทุน USD",
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      const Spacer(),
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
                                      const Text(
                                        "เงินทุน THB",
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      const Spacer(),
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
                                      const Text(
                                        "โอนกลับ USD",
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      const Spacer(),
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
                                      const Text(
                                        "โอนกลับ THB",
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      const Spacer(),
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
                                      const Text(
                                        "ปันผลรวม",
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      const Spacer(),
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
                                      const Text(
                                        "ภาษีปันผล",
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      const Spacer(),
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
                                      const Text(
                                        "ปันผลสุทธิ",
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      const Spacer(),
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
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
    );
  }
}
