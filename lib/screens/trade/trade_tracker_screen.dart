import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/stock_trade.dart';
import '../../models/stock_purchase.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/stock_price_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../utils/csv_file_io.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_drawer_button.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import 'broker_report_list_screen.dart';
import 'stock_trade_form_screen.dart';
import '../account/holding_buy_form_screen.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_segmented_tabs.dart';
import 'trade_tracker_models.dart';
import 'trade_tax_export.dart';
import 'trade_sale_history_tab.dart';
import 'trade_purchase_history_tab.dart';
import 'trade_yearly_tab.dart';
import 'trade_annual_tax_tab.dart';
import 'trade_filter_bar.dart';
import '../../utils/user_error_message.dart';

class TradeTrackerScreen extends StatefulWidget {
  const TradeTrackerScreen({super.key});

  @override
  State<TradeTrackerScreen> createState() => _TradeTrackerScreenState();
}

class _TradeTrackerScreenState extends State<TradeTrackerScreen> {
  int _selectedTab = 0;
  late StockPriceService _priceService;
  TradePnlFilter _pnlFilter = TradePnlFilter.all;
  String? _portfolioId;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _priceService = _buildPriceService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _priceService = _buildPriceService();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final tabBar = _buildTabBar();
    final isLargeScreen = MediaQuery.of(context).size.width >= 800;
    final bgColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      drawer: isLargeScreen
          ? null
          : const AppDrawer(currentRoute: '/trade-tracker'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        backgroundColor: bgColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: isLargeScreen ? 24 : 16,
        leading: isLargeScreen ? null : const AppDrawerButton(),
        leadingWidth: 64,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'พอร์ตการลงทุน',
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'บันทึกการลงทุน',
              style: TextStyle(
                color: textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: _buildAppBarActions(context),
      ),
      body: Consumer<AccountProvider>(
        builder: (context, accountProvider, _) {
          final transactions = context
              .watch<TransactionProvider>()
              .transactions;
          final trades = _filteredTrades(accountProvider.stockTrades);
          final portfolioAccounts = accountProvider.accounts
              .where((account) => account.isPortfolio)
              .toList();
          final principalAvailableForYearUsd = portfolioAccounts.fold(0.0, (
            sum,
            portfolio,
          ) {
            final previousPrincipal = accountProvider.getRemainingPrincipalPool(
              portfolio.id,
              transactions,
              targetYear: _selectedYear - 1,
            );
            final currentYearInflow = accountProvider
                .getPortfolioAnnualReportsForPortfolio(portfolio.id)
                .where((report) => report.year == _selectedYear)
                .fold(0.0, (reportSum, report) => reportSum + report.inflowUsd);
            return sum + previousPrincipal + currentYearInflow;
          });
          final principalQuotaRemainingUsd = portfolioAccounts
              .where((account) => account.isPortfolio)
              .fold(
                0.0,
                (sum, portfolio) =>
                    sum +
                    accountProvider.getRemainingPrincipalPool(
                      portfolio.id,
                      transactions,
                      targetYear: _selectedYear,
                    ),
              );

          return SafeArea(
            child: Column(
              children: [
                tabBar,
                // แสดงเฉพาะแท็บที่เลือก (ไม่สไลด์ ใช้แบบเดียวกับหน้าสถิติ)
                Expanded(
                  child: [
                    TradeYearlyTab(
                      trades: accountProvider.stockTrades,
                      selectedYear: _selectedYear,
                      onYearChanged: (year) =>
                          setState(() => _selectedYear = year),
                      isDarkMode: isDarkMode,
                    ),
                    TradeSaleHistoryTab(
                      trades: trades,
                      isDarkMode: isDarkMode,
                      portfolioNameOf: (trade) =>
                          accountProvider.findById(trade.portfolioId)?.name ??
                          'พอร์ตหุ้น',
                      onEdit: (trade) => _openTradeForm(context, trade),
                      onDelete: (trade) => _confirmDeleteTrade(context, trade),
                    ),
                    TradePurchaseHistoryTab(
                      purchases: accountProvider.stockPurchases,
                      isDarkMode: isDarkMode,
                      portfolioNameOf: (purchase) =>
                          accountProvider
                              .findById(purchase.portfolioId)
                              ?.name ??
                          'พอร์ตหุ้น',
                      onEdit: (purchase) =>
                          _openPurchaseHistoryForm(context, purchase),
                      onDelete: (purchase) =>
                          _confirmDeletePurchase(context, purchase),
                    ),
                    TradeAnnualTaxTab(
                      trades: accountProvider.stockTrades,
                      annualReports: accountProvider.portfolioAnnualReports,
                      selectedYear: _selectedYear,
                      principalAvailableForYearUsd:
                          principalAvailableForYearUsd,
                      principalQuotaRemainingUsd: principalQuotaRemainingUsd,
                      onYearChanged: (year) =>
                          setState(() => _selectedYear = year),
                      isDarkMode: isDarkMode,
                    ),
                  ][_selectedTab],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static const _tabLabels = ['สรุป', 'ขาย', 'ซื้อ', 'ภาษีไทย'];

  // แถบแท็บ fixed ด้านบน เนื้อหาของแต่ละแท็บเลื่อนอยู่ด้านล่าง
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: AppSegmentedTabs(
        segments: [
          for (final (index, label) in _tabLabels.indexed)
            AppSegment(
              label: label,
              isSelected: _selectedTab == index,
              onTap: () => setState(() => _selectedTab = index),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    switch (_selectedTab) {
      case 0:
        return [
          _buildAppBarAction(
            context,
            icon: Icons.tune_rounded,
            tooltip: 'ตัวกรอง',
            onPressed: () => _showFilterSheet(context),
          ),
          _buildAppBarAction(
            context,
            icon: Icons.add_rounded,
            tooltip: 'เพิ่ม Trade',
            onPressed: () => _openTradeForm(context, null),
          ),
        ];
      case 1:
        return [];
      case 2:
        return [
          Builder(
            builder: (buttonContext) => _buildAppBarAction(
              buttonContext,
              icon: Icons.file_download_outlined,
              tooltip: 'Export ข้อมูลภาษี',
              onPressed: () => _exportYearlyTaxData(
                context,
                sharePositionOrigin: _shareOriginOf(buttonContext),
              ),
            ),
          ),
          _buildAppBarAction(
            context,
            icon: Icons.edit_document,
            tooltip: 'รายงาน Broker',
            onPressed: () => _openBrokerReportPicker(context),
          ),
        ];
      case 3:
        return [];
    }
    return const [];
  }

  Widget _buildAppBarAction(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          side: BorderSide(color: AppColors.borderFor(isDarkMode), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          icon: Icon(
            icon,
            size: 20,
            color: isDarkMode
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }

  Future<void> _openBrokerReportPicker(BuildContext context) async {
    final provider = context.read<AccountProvider>();
    final portfolios = provider.accounts
        .where((account) => account.isPortfolio)
        .toList();

    if (portfolios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ต้องมีพอร์ตหุ้นก่อนดูรายงาน Broker')),
      );
      return;
    }

    final selectedPortfolio = await showTradePortfolioPickerSheet(
      context: context,
      portfolios: portfolios,
      selectedPortfolioId: _portfolioId,
      isDarkMode: context.read<SettingsProvider>().isDarkMode,
      includeAllOption: false,
    );

    if (!context.mounted ||
        selectedPortfolio is! String ||
        selectedPortfolio.isEmpty) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrokerReportListScreen(portfolioId: selectedPortfolio),
      ),
    );
  }

  Rect? _shareOriginOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _exportYearlyTaxData(
    BuildContext context, {
    Rect? sharePositionOrigin,
  }) async {
    final provider = context.read<AccountProvider>();
    final year = _selectedYear;
    final yearTrades =
        provider.stockTrades
            .where((trade) => trade.soldAt.year == year)
            .toList()
          ..sort((a, b) => a.soldAt.compareTo(b.soldAt));
    final yearAnnualReports =
        provider.portfolioAnnualReports
            .where((report) => report.year == year)
            .toList()
          ..sort((a, b) => a.portfolioId.compareTo(b.portfolioId));
    final transactions = context.read<TransactionProvider>().transactions;
    final portfolioAccounts = provider.accounts
        .where((account) => account.isPortfolio)
        .toList();
    final principalAvailableForYearUsd = portfolioAccounts.fold(0.0, (
      sum,
      portfolio,
    ) {
      final previousPrincipal = provider.getRemainingPrincipalPool(
        portfolio.id,
        transactions,
        targetYear: year - 1,
      );
      final currentYearInflow = provider
          .getPortfolioAnnualReportsForPortfolio(portfolio.id)
          .where((report) => report.year == year)
          .fold(0.0, (reportSum, report) => reportSum + report.inflowUsd);
      return sum + previousPrincipal + currentYearInflow;
    });

    if (yearTrades.isEmpty && yearAnnualReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่มีข้อมูลสำหรับ export ปี $year')),
      );
      return;
    }

    try {
      final files = buildYearlyTaxExportFiles(
        year: year,
        trades: yearTrades,
        annualReports: yearAnnualReports,
        principalAvailableForYearUsd: principalAvailableForYearUsd,
        portfolioNameOf: (portfolioId) =>
            provider.findById(portfolioId)?.name ?? 'พอร์ตหุ้น',
      );
      await saveCsvFiles(files, sharePositionOrigin: sharePositionOrigin);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export ข้อมูลภาษีปี $year แล้ว')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userErrorMessage(error, action: 'Export '))),
      );
    }
  }

  List<StockTrade> _filteredTrades(List<StockTrade> trades) {
    return trades.where((trade) {
      if (_portfolioId != null && trade.portfolioId != _portfolioId) {
        return false;
      }
      switch (_pnlFilter) {
        case TradePnlFilter.profit:
          return trade.realizedPnlUsd > 0;
        case TradePnlFilter.loss:
          return trade.realizedPnlUsd < 0;
        case TradePnlFilter.all:
          return true;
      }
    }).toList();
  }

  StockPriceService _buildPriceService() {
    final settings = context.read<SettingsProvider>();
    return StockPriceService(finnhubApiKey: settings.finnhubApiKey);
  }

  Future<void> _openTradeForm(BuildContext context, StockTrade? trade) async {
    final provider = context.read<AccountProvider>();
    final portfolios = provider.accounts
        .where((account) => account.type == AccountType.portfolio)
        .toList();

    if (portfolios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ต้องมีพอร์ตหุ้นก่อนเพิ่ม Trade')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockTradeFormScreen(
          portfolios: portfolios,
          existing: trade,
          generateId: provider.generateId,
          fetchProfile: (ticker) => _priceService.fetchProfile(ticker),
          onSave: (savedTrade) async {
            if (trade == null) {
              await provider.addStockTrade(savedTrade);
            } else {
              await provider.updateStockTrade(savedTrade);
            }
          },
        ),
      ),
    );
  }

  Future<void> _openPurchaseHistoryForm(
    BuildContext context,
    StockPurchase purchase,
  ) async {
    final provider = context.read<AccountProvider>();
    final portfolios = provider.accounts
        .where((account) => account.isPortfolio)
        .toList();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HoldingBuyFormScreen(
          currencyCode:
              provider.findById(purchase.portfolioId)?.currencyCodeLabel ??
              'USD',
          portfolios: portfolios,
          initialPortfolioId: purchase.portfolioId,
          existingPurchase: purchase,
          onBuy:
              ({
                required ticker,
                required portfolioId,
                required sharesBought,
                required buyPriceUsd,
                required cashPaidUsd,
                required resultingShares,
                required resultingCostBasisUsd,
                required resetPeakProfit,
                grossCostUsd,
                brokerFeeUsd,
                exchangeFeeUsd,
                taxFeeUsd,
                executedAt,
                required sellPlanEnabled,
                required takeProfitPct,
                required trailingStopPct,
                required stopLossPct,
              }) => provider.updateStockPurchase(
                purchase.copyWith(
                  portfolioId: portfolioId,
                  ticker: ticker,
                  sharesBought: sharesBought,
                  buyPriceUsd: buyPriceUsd,
                  cashPaidUsd: cashPaidUsd,
                  grossCostUsd: grossCostUsd,
                  brokerFeeUsd: brokerFeeUsd,
                  exchangeFeeUsd: exchangeFeeUsd,
                  taxFeeUsd: taxFeeUsd,
                ),
              ),
        ),
      ),
    );
  }

  Future<void> _confirmDeletePurchase(
    BuildContext context,
    StockPurchase purchase,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'ลบประวัติซื้อ',
      message: 'ต้องการลบประวัติซื้อ ${purchase.ticker} ใช่ไหม?',
      confirmLabel: 'ลบ',
    );
    if (confirmed == true && context.mounted) {
      await context.read<AccountProvider>().deleteStockPurchase(purchase.id);
    }
  }

  void _showFilterSheet(BuildContext context) {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final portfolios = context
        .read<AccountProvider>()
        .accounts
        .where((account) => account.type == AccountType.portfolio)
        .toList();
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    var selectedPortfolioId = _portfolioId;
    var selectedPnlFilter = _pnlFilter;

    showAppModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppModalBottomSheetHeader(title: 'ตัวกรองรายการขาย'),
                    const SizedBox(height: 16),
                    TradeFilterBar(
                      portfolios: portfolios,
                      selectedPortfolioId: selectedPortfolioId,
                      selectedPnlFilter: selectedPnlFilter,
                      isDarkMode: isDarkMode,
                      onPortfolioChanged: (value) {
                        setSheetState(() => selectedPortfolioId = value);
                      },
                      onPnlFilterChanged: (value) {
                        setSheetState(() => selectedPnlFilter = value);
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              selectedPortfolioId = null;
                              selectedPnlFilter = TradePnlFilter.all;
                            });
                          },
                          child: Text(
                            'ล้างค่า',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(
                            'ยกเลิก',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _portfolioId = selectedPortfolioId;
                              _pnlFilter = selectedPnlFilter;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('ใช้ตัวกรอง'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteTrade(
    BuildContext context,
    StockTrade trade,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'ลบ Trade',
      message: 'ต้องการลบประวัติขาย ${trade.ticker} ใช่ไหม?',
      confirmLabel: 'ลบ',
      isDestructive: true,
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<AccountProvider>().deleteStockTrade(trade.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('ลบ Trade ${trade.ticker} แล้ว')));
  }
}
