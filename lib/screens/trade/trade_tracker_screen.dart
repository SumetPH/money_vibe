import 'package:csv/csv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/account.dart';
import '../../models/stock_trade.dart';
import '../../models/tax_remittance.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/stock_price_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../utils/csv_file_io.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/group_header.dart';
import 'stock_trade_form_screen.dart';
import 'tax_remittance_form_screen.dart';

enum _TradePnlFilter { all, profit, loss }

class TradeTrackerScreen extends StatefulWidget {
  const TradeTrackerScreen({super.key});

  @override
  State<TradeTrackerScreen> createState() => _TradeTrackerScreenState();
}

class _TradeTrackerScreenState extends State<TradeTrackerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late StockPriceService _priceService;
  _TradePnlFilter _pnlFilter = _TradePnlFilter.all;
  String? _portfolioId;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _priceService = _buildPriceService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _priceService = _buildPriceService();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!mounted || _tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final isLargeScreen = MediaQuery.of(context).size.width >= 800;
    final bgColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      drawer: isLargeScreen
          ? null
          : const AppDrawer(currentRoute: '/trade-tracker'),
      appBar: AppBar(
        leading: isLargeScreen
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: const Text('บันทึกการเทรด'),
        actions: _buildAppBarActions(context),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'สรุป'),
            Tab(text: 'รายปี'),
            Tab(text: 'โอนกลับไทย'),
          ],
        ),
      ),
      body: Consumer<AccountProvider>(
        builder: (context, accountProvider, _) {
          final transactions = context
              .watch<TransactionProvider>()
              .transactions;
          final trades = _filteredTrades(accountProvider.stockTrades);
          final summary = _TradeSummary.fromTrades(trades);
          final tradeMonthSections = _groupTradesByMonth(trades);
          final principalQuotaRemainingUsd = accountProvider.accounts
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
            child: TabBarView(
              controller: _tabController,
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _SummaryPanel(
                        summary: summary,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (trades.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyTradeState(
                          isDarkMode: isDarkMode,
                          textColor: secondaryColor,
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((
                          context,
                          sectionIndex,
                        ) {
                          final section = tradeMonthSections[sectionIndex];
                          return _TradeMonthSection(
                            section: section,
                            isDarkMode: isDarkMode,
                            portfolioNameOf: (trade) =>
                                accountProvider
                                    .findById(trade.portfolioId)
                                    ?.name ??
                                'พอร์ตหุ้น',
                            onEdit: (trade) => _openTradeForm(context, trade),
                            onDelete: (trade) =>
                                _confirmDeleteTrade(context, trade),
                          );
                        }, childCount: tradeMonthSections.length),
                      ),
                    SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
                _YearlyTradeTab(
                  trades: accountProvider.stockTrades,
                  selectedYear: _selectedYear,
                  onYearChanged: (year) => setState(() => _selectedYear = year),
                  isDarkMode: isDarkMode,
                ),
                _TaxRemittanceTab(
                  trades: accountProvider.stockTrades,
                  remittances: accountProvider.taxRemittances,
                  selectedYear: _selectedYear,
                  principalQuotaRemainingUsd: principalQuotaRemainingUsd,
                  onYearChanged: (year) => setState(() => _selectedYear = year),
                  portfolioNameOf: (remittance) =>
                      accountProvider.findById(remittance.portfolioId)?.name ??
                      'พอร์ตหุ้น',
                  onAdd: () => _openRemittanceForm(context, null),
                  onEdit: (remittance) =>
                      _openRemittanceForm(context, remittance),
                  onDelete: (remittance) =>
                      _confirmDeleteRemittance(context, remittance),
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    switch (_tabController.index) {
      case 0:
        return [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'ตัวกรอง',
            onPressed: () => _showFilterSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'เพิ่ม Trade',
            onPressed: () => _openTradeForm(context, null),
          ),
        ];
      case 1:
        return [
          Builder(
            builder: (buttonContext) => IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export ข้อมูลภาษี',
              onPressed: () => _exportYearlyTaxData(
                context,
                sharePositionOrigin: _shareOriginOf(buttonContext),
              ),
            ),
          ),
        ];
      case 2:
        return [
          IconButton(
            icon: const Icon(Icons.account_balance),
            tooltip: 'บันทึกโอนกลับไทย',
            onPressed: () => _openRemittanceForm(context, null),
          ),
        ];
    }
    return const [];
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
    final yearRemittances =
        provider.taxRemittances
            .where((remittance) => remittance.remittedAt.year == year)
            .toList()
          ..sort((a, b) => a.remittedAt.compareTo(b.remittedAt));

    if (yearTrades.isEmpty && yearRemittances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่มีข้อมูลสำหรับ export ปี $year')),
      );
      return;
    }

    try {
      final files = _buildYearlyTaxExportFiles(
        year: year,
        trades: yearTrades,
        remittances: yearRemittances,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export ไม่สำเร็จ: $error')));
    }
  }

  List<StockTrade> _filteredTrades(List<StockTrade> trades) {
    return trades.where((trade) {
      if (_portfolioId != null && trade.portfolioId != _portfolioId) {
        return false;
      }
      switch (_pnlFilter) {
        case _TradePnlFilter.profit:
          return trade.realizedPnlUsd > 0;
        case _TradePnlFilter.loss:
          return trade.realizedPnlUsd < 0;
        case _TradePnlFilter.all:
          return true;
      }
    }).toList();
  }

  StockPriceService _buildPriceService() {
    final settings = context.read<SettingsProvider>();
    return StockPriceService(
      finnhubApiKey: settings.finnhubApiKey,
      useFinnhub: settings.useFinnhubForPrices,
      useYahooExtendedHoursPrice: settings.useYahooExtendedHoursPrice,
      exchangeRateSource: settings.exchangeRateSource,
    );
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

  Future<void> _openRemittanceForm(
    BuildContext context,
    TaxRemittance? remittance,
  ) async {
    final provider = context.read<AccountProvider>();
    final portfolios = provider.accounts
        .where((account) => account.type == AccountType.portfolio)
        .toList();

    if (portfolios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ต้องมีพอร์ตหุ้นก่อนบันทึกโอนกลับไทย')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaxRemittanceFormScreen(
          portfolios: portfolios,
          existing: remittance,
          generateId: provider.generateId,
          onSave: (savedRemittance) async {
            final transactions = context
                .read<TransactionProvider>()
                .transactions;
            if (remittance == null) {
              await provider.addTaxRemittance(
                savedRemittance,
                transactions: transactions,
              );
            } else {
              await provider.updateTaxRemittance(
                savedRemittance,
                transactions: transactions,
              );
            }
          },
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final portfolios = context
        .read<AccountProvider>()
        .accounts
        .where((account) => account.type == AccountType.portfolio)
        .toList();
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    var selectedPortfolioId = _portfolioId;
    var selectedPnlFilter = _pnlFilter;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
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
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: dividerColor,
                          borderRadius: BorderRadius.circular(AppRadii.tiny),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ตัวกรองรายการขาย',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _FilterBar(
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
                              selectedPnlFilter = _TradePnlFilter.all;
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
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.darkSurface : AppColors.surface,
        title: Text('ลบ Trade', style: TextStyle(color: textColor)),
        content: Text(
          'ต้องการลบประวัติขาย ${trade.ticker} ใช่ไหม?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ยกเลิก', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: expenseColor),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<AccountProvider>().deleteStockTrade(trade.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('ลบ Trade ${trade.ticker} แล้ว')));
  }

  Future<void> _confirmDeleteRemittance(
    BuildContext context,
    TaxRemittance remittance,
  ) async {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.darkSurface : AppColors.surface,
        title: Text('ลบรายการโอนกลับไทย', style: TextStyle(color: textColor)),
        content: Text(
          'ต้องการลบรายการโอนกลับ ${formatAmount(remittance.amountUsd)} USD ใช่ไหม?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ยกเลิก', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: expenseColor),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<AccountProvider>().deleteTaxRemittance(remittance.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ลบรายการโอนกลับไทยแล้ว')));
  }
}

class _YearlyTradeTab extends StatelessWidget {
  final List<StockTrade> trades;
  final int selectedYear;
  final ValueChanged<int> onYearChanged;
  final bool isDarkMode;

  const _YearlyTradeTab({
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
    final summary = _TradeSummary.fromTrades(yearTrades);
    final monthlySummaries = _monthlySummaries(yearTrades);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _YearSelector(
            selectedYear: selectedYear,
            onYearChanged: onYearChanged,
            isDarkMode: isDarkMode,
          ),
        ),
        SliverToBoxAdapter(
          child: _SummaryPanel(summary: summary, isDarkMode: isDarkMode),
        ),
        if (yearTrades.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyTradeState(
              isDarkMode: isDarkMode,
              textColor: secondaryColor,
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
          SliverToBoxAdapter(
            child: _MonthlyTradeTable(
              summaries: monthlySummaries,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  List<_MonthlyTradeSummary> _monthlySummaries(List<StockTrade> trades) {
    return List.generate(12, (index) {
      final month = index + 1;
      final monthTrades = trades
          .where((trade) => trade.soldAt.month == month)
          .toList();
      final summary = _TradeSummary.fromTrades(monthTrades);
      return _MonthlyTradeSummary(month: month, summary: summary);
    });
  }
}

class _TaxRemittanceTab extends StatelessWidget {
  final List<StockTrade> trades;
  final List<TaxRemittance> remittances;
  final int selectedYear;
  final double principalQuotaRemainingUsd;
  final ValueChanged<int> onYearChanged;
  final String Function(TaxRemittance remittance) portfolioNameOf;
  final VoidCallback onAdd;
  final ValueChanged<TaxRemittance> onEdit;
  final ValueChanged<TaxRemittance> onDelete;
  final bool isDarkMode;

  const _TaxRemittanceTab({
    required this.trades,
    required this.remittances,
    required this.selectedYear,
    required this.principalQuotaRemainingUsd,
    required this.onYearChanged,
    required this.portfolioNameOf,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
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
    final yearRemittances = remittances
        .where((remittance) => remittance.remittedAt.year == selectedYear)
        .toList();
    final tradeSummary = _TradeSummary.fromTrades(yearTrades);
    final remittanceSummary = _TaxRemittanceSummary.fromRemittances(
      yearRemittances,
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _YearSelector(
            selectedYear: selectedYear,
            onYearChanged: onYearChanged,
            isDarkMode: isDarkMode,
          ),
        ),
        SliverToBoxAdapter(
          child: _TaxRemittanceSummaryPanel(
            tradeSummary: tradeSummary,
            remittanceSummary: remittanceSummary,
            isDarkMode: isDarkMode,
          ),
        ),
        SliverToBoxAdapter(
          child: _TaxRemittanceAllocationSummarySection(
            remittanceSummary: remittanceSummary,
            principalQuotaRemainingUsd: principalQuotaRemainingUsd,
            isDarkMode: isDarkMode,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'รายการโอนกลับไทย',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (yearRemittances.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyTradeState(
              isDarkMode: isDarkMode,
              textColor: secondaryColor,
              icon: Icons.account_balance,
              message: 'ยังไม่มีรายการโอนกลับไทยในปีนี้',
              description:
                  'บันทึกเงินที่โอนกลับไทยและ allocation เพื่อใช้ประมาณภาษี',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((listCtx, index) {
              final remittance = yearRemittances[index];
              return _TaxRemittanceListItem(
                remittance: remittance,
                portfolioName: portfolioNameOf(remittance),
                isDarkMode: isDarkMode,
                onEdit: () => onEdit(remittance),
                onDelete: () => onDelete(remittance),
                onLongPress: () => _showRemittanceActionsSheet(
                  listCtx,
                  remittance,
                  portfolioNameOf(remittance),
                ),
              );
            }, childCount: yearRemittances.length),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  void _showRemittanceActionsSheet(
    BuildContext context,
    TaxRemittance remittance,
    String portfolioName,
  ) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final dangerColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: dividerColor,
                      borderRadius: BorderRadius.circular(AppRadii.tiny),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${formatAmount(remittance.amountUsd)} USD',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$portfolioName • ${_formatRemittanceDate(remittance.remittedAt)}',
                  style: TextStyle(color: secondaryColor, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: dividerColor),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined, color: textColor),
                  title: Text('แก้ไข', style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onEdit(remittance);
                  },
                ),
                Divider(height: 1, color: dividerColor),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: dangerColor),
                  title: Text('ลบรายการ', style: TextStyle(color: dangerColor)),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onDelete(remittance);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatRemittanceDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

Map<String, String> _buildYearlyTaxExportFiles({
  required int year,
  required List<StockTrade> trades,
  required List<TaxRemittance> remittances,
  required String Function(String portfolioId) portfolioNameOf,
}) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;

  return {
    'tax_summary_${year}_$timestamp.csv': _buildTaxSummaryCsv(
      year: year,
      trades: trades,
      remittances: remittances,
    ),
    'tax_stock_trades_${year}_$timestamp.csv': _buildTaxStockTradesCsv(
      trades: trades,
      portfolioNameOf: portfolioNameOf,
    ),
    'tax_remittances_${year}_$timestamp.csv': _buildTaxRemittancesCsv(
      remittances: remittances,
      portfolioNameOf: portfolioNameOf,
    ),
  };
}

String _buildTaxSummaryCsv({
  required int year,
  required List<StockTrade> trades,
  required List<TaxRemittance> remittances,
}) {
  final tradeSummary = _TradeSummary.fromTrades(trades);
  final remittanceSummary = _TaxRemittanceSummary.fromRemittances(remittances);
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
    ['จำนวนรายการโอนกลับไทย', remittanceSummary.remittanceCount, 'รายการ'],
    ['ยอดโอนกลับรวม', remittanceSummary.remittedUsd, 'USD'],
    ['ยอดโอนกลับรวม', remittanceSummary.remittedThb, 'THB'],
    [
      'เงินต้นที่ allocate แล้ว',
      remittanceSummary.principalAllocatedUsd,
      'USD',
    ],
    ['เงินได้ที่ allocate แล้ว', remittanceSummary.taxableUsd, 'USD'],
    ['เงินได้ที่ allocate แล้ว', remittanceSummary.taxableThb, 'THB'],
  ];

  return const ListToCsvConverter().convert(rows);
}

String _buildTaxStockTradesCsv({
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
      _formatCsvDate(trade.soldAt),
      trade.settledAt == null ? '' : _formatCsvDate(trade.settledAt!),
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
      _costMethodLabel(trade.costMethod),
      _pnlSourceLabel(trade.pnlSource),
      trade.brokerOrderRef ?? '',
    ]);
  }

  return const ListToCsvConverter().convert(rows);
}

String _buildTaxRemittancesCsv({
  required List<TaxRemittance> remittances,
  required String Function(String portfolioId) portfolioNameOf,
}) {
  final rows = <List<dynamic>>[
    [
      'วันที่โอนกลับ',
      'พอร์ต',
      'ยอดโอน USD',
      'อัตราแลกเปลี่ยน',
      'ยอดโอน THB',
      'เงินต้น USD',
      'เงินได้ USD',
      'เงินได้ THB',
      'Allocation',
      'หมายเหตุ',
    ],
  ];

  for (final remittance in remittances) {
    rows.add([
      _formatCsvDate(remittance.remittedAt),
      portfolioNameOf(remittance.portfolioId),
      remittance.amountUsd,
      remittance.fxRate,
      remittance.thbAmount,
      remittance.allocations
          .where(
            (allocation) =>
                allocation.bucketType == TaxRemittanceBucketType.principal,
          )
          .fold(0.0, (sum, allocation) => sum + allocation.amountUsd),
      remittance.taxableUsd,
      remittance.taxableThb,
      remittance.allocations.map(_formatAllocationForCsv).join(' | '),
      remittance.note,
    ]);
  }

  return const ListToCsvConverter().convert(rows);
}

String _formatAllocationForCsv(TaxRemittanceAllocation allocation) {
  final taxYear = allocation.taxYear == null ? '' : ' ${allocation.taxYear}';
  return '${taxRemittanceBucketLabel(allocation.bucketType)}$taxYear: ${allocation.amountUsd} USD';
}

String _formatCsvDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _costMethodLabel(CostMethod method) {
  switch (method) {
    case CostMethod.average:
      return 'Average';
    case CostMethod.fifo:
      return 'FIFO';
    case CostMethod.specific:
      return 'Specific';
  }
}

String _pnlSourceLabel(PnlSource source) {
  switch (source) {
    case PnlSource.estimated:
      return 'Estimated';
    case PnlSource.manual:
      return 'Manual';
    case PnlSource.broker:
      return 'Broker';
  }
}

class _TaxRemittanceSummary {
  final double remittedUsd;
  final double remittedThb;
  final double principalAllocatedUsd;
  final double taxableUsd;
  final double taxableThb;
  final int remittanceCount;

  const _TaxRemittanceSummary({
    required this.remittedUsd,
    required this.remittedThb,
    required this.principalAllocatedUsd,
    required this.taxableUsd,
    required this.taxableThb,
    required this.remittanceCount,
  });

  factory _TaxRemittanceSummary.fromRemittances(
    List<TaxRemittance> remittances,
  ) {
    return _TaxRemittanceSummary(
      remittedUsd: remittances.fold(0.0, (sum, item) => sum + item.amountUsd),
      remittedThb: remittances.fold(0.0, (sum, item) => sum + item.thbAmount),
      principalAllocatedUsd: remittances
          .expand((item) => item.allocations)
          .where(
            (allocation) =>
                allocation.bucketType == TaxRemittanceBucketType.principal,
          )
          .fold(0.0, (sum, allocation) => sum + allocation.amountUsd),
      taxableUsd: remittances.fold(0.0, (sum, item) => sum + item.taxableUsd),
      taxableThb: remittances.fold(0.0, (sum, item) => sum + item.taxableThb),
      remittanceCount: remittances.length,
    );
  }
}

class _TaxRemittanceSummaryPanel extends StatelessWidget {
  final _TradeSummary tradeSummary;
  final _TaxRemittanceSummary remittanceSummary;
  final bool isDarkMode;

  const _TaxRemittanceSummaryPanel({
    required this.tradeSummary,
    required this.remittanceSummary,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final taxableColor = AppColors.getAmountColor(
      remittanceSummary.taxableUsd,
      isDarkMode,
    );

    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'เงินได้/กำไรที่โอนกลับ',
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${remittanceSummary.remittanceCount} รายการ',
                style: TextStyle(color: secondaryColor, fontSize: 12),
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
                    '${formatAmount(remittanceSummary.taxableUsd)} USD',
                    style: TextStyle(
                      color: taxableColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatAmount(remittanceSummary.taxableThb)} THB',
                    style: TextStyle(color: secondaryColor, fontSize: 13),
                  ),
                ],
              ),
              _SummaryMetric(
                label: 'กำไรรวมก่อนหักขาดทุน',
                value: '${formatAmount(tradeSummary.profitUsd)} USD',
                color: AppColors.getAmountColor(
                  tradeSummary.profitUsd,
                  isDarkMode,
                ),
                alignEnd: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'ประมาณการจาก allocation ที่ไม่ใช่เงินต้น \nขาดทุนไม่ได้ถูกนำมาหักจากกำไร',
            style: TextStyle(color: secondaryColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TaxRemittanceAllocationSummarySection extends StatelessWidget {
  final _TaxRemittanceSummary remittanceSummary;
  final double principalQuotaRemainingUsd;
  final bool isDarkMode;

  const _TaxRemittanceAllocationSummarySection({
    required this.remittanceSummary,
    required this.principalQuotaRemainingUsd,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: dividerColor),
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
              const Spacer(),
              Text(
                '${remittanceSummary.remittanceCount} รายการ',
                style: TextStyle(color: secondaryColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'โอนกลับรวม',
                  value: '${formatAmount(remittanceSummary.remittedUsd)} USD',
                  color: textColor,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'เงินต้นใช้แล้ว',
                  value:
                      '${formatAmount(remittanceSummary.principalAllocatedUsd)} USD',
                  color: textColor,
                  alignEnd: true,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'โควต้าคงเหลือ',
                  value: '${formatAmount(principalQuotaRemainingUsd)} USD',
                  color: textColor,
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
    );
  }
}

class _TaxRemittanceListItem extends StatelessWidget {
  final TaxRemittance remittance;
  final String portfolioName;
  final bool isDarkMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;

  const _TaxRemittanceListItem({
    required this.remittance,
    required this.portfolioName,
    required this.isDarkMode,
    required this.onEdit,
    required this.onDelete,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Material(
      color: surfaceColor,
      child: InkWell(
        onTap: onEdit,
        onLongPress: onLongPress,
        child: Column(
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
                          '${formatAmount(remittance.amountUsd)} USD',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${formatAmount(remittance.taxableUsd)} เงินได้',
                        style: TextStyle(
                          color: AppColors.getAmountColor(
                            remittance.taxableUsd,
                            isDarkMode,
                          ),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$portfolioName • ${_formatRemittanceDate(remittance.remittedAt)} • ${formatAmount(remittance.thbAmount)} THB',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: secondaryColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            if (remittance.allocations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: remittance.allocations.map((allocation) {
                    final yearText =
                        allocation.bucketType ==
                                TaxRemittanceBucketType.principal ||
                            allocation.taxYear == null
                        ? ''
                        : ' ${allocation.taxYear}';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${taxRemittanceBucketLabel(allocation.bucketType)}$yearText',
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '${formatAmount(allocation.amountUsd)} USD',
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            Divider(height: 1, color: dividerColor),
          ],
        ),
      ),
    );
  }

  static String _formatRemittanceDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _YearSelector extends StatelessWidget {
  final int selectedYear;
  final ValueChanged<int> onYearChanged;
  final bool isDarkMode;

  const _YearSelector({
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
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: secondaryColor),
                onPressed: () => onYearChanged(selectedYear - 1),
              ),
              Expanded(
                child: Text(
                  '$selectedYear',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: secondaryColor),
                onPressed: () => onYearChanged(selectedYear + 1),
              ),
            ],
          ),
          Divider(height: 1, color: dividerColor),
        ],
      ),
    );
  }
}

class _MonthlyTradeSummary {
  final int month;
  final _TradeSummary summary;

  const _MonthlyTradeSummary({required this.month, required this.summary});
}

class _TradeMonthGroup {
  final int year;
  final int month;
  final List<StockTrade> trades;

  const _TradeMonthGroup({
    required this.year,
    required this.month,
    required this.trades,
  });
}

List<_TradeMonthGroup> _groupTradesByMonth(List<StockTrade> trades) {
  final sortedTrades = [...trades]
    ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
  final groups = <_TradeMonthGroup>[];

  for (final trade in sortedTrades) {
    final existingIndex = groups.indexWhere(
      (group) =>
          group.year == trade.soldAt.year && group.month == trade.soldAt.month,
    );

    if (existingIndex == -1) {
      groups.add(
        _TradeMonthGroup(
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

String _monthShortLabel(int month) {
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

String _monthFullLabel(int month) {
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

class _TradeMonthSection extends StatelessWidget {
  final _TradeMonthGroup section;
  final bool isDarkMode;
  final String Function(StockTrade trade) portfolioNameOf;
  final ValueChanged<StockTrade> onEdit;
  final ValueChanged<StockTrade> onDelete;

  const _TradeMonthSection({
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
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupHeader(
          title: '${_monthFullLabel(section.month)} ${section.year}',
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
        ...section.trades.asMap().entries.map((entry) {
          final index = entry.key;
          final trade = entry.value;

          return Column(
            children: [
              _TradeListItem(
                trade: trade,
                portfolioName: portfolioNameOf(trade),
                isDarkMode: isDarkMode,
                onEdit: () => onEdit(trade),
                onDelete: () => onDelete(trade),
              ),
              if (index != section.trades.length - 1)
                Divider(height: 1, color: dividerColor),
            ],
          );
        }),
      ],
    );
  }
}

class _MonthlyTradeTable extends StatelessWidget {
  final List<_MonthlyTradeSummary> summaries;
  final bool isDarkMode;

  const _MonthlyTradeTable({required this.summaries, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final profitColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final lossColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    return Container(
      color: surfaceColor,
      child: Column(
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
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'จำนวน',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'กำไร',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: profitColor,
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
                      color: lossColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'สุทธิ',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),
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
                          _monthShortLabel(monthSummary.month),
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
                  Divider(height: 1, color: dividerColor),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TradeSummary {
  final double cashReceivedUsd;
  final double realizedPnlUsd;
  final double profitUsd;
  final double lossUsd;
  final int tradeCount;
  final int winCount;
  final int lossCount;

  const _TradeSummary({
    required this.cashReceivedUsd,
    required this.realizedPnlUsd,
    required this.profitUsd,
    required this.lossUsd,
    required this.tradeCount,
    required this.winCount,
    required this.lossCount,
  });

  factory _TradeSummary.fromTrades(List<StockTrade> trades) {
    return _TradeSummary(
      cashReceivedUsd: trades.fold(
        0,
        (sum, trade) => sum + trade.cashReceivedUsd,
      ),
      realizedPnlUsd: trades.fold(
        0,
        (sum, trade) => sum + trade.realizedPnlUsd,
      ),
      profitUsd: trades
          .where((trade) => trade.realizedPnlUsd > 0)
          .fold(0, (sum, trade) => sum + trade.realizedPnlUsd),
      lossUsd: trades
          .where((trade) => trade.realizedPnlUsd < 0)
          .fold(0, (sum, trade) => sum + trade.realizedPnlUsd),
      tradeCount: trades.length,
      winCount: trades.where((trade) => trade.realizedPnlUsd > 0).length,
      lossCount: trades.where((trade) => trade.realizedPnlUsd < 0).length,
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final _TradeSummary summary;
  final bool isDarkMode;

  const _SummaryPanel({required this.summary, required this.isDarkMode});

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
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;

    return Container(
      color: surfaceColor,
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
                child: _SummaryMetric(
                  label: 'เงินสดรับจากการขาย',
                  value: '${formatAmount(summary.cashReceivedUsd)} USD',
                  color: textColor,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'กำไร',
                  value: '${formatAmount(summary.profitUsd)} USD',
                  color: profitColor,
                  alignEnd: true,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
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
            style: TextStyle(fontSize: 12, color: secondaryColor),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  const _SummaryMetric({
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
          style: TextStyle(fontSize: 11, color: secondaryColor),
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

class _EmptyTradeState extends StatelessWidget {
  final bool isDarkMode;
  final Color textColor;
  final IconData icon;
  final String message;
  final String description;

  const _EmptyTradeState({
    required this.isDarkMode,
    required this.textColor,
    this.icon = Icons.show_chart,
    this.message = 'ยังไม่มีประวัติการขาย',
    this.description = 'เมื่อขายหุ้น รายการจะแสดงที่นี่พร้อมกำไร/ขาดทุน',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.darkSurfaceVariant
                    : AppColors.sectionHeader,
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Icon(
                icon,
                color: textColor.withValues(alpha: 0.9),
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<Account> portfolios;
  final String? selectedPortfolioId;
  final _TradePnlFilter selectedPnlFilter;
  final bool isDarkMode;
  final ValueChanged<String?> onPortfolioChanged;
  final ValueChanged<_TradePnlFilter> onPnlFilterChanged;

  const _FilterBar({
    required this.portfolios,
    required this.selectedPortfolioId,
    required this.selectedPnlFilter,
    required this.isDarkMode,
    required this.onPortfolioChanged,
    required this.onPnlFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;
        Account? selectedPortfolio;
        for (final portfolio in portfolios) {
          if (portfolio.id == selectedPortfolioId) {
            selectedPortfolio = portfolio;
            break;
          }
        }
        final portfolioSelector = SizedBox(
          width: isWide ? 260 : double.infinity,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            onTap: () async {
              final selected = await _showPortfolioPickerSheet(
                context: context,
                portfolios: portfolios,
                selectedPortfolioId: selectedPortfolioId,
                isDarkMode: isDarkMode,
                includeAllOption: true,
              );
              if (selected == _PortfolioPickerCanceled.value) return;
              onPortfolioChanged(
                selected == _PortfolioPickerAll.value
                    ? null
                    : selected as String,
              );
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'พอร์ต',
                labelStyle: TextStyle(color: secondaryColor),
                prefixIcon: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: secondaryColor,
                  size: 20,
                ),
                suffixIcon: Icon(
                  Icons.keyboard_arrow_down,
                  color: secondaryColor,
                ),
                isDense: true,
                filled: true,
                fillColor: isDarkMode
                    ? AppColors.darkSurfaceVariant
                    : AppColors.sectionHeader,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              child: Text(
                selectedPortfolio?.name ?? 'ทุกพอร์ต',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ),
          ),
        );

        final filters = _PnlFilterChips(
          selected: selectedPnlFilter,
          isDarkMode: isDarkMode,
          onChanged: onPnlFilterChanged,
        );

        if (isWide) {
          return Row(
            children: [
              portfolioSelector,
              const SizedBox(width: 12),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: filters),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [portfolioSelector, const SizedBox(height: 12), filters],
        );
      },
    );
  }
}

enum _PortfolioPickerCanceled { value }

enum _PortfolioPickerAll { value }

Future<Object?> _showPortfolioPickerSheet({
  required BuildContext context,
  required List<Account> portfolios,
  required String? selectedPortfolioId,
  required bool isDarkMode,
  required bool includeAllOption,
}) {
  final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
  final textColor = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final secondaryColor = isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;
  final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

  return showModalBottomSheet<Object?>(
    context: context,
    backgroundColor: surfaceColor,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dividerColor,
                    borderRadius: BorderRadius.circular(AppRadii.tiny),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'เลือกพอร์ต',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (includeAllOption)
                _PortfolioPickerTile(
                  title: 'ทุกพอร์ต',
                  selected: selectedPortfolioId == null,
                  textColor: textColor,
                  secondaryColor: secondaryColor,
                  onTap: () =>
                      Navigator.pop(sheetContext, _PortfolioPickerAll.value),
                ),
              ...portfolios.map(
                (portfolio) => _PortfolioPickerTile(
                  title: portfolio.name,
                  selected: portfolio.id == selectedPortfolioId,
                  textColor: textColor,
                  secondaryColor: secondaryColor,
                  onTap: () => Navigator.pop(sheetContext, portfolio.id),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ).then((value) => value ?? _PortfolioPickerCanceled.value);
}

class _PortfolioPickerTile extends StatelessWidget {
  final String title;
  final bool selected;
  final Color textColor;
  final Color secondaryColor;
  final VoidCallback onTap;

  const _PortfolioPickerTile({
    required this.title,
    required this.selected,
    required this.textColor,
    required this.secondaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: textColor),
      ),
      trailing: selected ? Icon(Icons.check, color: secondaryColor) : null,
      onTap: onTap,
    );
  }
}

class _PnlFilterChips extends StatelessWidget {
  final _TradePnlFilter selected;
  final bool isDarkMode;
  final ValueChanged<_TradePnlFilter> onChanged;

  const _PnlFilterChips({
    required this.selected,
    required this.isDarkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChipButton(
          icon: Icons.list_alt_outlined,
          label: 'ทั้งหมด',
          selected: selected == _TradePnlFilter.all,
          isDarkMode: isDarkMode,
          onTap: () => onChanged(_TradePnlFilter.all),
        ),
        _FilterChipButton(
          icon: Icons.trending_up,
          label: 'กำไร',
          selected: selected == _TradePnlFilter.profit,
          isDarkMode: isDarkMode,
          color: isDarkMode ? AppColors.darkIncome : AppColors.income,
          onTap: () => onChanged(_TradePnlFilter.profit),
        ),
        _FilterChipButton(
          icon: Icons.trending_down,
          label: 'ขาดทุน',
          selected: selected == _TradePnlFilter.loss,
          isDarkMode: isDarkMode,
          color: isDarkMode ? AppColors.darkExpense : AppColors.expense,
          onTap: () => onChanged(_TradePnlFilter.loss),
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDarkMode;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDarkMode,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        color ?? (isDarkMode ? AppColors.darkTransfer : AppColors.transfer);
    final textColor = selected
        ? selectedColor
        : (isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary);
    final bgColor = selected
        ? selectedColor.withValues(alpha: 0.14)
        : (isDarkMode ? AppColors.darkSurfaceVariant : AppColors.sectionHeader);
    final borderColor = selected
        ? selectedColor.withValues(alpha: 0.42)
        : Colors.transparent;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeListItem extends StatelessWidget {
  final StockTrade trade;
  final String portfolioName;
  final bool isDarkMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TradeListItem({
    required this.trade,
    required this.portfolioName,
    required this.isDarkMode,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final pnlColor = AppColors.getAmountColor(trade.realizedPnlUsd, isDarkMode);
    final thumbnailColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.header;

    return InkWell(
      onTap: () => _showActionSheet(context),
      onLongPress: () => _showActionSheet(context),
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: thumbnailColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              padding: trade.logoUrl.isEmpty
                  ? EdgeInsets.zero
                  : const EdgeInsets.all(6),
              child: trade.logoUrl.isEmpty
                  ? _TickerFallback(ticker: trade.ticker, color: thumbnailColor)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      child: CachedNetworkImage(
                        imageUrl: trade.logoUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => _TickerFallback(
                          ticker: trade.ticker,
                          color: thumbnailColor,
                        ),
                        errorWidget: (_, _, _) => _TickerFallback(
                          ticker: trade.ticker,
                          color: thumbnailColor,
                        ),
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          trade.ticker,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (trade.pnlSource == PnlSource.broker) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppColors.darkTransfer.withValues(alpha: 0.2)
                                : AppColors.transfer.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadii.tiny),
                            border: Border.all(
                              color: isDarkMode
                                  ? AppColors.darkTransfer
                                  : AppColors.transfer,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'Broker',
                            style: TextStyle(
                              fontSize: 9,
                              color: isDarkMode
                                  ? AppColors.darkTransfer
                                  : AppColors.transfer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$portfolioName • ${_formatDate(trade.soldAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: secondaryColor, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatShares(trade.sharesSold)} shares • ${trade.sellPriceUsd.toStringAsFixed(4)} USD',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: secondaryColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${trade.realizedPnlUsd >= 0 ? '+' : ''}${formatAmount(trade.realizedPnlUsd)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: pnlColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatAmount(trade.cashReceivedUsd)} USD',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: secondaryColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final dangerColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;
    final pnlColor = AppColors.getAmountColor(trade.realizedPnlUsd, isDarkMode);
    final thumbnailColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.header;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: dividerColor,
                      borderRadius: BorderRadius.circular(AppRadii.tiny),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: thumbnailColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                      padding: trade.logoUrl.isEmpty
                          ? EdgeInsets.zero
                          : const EdgeInsets.all(6),
                      child: trade.logoUrl.isEmpty
                          ? _TickerFallback(
                              ticker: trade.ticker,
                              color: thumbnailColor,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadii.small,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: trade.logoUrl,
                                fit: BoxFit.contain,
                                placeholder: (_, _) => _TickerFallback(
                                  ticker: trade.ticker,
                                  color: thumbnailColor,
                                ),
                                errorWidget: (_, _, _) => _TickerFallback(
                                  ticker: trade.ticker,
                                  color: thumbnailColor,
                                ),
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  trade.ticker,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (trade.pnlSource == PnlSource.broker) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? AppColors.darkTransfer.withValues(
                                            alpha: 0.2,
                                          )
                                        : AppColors.transfer.withValues(
                                            alpha: 0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.tiny,
                                    ),
                                    border: Border.all(
                                      color: isDarkMode
                                          ? AppColors.darkTransfer
                                          : AppColors.transfer,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    'Broker P/L',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDarkMode
                                          ? AppColors.darkTransfer
                                          : AppColors.transfer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$portfolioName • ${_formatDate(trade.soldAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${trade.realizedPnlUsd >= 0 ? '+' : ''}${formatAmount(trade.realizedPnlUsd)}',
                      style: TextStyle(
                        color: pnlColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: dividerColor),
                const SizedBox(height: 12),
                _TradeDetailRow(
                  label: 'จำนวน',
                  value: _formatShares(trade.sharesSold),
                  isDarkMode: isDarkMode,
                ),
                _TradeDetailRow(
                  label: 'ราคาขาย',
                  value: '${trade.sellPriceUsd.toStringAsFixed(4)} USD',
                  isDarkMode: isDarkMode,
                ),
                _TradeDetailRow(
                  label: 'ราคาทุน',
                  value: '${trade.costBasisUsd.toStringAsFixed(4)} USD',
                  isDarkMode: isDarkMode,
                ),
                _TradeDetailRow(
                  label: 'เงินสดรับสุทธิ (Net)',
                  value: '${formatAmount(trade.cashReceivedUsd)} USD',
                  isDarkMode: isDarkMode,
                ),
                if (trade.grossProceedsUsd != null ||
                    (trade.brokerFeeUsd != null &&
                        trade.brokerFeeUsd! > 0)) ...[
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    color: dividerColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 10),
                  if (trade.grossProceedsUsd != null)
                    _TradeDetailRow(
                      label: 'มูลค่าขายรวม (Gross)',
                      value: '${formatAmount(trade.grossProceedsUsd!)} USD',
                      isDarkMode: isDarkMode,
                    ),
                  if (trade.brokerFeeUsd != null && trade.brokerFeeUsd! > 0)
                    _TradeDetailRow(
                      label: 'ค่าธรรมเนียม Broker',
                      value: '${formatAmount(trade.brokerFeeUsd!)} USD',
                      isDarkMode: isDarkMode,
                    ),
                  if (trade.exchangeFeeUsd != null && trade.exchangeFeeUsd! > 0)
                    _TradeDetailRow(
                      label: 'SEC / Exchange Fee',
                      value: '${formatAmount(trade.exchangeFeeUsd!)} USD',
                      isDarkMode: isDarkMode,
                    ),
                  if (trade.taxFeeUsd != null && trade.taxFeeUsd! > 0)
                    _TradeDetailRow(
                      label: 'Tax / VAT',
                      value: '${formatAmount(trade.taxFeeUsd!)} USD',
                      isDarkMode: isDarkMode,
                    ),
                ],
                const SizedBox(height: 10),
                Divider(height: 1, color: dividerColor),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          onEdit();
                        },
                        icon: Icon(Icons.edit_outlined, color: textColor),
                        label: Text(
                          'แก้ไข',
                          style: TextStyle(color: textColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          onDelete();
                        },
                        icon: Icon(Icons.delete_outline, color: dangerColor),
                        label: Text('ลบ', style: TextStyle(color: dangerColor)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatShares(double value) {
    return value.toStringAsFixed(7).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class _TradeDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const _TradeDetailRow({
    required this.label,
    required this.value,
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: secondaryColor, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TickerFallback extends StatelessWidget {
  final String ticker;
  final Color color;

  const _TickerFallback({required this.ticker, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        ticker.characters.take(2).toString(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
