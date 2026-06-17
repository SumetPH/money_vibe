import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/account.dart';
import '../../models/stock_trade.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/stock_price_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/group_header.dart';
import 'stock_trade_form_screen.dart';

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
    _tabController = TabController(length: 2, vsync: this);
    _priceService = _buildPriceService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _priceService = _buildPriceService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showFilterSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openTradeForm(context, null),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'สรุป'),
            Tab(text: 'รายปี'),
          ],
        ),
      ),
      body: Consumer<AccountProvider>(
        builder: (context, accountProvider, _) {
          final trades = _filteredTrades(accountProvider.stockTrades);
          final summary = _TradeSummary.fromTrades(trades);
          final tradeMonthSections = _groupTradesByMonth(trades);

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
              ],
            ),
          );
        },
      ),
    );
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
                'Realized P/L',
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
                  label: 'เงินสดรับ',
                  value: '${formatAmount(summary.cashReceivedUsd)} USD',
                  color: textColor,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'กำไร',
                  value: formatAmount(summary.profitUsd),
                  color: profitColor,
                  alignEnd: true,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'ขาดทุน',
                  value: formatAmount(summary.lossUsd.abs()),
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

  const _EmptyTradeState({required this.isDarkMode, required this.textColor});

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
                Icons.show_chart,
                color: textColor.withValues(alpha: 0.9),
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่มีประวัติการขาย',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'เมื่อขายหุ้น รายการจะแสดงที่นี่พร้อมกำไร/ขาดทุน',
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
                  Text(
                    trade.ticker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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
                          Text(
                            trade.ticker,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
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
                  label: 'เงินสดรับ',
                  value: '${formatAmount(trade.cashReceivedUsd)} USD',
                  isDarkMode: isDarkMode,
                ),
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
