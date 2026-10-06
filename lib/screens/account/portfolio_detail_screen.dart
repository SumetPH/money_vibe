import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
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
import 'holding_form_screen.dart';
import 'holding_buy_form_screen.dart';
import 'portfolio_investment_plan_screen.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_segmented_tabs.dart';
import 'portfolio_hero_summary_card.dart';
import 'portfolio_edit_dialogs.dart';
import 'portfolio_group_section.dart';
import 'portfolio_holding_actions.dart';
import 'portfolio_menu_sheet.dart';
import '../../utils/user_error_message.dart';

class PortfolioDetailScreen extends StatefulWidget {
  final Account account;

  const PortfolioDetailScreen({super.key, required this.account});

  @override
  State<PortfolioDetailScreen> createState() => _PortfolioDetailScreenState();
}

class _PortfolioDetailScreenState extends State<PortfolioDetailScreen>
    with SingleTickerProviderStateMixin {
  // Finnhub free tier จำกัดต่อนาที จึงเว้นระยะให้รอบท้ายพ้นช่วง rate limit
  static const List<Duration> _logoBackfillDelays = [
    Duration(seconds: 2),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(seconds: 65),
  ];

  late StockPriceService _priceService;
  late StockLogoStorageService _logoStorageService;
  late final AnimationController _refreshIconController;
  int _selectedTab = 0;
  bool _isRefreshing = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPrices());
  }

  @override
  void dispose() {
    _refreshIconController.dispose();
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

  StockPriceService _buildPriceService() => StockPriceService(
    finnhubApiKey: context.read<SettingsProvider>().finnhubApiKey,
  );

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

      final priceSymbolsByHoldingId = <String, String>{
        if (_priceService.isConfigured)
          for (final h in holdings) h.id: ?acc.priceSymbolFor(h.ticker),
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
                priceSymbolsByHoldingId.containsKey(holding.id) &&
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
        final sellPlanHolding = syncSellPlanProgress(updatedHolding);
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
          final mirroredLogoUrl = await resolveStockLogoUrl(
            _logoStorageService,
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
      if (acc.isUsPortfolio && !_priceService.isConfigured) {
        warningMessages.add('ใส่ Finnhub API key เพื่ออัปเดตราคาอัตโนมัติ');
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userErrorMessage(e, action: 'โหลดราคา'))),
        );
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
              PortfolioHeroSummaryCard(
                account: acc,
                totalValue: totalValue,
                holdings: holdings,
                onRateTap: () =>
                    editPortfolioExchangeRate(context, provider, acc),
                onCashTap: () =>
                    editPortfolioCashBalance(context, provider, acc),
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AppSegmentedTabs(
                  segments: [
                    for (final (index, label) in const [
                      'พอร์ต',
                      'แผนการลงทุน',
                    ].indexed)
                      AppSegment(
                        label: label,
                        isSelected: _selectedTab == index,
                        onTap: () => setState(() => _selectedTab = index),
                      ),
                  ],
                ),
              ),
              Builder(
                builder: (context) => _selectedTab == 0
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
                              SnackBar(
                                content: Text(
                                  userErrorMessage(e, action: 'บันทึก DCA '),
                                ),
                              ),
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
    final symbol = widget.account.priceSymbolFor(ticker);
    if (symbol == null) return null;
    final prices = await _priceService.fetchPrices([symbol]);
    return prices[symbol];
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
                final purchase = StockPurchase(
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
                );
                await provider.buyHolding(
                  purchase: purchase,
                  updatedHolding: updatedHolding,
                );
                if (updatedHolding.logoUrl.isEmpty) {
                  unawaited(_backfillHoldingLogo(provider, purchase));
                }
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

    // สร้าง service ใหม่ทุกครั้งเพื่อใช้ Finnhub API key ล่าสุดจาก settings
    if (mounted) _priceService = _buildPriceService();
    if (!_priceService.isConfigured) {
      return holding.copyWith(logoUrl: fallbackLogoUrl);
    }

    final profile = await _priceService.fetchProfile(holding.ticker);
    final logoUrl = await resolveStockLogoUrl(
      _logoStorageService,
      ticker: holding.ticker,
      sourceUrl: profile?.logoUrl ?? '',
      currentLogoUrl: fallbackLogoUrl,
    );

    return holding.copyWith(logoUrl: logoUrl);
  }

  /// การดึงโลโก้ตอนซื้อหุ้นใหม่อาจล้มเหลวชั่วคราว (เช่น Finnhub rate limit
  /// แบบนับต่อนาทีหลังรีเฟรชราคา) จึงลองดึงซ้ำเบื้องหลังโดยเว้นระยะห่างขึ้นเรื่อย ๆ
  /// แล้วอัปเดตทั้ง holding และประวัติซื้อ
  Future<void> _backfillHoldingLogo(
    AccountProvider provider,
    StockPurchase purchase,
  ) async {
    StockHolding? findHolding() => provider
        .getHoldings(purchase.portfolioId)
        .where((h) => h.id == purchase.holdingId)
        .firstOrNull;

    for (final delay in _logoBackfillDelays) {
      await Future<void>.delayed(delay);
      if (!mounted) return;

      final holding = findHolding();
      if (holding == null || holding.logoUrl.isNotEmpty) return;

      try {
        final enriched = await _enrichHoldingWithProfile(holding);
        if (enriched.logoUrl.isEmpty) continue;
        await applyBackfilledHoldingLogo(provider, purchase, enriched.logoUrl);
        return;
      } catch (e) {
        debugPrint('Backfill logo failed for ${purchase.ticker}: $e');
      }
    }
  }

  void _showMenuSheet(BuildContext context) {
    showPortfolioMenuSheet(
      context,
      account: widget.account,
      onBuy: (sheetContext) => _openHoldingBuyForm(
        sheetContext,
        sheetContext.read<AccountProvider>(),
        widget.account.id,
        null,
      ),
      onAddHolding: (sheetContext) => _openHoldingForm(
        sheetContext,
        sheetContext.read<AccountProvider>(),
        widget.account.id,
        null,
      ),
      onReorderGroups: (holdings, isDarkMode) =>
          showPortfolioGroupReorderDialog(
            this.context,
            _currentPortfolioGroupKeys(holdings),
            isDarkMode,
            onSave: (groups) {
              setState(() {
                _groupOrder = groups;
              });
              _saveGroupOrder();
            },
          ),
    );
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
            PortfolioGroupSection(
              groupName: groupName,
              groupHoldings: groups[groupName]!,
              acc: acc,
              isDarkMode: isDarkMode,
              provider: provider,
              sortType: _groupSortTypes[groupName] ?? 'value',
              onSortTypeChanged: (val) => _setGroupSortType(groupName, val),
              onEdit: (context, h) =>
                  _openHoldingForm(context, provider, acc.id, h),
              onChangeLogo: (context, h) => pickAndUploadHoldingLogo(
                context,
                provider,
                _logoStorageService,
                h,
              ),
              onSell: (context, h) => openHoldingSellForm(
                context,
                provider,
                widget.account,
                acc.id,
                h,
              ),
              onBuy: (context, h) =>
                  _openHoldingBuyForm(context, provider, acc.id, h),
            ),
          ],
        ],
      ),
    );
  }
}
