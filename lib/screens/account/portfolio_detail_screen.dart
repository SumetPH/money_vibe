import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_vibe/screens/account/portfolio_analyze_screen.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/stock_holding.dart';
import '../../models/stock_purchase.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/stock_logo_storage_service.dart';
import '../../services/stock_price_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/portfolio_holding_item_widget.dart';
import '../../main.dart';
import 'holding_form_screen.dart';
import 'holding_sell_form_screen.dart';
import 'holding_buy_form_screen.dart';
import 'portfolio_investment_plan_screen.dart';
import '../trade/broker_report_list_screen.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/app_bar_buttons.dart';

class PortfolioDetailScreen extends StatefulWidget {
  final Account account;

  const PortfolioDetailScreen({super.key, required this.account});

  @override
  State<PortfolioDetailScreen> createState() => _PortfolioDetailScreenState();
}

class _PortfolioDetailScreenState extends State<PortfolioDetailScreen>
    with TickerProviderStateMixin {
  late StockPriceService _priceService;
  late StockLogoStorageService _logoStorageService;
  late final AnimationController _refreshIconController;
  late final TabController _tabController;
  bool _isRefreshing = false;
  bool _isReorderMode = false;
  Map<String, String> _groupSortTypes =
      {}; // Key: groupName, Value: 'value' หรือ 'pnl'
  List<String> _groupOrder = [];

  @override
  void initState() {
    super.initState();
    _loadGroupOrder();
    _priceService = _buildPriceService();
    _logoStorageService = StockLogoStorageService();
    _refreshIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPrices());
  }

  @override
  void dispose() {
    _refreshIconController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(
        'portfolio_group_order_${widget.account.id}',
      );
      final Map<String, String> sorts = {};
      if (list != null) {
        for (final g in list) {
          final st = prefs.getString(
            'portfolio_group_sort_${widget.account.id}_$g',
          );
          if (st != null) sorts[g] = st;
        }
        setState(() {
          _groupOrder = list;
          _groupSortTypes = sorts;
        });
      }
    } catch (_) {}
  }

  Future<void> _setGroupSortType(String groupName, String sortType) async {
    setState(() {
      _groupSortTypes[groupName] = sortType;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'portfolio_group_sort_${widget.account.id}_$groupName',
        sortType,
      );
    } catch (_) {}
  }

  Future<void> _saveGroupOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'portfolio_group_order_${widget.account.id}',
        _groupOrder,
      );
    } catch (_) {}
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

  Future<void> _refreshPrices() async {
    if (_isRefreshing) return;
    final provider = context.read<AccountProvider>();

    _refreshIconController.repeat();
    setState(() => _isRefreshing = true);

    try {
      await provider.reloadPersistedData();
      if (!mounted) return;

      _priceService = _buildPriceService();
      final acc = provider.findById(widget.account.id);
      if (acc == null) return;
      final holdings = provider.getHoldings(acc.id);
      if (holdings.isEmpty) return;

      final priceSymbolsByHoldingId = {
        for (final h in holdings) h.id: acc.yahooSymbolFor(h.ticker),
      };
      final tickers = priceSymbolsByHoldingId.values.toSet().toList();
      final tickersNeedingProfile = _priceService.isConfigured
          ? holdings
                .where((h) => h.logoUrl.isEmpty)
                .where((h) => acc.isUsPortfolio)
                .map((h) => h.ticker)
                .toSet()
                .toList()
          : <String>[];
      final futures = await Future.wait([
        _priceService.fetchPrices(tickers),
        acc.autoUpdateRate
            ? _priceService
                  .fetchUsdThbRate()
                  .then<double?>((value) => value)
                  .catchError((_) => null)
            : Future<double?>.value(null),
        tickersNeedingProfile.isEmpty
            ? Future.value(<String, StockCompanyProfile>{})
            : _priceService.fetchProfiles(tickersNeedingProfile),
      ]);

      final prices = futures[0] as Map<String, double>;
      final rate = futures[1] as double?;
      final profiles = futures[2] as Map<String, StockCompanyProfile>;
      final failedTickers = holdings
          .where(
            (holding) =>
                !prices.containsKey(priceSymbolsByHoldingId[holding.id]),
          )
          .map((holding) => holding.ticker)
          .toSet()
          .toList();
      if (!mounted) return;

      final hasCompletePriceSnapshot = failedTickers.isEmpty;
      final updatedHoldings = <StockHolding>[];
      for (final h in holdings) {
        var updatedHolding = h;
        var hasChanges = false;
        final newPrice = prices[priceSymbolsByHoldingId[h.id]];
        if (hasCompletePriceSnapshot && newPrice != null) {
          updatedHolding = updatedHolding.copyWith(priceUsd: newPrice);
          hasChanges = true;
        }
        final sellPlanHolding = _syncSellPlanProgress(updatedHolding);
        if (sellPlanHolding.peakProfitPct != updatedHolding.peakProfitPct) {
          updatedHolding = sellPlanHolding;
          hasChanges = true;
        }
        final profile = profiles[h.ticker];
        final sourceLogoUrl =
            h.logoUrl.isNotEmpty &&
                !_logoStorageService.isStoredLogoUrl(h.logoUrl)
            ? h.logoUrl
            : (profile?.logoUrl ?? '');
        if (sourceLogoUrl.isNotEmpty) {
          final mirroredLogoUrl = await _resolveLogoUrl(
            ticker: h.ticker,
            sourceUrl: sourceLogoUrl,
            currentLogoUrl: h.logoUrl,
          );
          if (!mounted) return;
          if (mirroredLogoUrl.isNotEmpty && mirroredLogoUrl != h.logoUrl) {
            updatedHolding = updatedHolding.copyWith(logoUrl: mirroredLogoUrl);
            hasChanges = true;
          }
        }
        if (hasChanges) {
          updatedHoldings.add(updatedHolding);
        }
      }
      await provider.updatePortfolioMarketData(
        portfolioId: acc.id,
        holdings: updatedHoldings,
        exchangeRate: hasCompletePriceSnapshot ? rate : null,
      );
      final warningMessages = <String>[];
      if (failedTickers.isNotEmpty) {
        final displayedTickers = failedTickers.take(5).join(', ');
        final remainingCount = failedTickers.length - 5;
        final remainingLabel = remainingCount > 0
            ? ' และอีก $remainingCount รายการ'
            : '';
        warningMessages.add(
          'อัปเดตราคาไม่ครบ: $displayedTickers$remainingLabel '
          '(ยังไม่เปลี่ยนราคาเพื่อป้องกันยอดรวมคลาดเคลื่อน)',
        );
      }
      if (acc.autoUpdateRate && rate == null) {
        warningMessages.add('อัปเดตอัตราแลกเปลี่ยนไม่ได้ (กำลังใช้ค่าเดิม)');
      }
      if (warningMessages.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(warningMessages.join('\n'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('โหลดราคาไม่ได้: $e')));
      }
    } finally {
      if (mounted) {
        _refreshIconController
          ..stop()
          ..reset();
        setState(() => _isRefreshing = false);
      }
    }
  }

  StockHolding _syncSellPlanProgress(StockHolding holding) {
    if (!holding.sellPlanEnabled ||
        !holding.canCalculateSellPlan ||
        holding.trailingStopPct <= 0) {
      return holding;
    }

    final currentPnlPct = holding.unrealizedPnlPct;
    final peakProfitPct = holding.peakProfitPct;
    if (peakProfitPct == null) {
      if (_shouldTrackPeakProfit(
        currentPnlPct: currentPnlPct,
        takeProfitPct: holding.takeProfitPct,
      )) {
        return holding.copyWith(peakProfitPct: _roundPct(currentPnlPct));
      }
      return holding;
    }

    if (currentPnlPct > peakProfitPct) {
      return holding.copyWith(peakProfitPct: _roundPct(currentPnlPct));
    }

    return holding;
  }

  double _roundPct(double value) => double.parse(value.toStringAsFixed(2));

  bool _shouldTrackPeakProfit({
    required double currentPnlPct,
    required double takeProfitPct,
  }) {
    if (takeProfitPct <= 0) {
      return currentPnlPct > 0;
    }
    return currentPnlPct >= takeProfitPct;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    return Consumer<AccountProvider>(
      builder: (context, provider, _) {
        final acc = provider.findById(widget.account.id) ?? widget.account;
        final holdings = provider.getHoldings(acc.id);
        final transactions = context.read<TransactionProvider>().transactions;
        final totalValue = provider.getBalance(acc.id, transactions);
        final totalHoldingsValueUsd = holdings.fold<double>(
          0,
          (sum, holding) => sum + holding.valueUsd,
        );
        final tabContent = SingleChildScrollView(
          child: Column(
            children: [
              _HeroPortfolioSummaryCard(
                account: acc,
                totalValue: totalValue,
                holdings: holdings,
                onRateTap: () => _editExchangeRate(context, provider, acc),
                onCashTap: () => _editCashBalance(context, provider, acc),
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.darkSurface
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.xLarge),
                    border: Border.all(color: AppColors.borderFor(isDarkMode)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.darkSurfaceVariant
                          : AppColors.sectionHeader,
                      borderRadius: BorderRadius.circular(AppRadii.large),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDarkMode ? 0.2 : 0.05,
                          ),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    splashBorderRadius: BorderRadius.circular(AppRadii.large),
                    dividerColor: Colors.transparent,
                    labelColor: isDarkMode
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    unselectedLabelColor: isDarkMode
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: 'พอร์ต'),
                      // Tab(text: 'หุ้นทั้งหมด'),
                      Tab(text: 'แผนการลงทุน'),
                    ],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) => _tabController.index == 0
                    ? _buildPortfolioTab(
                        context,
                        provider,
                        acc,
                        holdings,
                        totalHoldingsValueUsd,
                        isDarkMode,
                      )
                    : PortfolioInvestmentPlanScreen(
                        account: acc,
                        holdings: holdings,
                        targets: provider.getPortfolioAllocationTargets(acc.id),
                        dcaCompleted: provider.isInvestmentPlanDcaCompleted(
                          acc.id,
                        ),
                        onDcaChanged: (completed) async {
                          try {
                            await provider.setInvestmentPlanDcaCompleted(
                              portfolioId: acc.id,
                              completed: completed,
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('บันทึก DCA ไม่ได้: $e')),
                            );
                          }
                        },
                        onTargetChanged:
                            ({
                              required holding,
                              required targetPercent,
                              required isEnabled,
                            }) => provider.updateAllocationTargetForHolding(
                              portfolioId: acc.id,
                              holding: holding,
                              targetPercent: targetPercent,
                              isEnabled: isEnabled,
                            ),
                        isDarkMode: isDarkMode,
                      ),
              ),
            ],
          ),
        );

        return Scaffold(
          backgroundColor: isDarkMode
              ? AppColors.darkBackground
              : AppColors.background,
          appBar: AppBar(
            backgroundColor: isDarkMode
                ? AppColors.darkBackground
                : AppColors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leadingWidth: 64,
            leading: const AppBackButton(),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  acc.name,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  acc.type.label,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    side: BorderSide(
                      color: AppColors.borderFor(isDarkMode),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: _isRefreshing
                        ? RotationTransition(
                            turns: _refreshIconController,
                            child: const Icon(Icons.refresh_rounded, size: 20),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: isDarkMode
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                    tooltip: 'อัปเดตราคาหุ้น',
                    onPressed: _isRefreshing ? null : _refreshPrices,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Material(
                  color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    side: BorderSide(
                      color: AppColors.borderFor(isDarkMode),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: isDarkMode
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                    tooltip: 'เมนูเพิ่มเติม',
                    onPressed: () => _showMenuSheet(context),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: kIsWeb ? SelectionArea(child: tabContent) : tabContent,
          ),
        );
      },
    );
  }

  Future<void> _editExchangeRate(
    BuildContext context,
    AccountProvider provider,
    Account acc,
  ) async {
    if (acc.currency != 'USD') return;

    final controller = TextEditingController(
      text: acc.exchangeRate.toStringAsFixed(2),
    );
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final dialogBgColor = isDarkMode
        ? AppColors.darkSurface
        : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var autoUpdate = acc.autoUpdateRate;
        return StatefulBuilder(
          // design-check: allow input or multi-choice dialog
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: dialogBgColor,
            title: Text('อัตราแลกเปลี่ยน', style: TextStyle(color: textColor)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: !autoUpdate,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'USD/THB',
                    suffixText: 'บาท',
                    labelStyle: TextStyle(
                      color: isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Auto-update จาก API',
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                    ),
                    AppSwitch(
                      value: autoUpdate,
                      onChanged: (v) => setDialogState(() => autoUpdate = v),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('ยกเลิก', style: TextStyle(color: textColor)),
              ),
              TextButton(
                onPressed: () {
                  final v = double.tryParse(controller.text.trim());
                  if (v != null && v > 0) {
                    provider.updateAccountExchangeRate(
                      acc.id,
                      exchangeRate: v,
                      autoUpdateRate: autoUpdate,
                    );
                  }
                  Navigator.pop(ctx);
                },
                child: Text('บันทึก', style: TextStyle(color: textColor)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editCashBalance(
    BuildContext context,
    AccountProvider provider,
    Account acc,
  ) async {
    final controller = TextEditingController(
      text: acc.cashBalance.toStringAsFixed(2),
    );
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final dialogBgColor = isDarkMode
        ? AppColors.darkSurface
        : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var autoUpdate = acc.autoUpdateRate;
        return StatefulBuilder(
          // design-check: allow input or multi-choice dialog
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: dialogBgColor,
            title: Text('ยอดเงินสด', style: TextStyle(color: textColor)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: !autoUpdate,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'ยอดเงินสด (${acc.currencyCodeLabel})',
                    suffixText: acc.currencyAmountSuffix,
                    labelStyle: TextStyle(
                      color: isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('ยกเลิก', style: TextStyle(color: textColor)),
              ),
              TextButton(
                onPressed: () {
                  final v = double.tryParse(controller.text.trim());
                  if (v != null) {
                    provider.updateAccountCashBalance(acc.id, v);
                  }
                  Navigator.pop(ctx);
                },
                child: Text('บันทึก', style: TextStyle(color: textColor)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openHoldingForm(
    BuildContext context,
    AccountProvider provider,
    String portfolioId,
    StockHolding? existing,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HoldingFormScreen(
          portfolioId: portfolioId,
          currencyCode: widget.account.currencyCodeLabel,
          existing: existing,
          onSave: (holding) async {
            final holdingWithProfile = await _enrichHoldingWithProfile(
              holding,
              existing: existing,
            );
            if (existing == null) {
              await provider.addHolding(holdingWithProfile);
            } else {
              await provider.updateHolding(holdingWithProfile);
            }
          },
          onDelete: existing == null
              ? null
              : () => provider.deleteHolding(existing.id, portfolioId),
          fetchCurrentPrice: _fetchCurrentHoldingPrice,
          generateId: provider.generateId,
        ),
      ),
    );
  }

  Future<double?> _fetchCurrentHoldingPrice(String ticker) async {
    _priceService = _buildPriceService();
    final symbol = widget.account.yahooSymbolFor(ticker);
    final prices = await _priceService.fetchPrices([symbol]);
    return prices[symbol];
  }

  Future<void> _openHoldingSellForm(
    BuildContext context,
    AccountProvider provider,
    String portfolioId,
    StockHolding holding,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HoldingSellFormScreen(
          holding: holding,
          currencyCode: widget.account.currencyCodeLabel,
          onSell:
              ({
                required sharesSold,
                required sellPriceUsd,
                required cashReceivedUsd,
                required remainingShares,
                required resetPeakProfit,
                remainingCostBasisUsd,
                grossProceedsUsd,
                brokerFeeUsd,
                exchangeFeeUsd,
                taxFeeUsd,
                executedAt,
              }) async {
                await provider.sellHolding(
                  portfolioId: portfolioId,
                  holdingId: holding.id,
                  sharesSold: sharesSold,
                  sellPriceUsd: sellPriceUsd,
                  cashReceivedUsd: cashReceivedUsd,
                  remainingShares: remainingShares,
                  resetPeakProfit: resetPeakProfit,
                  remainingCostBasisUsd: remainingCostBasisUsd,
                  grossProceedsUsd: grossProceedsUsd,
                  brokerFeeUsd: brokerFeeUsd,
                  exchangeFeeUsd: exchangeFeeUsd,
                  taxFeeUsd: taxFeeUsd,
                  soldAt: executedAt,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('บันทึกการขาย ${holding.ticker} แล้ว'),
                    ),
                  );
                }
              },
        ),
      ),
    );
  }

  Future<void> _openHoldingBuyForm(
    BuildContext context,
    AccountProvider provider,
    String portfolioId,
    StockHolding? holding,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HoldingBuyFormScreen(
          holding: holding,
          currencyCode: widget.account.currencyCodeLabel,
          portfolios: provider.accounts
              .where((account) => account.isPortfolio)
              .toList(),
          initialPortfolioId: portfolioId,
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
              }) async {
                final baseHolding =
                    holding ??
                    StockHolding(
                      id: provider.generateId(),
                      portfolioId: portfolioId,
                      ticker: ticker,
                    );
                final effectiveSellPlanEnabled =
                    holding?.sellPlanEnabled ?? sellPlanEnabled;
                final holdingAfterBuy = baseHolding.copyWith(
                  ticker: ticker,
                  shares: resultingShares,
                  costBasisUsd: resultingCostBasisUsd,
                  priceUsd: buyPriceUsd,
                  sellPlanEnabled: effectiveSellPlanEnabled,
                  takeProfitPct: holding?.takeProfitPct ?? takeProfitPct,
                  trailingStopPct: holding?.trailingStopPct ?? trailingStopPct,
                  stopLossPct: holding?.stopLossPct ?? stopLossPct,
                );
                final peakProfitPct = switch ((holding, resetPeakProfit)) {
                  (final existing?, false) => existing.peakProfitPct,
                  (final existing?, true) =>
                    holdingAfterBuy.unrealizedPnlPct >= existing.takeProfitPct
                        ? double.parse(
                            holdingAfterBuy.unrealizedPnlPct.toStringAsFixed(2),
                          )
                        : null,
                  _ => null,
                };
                final updatedHolding = await _enrichHoldingWithProfile(
                  holdingAfterBuy.copyWith(peakProfitPct: peakProfitPct),
                  existing: holding,
                );
                await provider.buyHolding(
                  purchase: StockPurchase(
                    id: provider.generateId(),
                    portfolioId: portfolioId,
                    holdingId: updatedHolding.id,
                    ticker: ticker,
                    name: updatedHolding.name,
                    logoUrl: updatedHolding.logoUrl,
                    sharesBought: sharesBought,
                    buyPriceUsd: buyPriceUsd,
                    cashPaidUsd: cashPaidUsd,
                    grossCostUsd: grossCostUsd,
                    brokerFeeUsd: brokerFeeUsd,
                    exchangeFeeUsd: exchangeFeeUsd,
                    taxFeeUsd: taxFeeUsd,
                    boughtAt: executedAt ?? DateTime.now(),
                    createdAt: DateTime.now(),
                  ),
                  updatedHolding: updatedHolding,
                );
              },
        ),
      ),
    );
  }

  Future<StockHolding> _enrichHoldingWithProfile(
    StockHolding holding, {
    StockHolding? existing,
  }) async {
    final hasSameTicker = existing != null && existing.ticker == holding.ticker;
    final fallbackLogoUrl = holding.logoUrl.isNotEmpty
        ? holding.logoUrl
        : (hasSameTicker ? existing.logoUrl : '');

    if (!_priceService.isConfigured) {
      return holding.copyWith(logoUrl: fallbackLogoUrl);
    }

    final profile = await _priceService.fetchProfile(holding.ticker);
    final logoUrl = await _resolveLogoUrl(
      ticker: holding.ticker,
      sourceUrl: profile?.logoUrl ?? '',
      currentLogoUrl: fallbackLogoUrl,
    );

    return holding.copyWith(logoUrl: logoUrl);
  }

  Future<String> _resolveLogoUrl({
    required String ticker,
    required String sourceUrl,
    required String currentLogoUrl,
  }) async {
    if (sourceUrl.isEmpty) return currentLogoUrl;
    if (_logoStorageService.isStoredLogoUrl(currentLogoUrl)) {
      return currentLogoUrl;
    }

    final mirroredLogoUrl = await _logoStorageService.mirrorLogo(
      ticker: ticker,
      sourceUrl: sourceUrl,
    );
    if (mirroredLogoUrl != null && mirroredLogoUrl.isNotEmpty) {
      return mirroredLogoUrl;
    }

    return currentLogoUrl.isNotEmpty ? currentLogoUrl : sourceUrl;
  }

  Future<void> _pickAndUploadHoldingLogo(
    BuildContext context,
    AccountProvider provider,
    StockHolding holding,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่สามารถอ่านไฟล์รูปได้')));
      return;
    }

    final extension = file.extension?.toLowerCase() ?? 'png';
    final uploadedUrl = await _logoStorageService.uploadLogoBytes(
      ticker: holding.ticker,
      bytes: file.bytes!,
      extension: extension,
      contentType: _contentTypeForExtension(extension),
    );

    if (!context.mounted) return;
    if (uploadedUrl == null || uploadedUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('อัปโหลดโลโก้ไม่สำเร็จ')));
      return;
    }

    await provider.updateHolding(holding.copyWith(logoUrl: uploadedUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('อัปเดตโลโก้แล้ว')));
  }

  String _contentTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/png';
    }
  }

  List<String> _currentPortfolioGroupKeys(List<StockHolding> holdings) {
    final groupSet = <String>{};
    for (final h in holdings) {
      final groupName = h.portfolioGroup.trim().isEmpty
          ? 'ทั่วไป'
          : h.portfolioGroup.trim();
      groupSet.add(groupName);
    }

    return [
      ..._groupOrder.where(groupSet.contains),
      ...groupSet.where((groupName) => !_groupOrder.contains(groupName)),
    ];
  }

  void _showMenuSheet(BuildContext context) {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppModalBottomSheetHeader(
                      title: 'ตัวเลือกพอร์ตการลงทุน',
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: isDarkMode
                          ? AppColors.darkSurfaceVariant
                          : AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.xLarge),
                        side: BorderSide(
                          color: dividerColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _buildMenuSheetTile(
                            icon: Icons.add_shopping_cart_rounded,
                            iconColor: incomeColor,
                            title: 'ซื้อหุ้นใหม่',
                            subtitle: 'บันทึกรายการซื้อหุ้นเข้าพอร์ต',
                            textColor: textColor,
                            secondaryColor: textSecondary,
                            bgColor: isDarkMode
                                ? AppColors.darkSurface
                                : AppColors.surface,
                            onTap: () {
                              Navigator.pop(context);
                              _openHoldingBuyForm(
                                context,
                                context.read<AccountProvider>(),
                                widget.account.id,
                                null,
                              );
                            },
                          ),
                          Divider(
                            height: 1,
                            indent: 64,
                            endIndent: 16,
                            color: dividerColor.withValues(alpha: 0.3),
                          ),
                          _buildMenuSheetTile(
                            icon: Icons.add_circle_outline_rounded,
                            iconColor: textColor,
                            title: 'เพิ่มหุ้นเป็นยอดตั้งต้น',
                            subtitle:
                                'เพิ่มข้อมูลหุ้นเดิมที่มีอยู่แล้วเข้าพอร์ต',
                            textColor: textColor,
                            secondaryColor: textSecondary,
                            bgColor: isDarkMode
                                ? AppColors.darkSurface
                                : AppColors.surface,
                            onTap: () {
                              Navigator.pop(context);
                              _openHoldingForm(
                                context,
                                context.read<AccountProvider>(),
                                widget.account.id,
                                null,
                              );
                            },
                          ),
                          if (widget.account.isUsPortfolio) ...[
                            Divider(
                              height: 1,
                              indent: 64,
                              endIndent: 16,
                              color: dividerColor.withValues(alpha: 0.3),
                            ),
                            _buildMenuSheetTile(
                              icon: Icons.edit_document,
                              iconColor: textColor,
                              title: 'ปรับรายงานประจำปี',
                              subtitle: 'นำเข้าและตรวจทานรายงาน Broker สหรัฐฯ',
                              textColor: textColor,
                              secondaryColor: textSecondary,
                              bgColor: isDarkMode
                                  ? AppColors.darkSurface
                                  : AppColors.surface,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BrokerReportListScreen(
                                      portfolioId: widget.account.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          Divider(
                            height: 1,
                            indent: 64,
                            endIndent: 16,
                            color: dividerColor.withValues(alpha: 0.3),
                          ),
                          _buildMenuSheetTile(
                            icon: Icons.auto_awesome_rounded,
                            iconColor: isDarkMode
                                ? AppColors.darkFabYellow
                                : AppColors.fabYellow,
                            title: 'วิเคราะห์พอร์ต',
                            subtitle: 'ตรวจสอบการกระจายความเสี่ยงและผลตอบแทน',
                            textColor: textColor,
                            secondaryColor: textSecondary,
                            bgColor: isDarkMode
                                ? AppColors.darkSurface
                                : AppColors.surface,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PortfolioAnalyzeScreen(
                                    accountId: widget.account.id,
                                  ),
                                ),
                              );
                            },
                          ),
                          Divider(
                            height: 1,
                            indent: 64,
                            endIndent: 16,
                            color: dividerColor.withValues(alpha: 0.3),
                          ),
                          _buildMenuSheetTile(
                            icon: Icons.account_tree_outlined,
                            iconColor: textColor,
                            title: 'จัดลำดับกลุ่ม',
                            subtitle: 'ลากและสลับลำดับการแสดงผลของกลุ่มพอร์ต',
                            textColor: textColor,
                            secondaryColor: textSecondary,
                            bgColor: isDarkMode
                                ? AppColors.darkSurface
                                : AppColors.surface,
                            onTap: () {
                              final holdings = context
                                  .read<AccountProvider>()
                                  .getHoldings(widget.account.id);
                              Navigator.pop(context);
                              _showGroupReorderDialog(
                                this.context,
                                _currentPortfolioGroupKeys(holdings),
                                isDarkMode,
                              );
                            },
                          ),
                          Divider(
                            height: 1,
                            indent: 64,
                            endIndent: 16,
                            color: dividerColor.withValues(alpha: 0.3),
                          ),
                          ListTile(
                            tileColor: isDarkMode
                                ? AppColors.darkSurface
                                : AppColors.surface,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: textColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.reorder_rounded,
                                color: textColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'โหมดจัดเรียงลำดับหุ้น',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              'แสดงปุ่มลากเพื่อสลับลำดับหุ้นในแต่ละกลุ่ม',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                            trailing: AppSwitch(
                              value: _isReorderMode,
                              onChanged: (value) {
                                setStateModal(() => _isReorderMode = value);
                                setState(() => _isReorderMode = value);
                              },
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildMenuSheetTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color secondaryColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: secondaryColor),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: secondaryColor.withValues(alpha: 0.5),
      ),
      onTap: onTap,
    );
  }

  Widget _buildPortfolioTab(
    BuildContext context,
    AccountProvider provider,
    Account acc,
    List<StockHolding> holdings,
    double totalHoldingsValueUsd,
    bool isDarkMode,
  ) {
    if (holdings.isEmpty) {
      return Center(
        child: Text(
          'ยังไม่มีหุ้น กด + เพื่อเพิ่ม',
          style: TextStyle(
            color: isDarkMode
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      );
    }

    final groups = <String, List<StockHolding>>{};
    for (final h in holdings) {
      final g = h.portfolioGroup.trim().isEmpty
          ? 'ทั่วไป'
          : h.portfolioGroup.trim();
      groups.putIfAbsent(g, () => []).add(h);
    }

    final currentGroups = groups.keys.toList();
    var orderChanged = false;
    for (final g in currentGroups) {
      if (!_groupOrder.contains(g)) {
        _groupOrder.add(g);
        orderChanged = true;
        SharedPreferences.getInstance().then((prefs) {
          final st = prefs.getString(
            'portfolio_group_sort_${widget.account.id}_$g',
          );
          if (st != null && mounted) {
            setState(() {
              _groupSortTypes[g] = st;
            });
          }
        });
      }
    }
    final sortedGroupKeys = _groupOrder
        .where((g) => groups.containsKey(g))
        .toList();
    if (orderChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _saveGroupOrder());
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        children: [
          for (final groupName in sortedGroupKeys) ...[
            _buildGroupSection(
              context,
              groupName,
              groups[groupName]!,
              acc,
              totalHoldingsValueUsd,
              isDarkMode,
              provider,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    String groupName,
    List<StockHolding> groupHoldings,
    Account acc,
    double totalHoldingsValueUsd,
    bool isDarkMode,
    AccountProvider provider,
  ) {
    final rate = acc.exchangeRate;
    final isUsd = acc.currency == 'USD';
    final currencyCode = acc.currencyCodeLabel;
    final groupValueUsd = groupHoldings.fold<double>(
      0,
      (sum, h) => sum + h.valueUsd,
    );
    final groupCostUsd = groupHoldings.fold<double>(
      0,
      (sum, h) => sum + h.totalCostUsd,
    );
    final groupValue = isUsd ? groupValueUsd * rate : groupValueUsd;
    final groupPnlUsd = groupCostUsd > 0 ? groupValueUsd - groupCostUsd : 0.0;
    final groupPnl = isUsd ? groupPnlUsd * rate : groupPnlUsd;
    final groupPnlPct = groupCostUsd > 0
        ? (groupPnlUsd / groupCostUsd * 100)
        : 0.0;

    final sortType = _groupSortTypes[groupName] ?? 'value';
    final sortedHoldings = List<StockHolding>.from(groupHoldings);
    if (sortType == 'value') {
      sortedHoldings.sort((a, b) => b.valueUsd.compareTo(a.valueUsd));
    } else {
      sortedHoldings.sort(
        (a, b) => b.unrealizedPnlPct.compareTo(a.unrealizedPnlPct),
      );
    }

    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Group Header ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: incomeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          Icons.folder_special_rounded,
                          size: 16,
                          color: incomeColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          groupName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: secondaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.full),
                        ),
                        child: Text(
                          '${sortedHoldings.length} ตัว',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: secondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'มูลค่าปัจจุบัน',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: secondaryColor,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            formatAmount(groupValue),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          if (isUsd)
                            Text(
                              '${formatAmount(groupValueUsd)} $currencyCode',
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryColor,
                              ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'กำไร/ขาดทุน',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: secondaryColor,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${groupPnlUsd >= 0 ? '+' : ''}${formatAmount(groupPnl)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: groupPnlUsd >= 0
                                      ? incomeColor
                                      : expenseColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (groupPnlUsd >= 0
                                              ? incomeColor
                                              : expenseColor)
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${groupPnlPct >= 0 ? '+' : ''}${groupPnlPct.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: groupPnlUsd >= 0
                                        ? incomeColor
                                        : expenseColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (groupName != 'ทั่วไป')
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: dividerColor.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  initialValue: sortType,
                  color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
                  padding: EdgeInsets.zero,
                  tooltip: 'เปลี่ยนรูปแบบการเรียง',
                  onSelected: (val) => _setGroupSortType(groupName, val),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sortType == 'value'
                            ? 'เรียงตามมูลค่า'
                            : 'เรียงตามกำไร/ขาดทุน',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: secondaryColor,
                      ),
                    ],
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'value',
                      child: Text(
                        'เรียงตามมูลค่า',
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor,
                          fontWeight: sortType == 'value'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pnl',
                      child: Text(
                        'เรียงตามกำไร/ขาดทุน',
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor,
                          fontWeight: sortType == 'pnl'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedHoldings.length,
              itemBuilder: (context, index) {
                final h = sortedHoldings[index];
                return Column(
                  key: ValueKey(h.id),
                  children: [
                    if (index > 0 || groupName == 'ทั่วไป')
                      Divider(
                        height: 1,
                        color: AppColors.listDividerFor(isDarkMode),
                      ),
                    PortfolioHoldingItemWidget(
                      holding: h,
                      exchangeRate: acc.exchangeRate,
                      currencyCode: acc.currencyCodeLabel,
                      totalHoldingsValueUsd: groupValueUsd,
                      isReorderMode: false,
                      onEdit: () =>
                          _openHoldingForm(context, provider, acc.id, h),
                      onChangeLogo: () =>
                          _pickAndUploadHoldingLogo(context, provider, h),
                      onClearLogo: h.logoUrl.isNotEmpty
                          ? () =>
                                provider.updateHolding(h.copyWith(logoUrl: ''))
                          : null,
                      onSell: () =>
                          _openHoldingSellForm(context, provider, acc.id, h),
                      onBuy: () =>
                          _openHoldingBuyForm(context, provider, acc.id, h),
                      onDelete: () => provider.deleteHolding(h.id, acc.id),
                      isDarkMode: isDarkMode,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupReorderDialog(
    BuildContext context,
    List<String> currentGroups,
    bool isDarkMode,
  ) {
    final dialogGroups = List<String>.from(currentGroups);
    final bgColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // design-check: allow input or multi-choice dialog
            return AlertDialog(
              backgroundColor: bgColor,
              title: Text(
                'จัดลำดับกลุ่มพอร์ต',
                style: TextStyle(color: textColor, fontSize: 18),
              ),
              contentPadding: const EdgeInsets.only(top: 16, bottom: 8),
              content: Column(
                children: [
                  Divider(height: 1, color: dividerColor),
                  SizedBox(
                    width: double.maxFinite,
                    height: 300,
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: dialogGroups.length,
                      onReorderItem: (oldIndex, newIndex) {
                        setStateDialog(() {
                          final item = dialogGroups.removeAt(oldIndex);
                          dialogGroups.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final g = dialogGroups[index];
                        return ListTile(
                          key: ValueKey(g),
                          title: Text(g, style: TextStyle(color: textColor)),
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: Icon(Icons.drag_handle, color: dividerColor),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('ยกเลิก', style: TextStyle(color: textColor)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _groupOrder = dialogGroups;
                    });
                    _saveGroupOrder();
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'บันทึก',
                    style: TextStyle(
                      color: isDarkMode
                          ? AppColors.darkIncome
                          : AppColors.income,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HeroPortfolioSummaryCard extends StatelessWidget {
  final Account account;
  final double totalValue;
  final List<StockHolding> holdings;
  final VoidCallback onRateTap;
  final VoidCallback onCashTap;
  final bool isDarkMode;

  const _HeroPortfolioSummaryCard({
    required this.account,
    required this.totalValue,
    required this.holdings,
    required this.onRateTap,
    required this.onCashTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final rate = account.exchangeRate;
    final isUsd = account.currency == 'USD';
    final currencyCode = account.currencyCodeLabel;
    final totalValueBase =
        account.cashBalance + holdings.fold(0.0, (sum, h) => sum + h.valueUsd);
    final totalCostBase = holdings.fold(0.0, (sum, h) => sum + h.totalCostUsd);
    final totalCost = isUsd ? totalCostBase * rate : totalCostBase;
    final stocksValueBase = holdings.fold(0.0, (sum, h) => sum + h.valueUsd);
    final stocksValue = isUsd ? stocksValueBase * rate : stocksValueBase;
    final displayTotalValue = isUsd ? totalValue * rate : totalValue;
    final pnl = totalCost > 0 ? stocksValue - totalCost : 0.0;
    final pnlPct = totalCost > 0 ? (pnl / totalCost * 100) : 0.0;

    final cashBalanceThb = isUsd
        ? account.cashBalance * rate
        : account.cashBalance;

    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimaryColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Top Section: Account Icon, Total Value, Exchange Rate ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: account.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: AccountIconWidget(
                      account: account,
                      size: 24,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'มูลค่าพอร์ตรวม',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatAmount(displayTotalValue),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getAmountColor(
                            totalValue,
                            isDarkMode,
                          ),
                        ),
                      ),
                      if (isUsd) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${formatAmount(totalValueBase)} $currencyCode',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isUsd)
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(AppRadii.xLarge),
                      border: Border.all(
                        color: AppColors.borderFor(isDarkMode),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onRateTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '1 USD = ${rate.toStringAsFixed(2)} ฿',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textPrimaryColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              account.autoUpdateRate
                                  ? Icons.sync_rounded
                                  : Icons.lock_outline_rounded,
                              size: 13,
                              color: account.autoUpdateRate
                                  ? incomeColor
                                  : textSecondaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Divider ──
          Divider(height: 1, color: dividerColor.withValues(alpha: 0.3)),

          // ── 2. Middle Stats: Cost, Stocks Value, Unrealized PnL ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ต้นทุนหุ้นรวม',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatAmount(totalCost),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimaryColor,
                        ),
                      ),
                      Text(
                        isUsd
                            ? '${formatAmount(totalCostBase)} $currencyCode'
                            : currencyCode,
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: dividerColor.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'มูลค่าหุ้นรวม',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatAmount(stocksValue),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimaryColor,
                        ),
                      ),
                      Text(
                        isUsd
                            ? '${formatAmount(stocksValueBase)} $currencyCode'
                            : currencyCode,
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: dividerColor.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'กำไร/ขาดทุน',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pnl >= 0 ? '+' : ''}${formatAmount(pnl)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: pnl >= 0 ? incomeColor : expenseColor,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (pnl >= 0 ? incomeColor : expenseColor)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: pnl >= 0 ? incomeColor : expenseColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ──
          Divider(height: 1, color: dividerColor.withValues(alpha: 0.3)),

          // ── 3. Bottom Row: Cash in Broker ──
          InkWell(
            onTap: onCashTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: incomeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: incomeColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'เงินสดใน Broker',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatAmount(cashBalanceThb),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getAmountColor(
                            cashBalanceThb,
                            isDarkMode,
                          ),
                        ),
                      ),
                      if (isUsd)
                        Text(
                          '${formatAmount(account.cashBalance)} $currencyCode',
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondaryColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    color: textSecondaryColor.withValues(alpha: 0.5),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
