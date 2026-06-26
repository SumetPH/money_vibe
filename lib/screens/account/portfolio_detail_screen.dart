import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_vibe/screens/account/portfolio_analyze_screen.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/stock_holding.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/stock_logo_storage_service.dart';
import '../../services/stock_price_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bar_action_button.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/portfolio_holding_item_widget.dart';
import '../../main.dart';
import 'holding_form_screen.dart';
import 'holding_sell_form_screen.dart';
import '../trade/broker_report_list_screen.dart';

class PortfolioDetailScreen extends StatefulWidget {
  final Account account;

  const PortfolioDetailScreen({super.key, required this.account});

  @override
  State<PortfolioDetailScreen> createState() => _PortfolioDetailScreenState();
}

class _PortfolioDetailScreenState extends State<PortfolioDetailScreen>
    with SingleTickerProviderStateMixin {
  late StockPriceService _priceService;
  late StockLogoStorageService _logoStorageService;
  late final AnimationController _refreshIconController;
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
    _priceService = _buildPriceService();
    final provider = context.read<AccountProvider>();
    final acc = provider.findById(widget.account.id);
    if (acc == null) return;
    final holdings = provider.getHoldings(acc.id);
    if (holdings.isEmpty) return;

    _refreshIconController.repeat();
    setState(() => _isRefreshing = true);
    try {
      final tickers = holdings.map((h) => h.ticker).toList();
      final tickersNeedingProfile = _priceService.isConfigured
          ? holdings
                .where((h) => h.logoUrl.isEmpty)
                .map((h) => h.ticker)
                .toSet()
                .toList()
          : <String>[];
      final futures = await Future.wait([
        _priceService.fetchPrices(tickers),
        _priceService.fetchUsdThbRate(),
        tickersNeedingProfile.isEmpty
            ? Future.value(<String, StockCompanyProfile>{})
            : _priceService.fetchProfiles(tickersNeedingProfile),
      ]);

      final prices = futures[0] as Map<String, double>;
      final rate = futures[1] as double;
      final profiles = futures[2] as Map<String, StockCompanyProfile>;

      if (acc.autoUpdateRate) {
        provider.updateAccount(acc.copyWith(exchangeRate: rate));
      }
      final updatedHoldings = <StockHolding>[];
      for (final h in holdings) {
        var updatedHolding = h;
        var hasChanges = false;
        final newPrice = prices[h.ticker];
        if (newPrice != null) {
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
          if (mirroredLogoUrl.isNotEmpty && mirroredLogoUrl != h.logoUrl) {
            updatedHolding = updatedHolding.copyWith(logoUrl: mirroredLogoUrl);
            hasChanges = true;
          }
        }
        if (hasChanges) {
          updatedHoldings.add(updatedHolding);
        }
      }
      if (updatedHoldings.isNotEmpty) {
        await provider.updateHoldingsBatch(updatedHoldings);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('โหลดราคาไม่ได้: $e')));
      }
    } finally {
      _refreshIconController
        ..stop()
        ..reset();
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  StockHolding _syncSellPlanProgress(StockHolding holding) {
    if (!holding.sellPlanEnabled ||
        !holding.canCalculateSellPlan ||
        holding.takeProfitPct <= 0 ||
        holding.trailingStopPct <= 0) {
      return holding;
    }

    final currentPnlPct = holding.unrealizedPnlPct;
    final peakProfitPct = holding.peakProfitPct;
    if (peakProfitPct == null) {
      if (currentPnlPct >= holding.takeProfitPct) {
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
        final tabContent = DefaultTabController(
          length: 2,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Summary card
                      _SummaryCard(
                        account: acc,
                        totalValue: totalValue,
                        holdings: holdings,
                        onRateTap: () =>
                            _editExchangeRate(context, provider, acc),
                        isDarkMode: isDarkMode,
                      ),

                      // Cash balance row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          color: isDarkMode
                              ? AppColors.darkDivider
                              : AppColors.divider,
                        ),
                      ),
                      _CashRow(
                        cashBalance: acc.cashBalance,
                        exchangeRate: acc.exchangeRate,
                        onTap: () => _editCashBalance(context, provider, acc),
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 16)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorColor: isDarkMode
                          ? AppColors.darkIncome
                          : AppColors.income,
                      labelColor: isDarkMode
                          ? AppColors.darkIncome
                          : AppColors.income,
                      unselectedLabelColor: isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      tabs: const [
                        Tab(text: 'พอร์ต'),
                        Tab(text: 'หุ้นทั้งหมด'),
                      ],
                    ),
                    isDarkMode ? AppColors.darkSurface : AppColors.surface,
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                // Tab พอร์ต
                _buildPortfolioTab(
                  context,
                  provider,
                  acc,
                  holdings,
                  totalHoldingsValueUsd,
                  isDarkMode,
                ),
                // Tab หุ้นทั้งหมด
                _buildAllStocksTab(
                  context,
                  provider,
                  acc,
                  holdings,
                  totalHoldingsValueUsd,
                  isDarkMode,
                ),
              ],
            ),
          ),
        );

        return Scaffold(
          backgroundColor: isDarkMode
              ? AppColors.darkBackground
              : AppColors.background,
          appBar: AppBar(
            title: Text(acc.name),
            actions: [
              AppBarActionButton(
                tooltip: 'อัพเดทราคาหุ้น',
                onPressed: _refreshPrices,
                isLoading: _isRefreshing,
                loadingIcon: RotationTransition(
                  turns: _refreshIconController,
                  child: const Icon(Icons.refresh),
                ),
                icon: const Icon(Icons.refresh),
              ),

              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showMenuSheet(context),
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
    final controller = TextEditingController(
      text: acc.exchangeRate.toStringAsFixed(2),
    );
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final dialogBgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var autoUpdate = acc.autoUpdateRate;
        return StatefulBuilder(
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
                    Switch(
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
                    provider.updateAccount(
                      acc.copyWith(exchangeRate: v, autoUpdateRate: autoUpdate),
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
    final dialogBgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var autoUpdate = acc.autoUpdateRate;
        return StatefulBuilder(
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
                    labelText: 'ยอดเงินสด (USD)',
                    suffixText: 'USD',
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
                    provider.updateAccount(acc.copyWith(cashBalance: v));
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
    final prices = await _priceService.fetchPrices([ticker]);
    return prices[ticker];
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
          onSell:
              ({
                required sharesSold,
                required sellPriceUsd,
                required cashReceivedUsd,
                grossProceedsUsd,
                brokerFeeUsd,
                exchangeFeeUsd,
                taxFeeUsd,
              }) async {
                await provider.sellHolding(
                  portfolioId: portfolioId,
                  holdingId: holding.id,
                  sharesSold: sharesSold,
                  sellPriceUsd: sellPriceUsd,
                  cashReceivedUsd: cashReceivedUsd,
                  grossProceedsUsd: grossProceedsUsd,
                  brokerFeeUsd: brokerFeeUsd,
                  exchangeFeeUsd: exchangeFeeUsd,
                  taxFeeUsd: taxFeeUsd,
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
    final bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final handleColor = isDarkMode
        ? AppColors.darkDivider
        : Colors.grey.shade300;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: Icon(Icons.add_circle_outline, color: textColor),
                    title: Text(
                      'เพิ่มหุ้นใหม่',
                      style: TextStyle(color: textColor),
                    ),
                    tileColor: bgColor,
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
                  Divider(height: 1, color: dividerColor),
                  ListTile(
                    leading: Icon(Icons.auto_awesome, color: textColor),
                    title: Text(
                      'วิเคราะห์พอร์ต',
                      style: TextStyle(color: textColor),
                    ),
                    tileColor: bgColor,
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
                  Divider(height: 1, color: dividerColor),
                  ListTile(
                    leading: Icon(Icons.edit_document, color: textColor),
                    title: Text(
                      'ปรับรายงานประจำปี',
                      style: TextStyle(color: textColor),
                    ),
                    tileColor: bgColor,
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
                  Divider(height: 1, color: dividerColor),
                  ListTile(
                    leading: Icon(
                      Icons.account_tree_outlined,
                      color: textColor,
                    ),
                    title: Text(
                      'จัดลำดับกลุ่ม',
                      style: TextStyle(color: textColor),
                    ),
                    tileColor: bgColor,
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
                  Divider(height: 1, color: dividerColor),
                  ListTile(
                    leading: Icon(Icons.reorder, color: textColor),
                    title: Text(
                      'จัดเรียงลำดับ',
                      style: TextStyle(color: textColor),
                    ),
                    tileColor: bgColor,
                    trailing: Switch(
                      value: _isReorderMode,
                      onChanged: (value) {
                        setStateModal(() => _isReorderMode = value);
                        setState(() => _isReorderMode = value);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
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
          const SizedBox(height: 16),
        ],
      ],
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
    final groupValueUsd = groupHoldings.fold<double>(
      0,
      (sum, h) => sum + h.valueUsd,
    );
    final groupCostUsd = groupHoldings.fold<double>(
      0,
      (sum, h) => sum + h.totalCostUsd,
    );
    final groupValueThb = groupValueUsd * rate;
    final groupPnlUsd = groupCostUsd > 0 ? groupValueUsd - groupCostUsd : 0.0;
    final groupPnlThb = groupPnlUsd * rate;
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
    final headerBgColor = isDarkMode
        ? AppColors.darkSectionHeader
        : AppColors.sectionHeader;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Container(
      color: surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: headerBgColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_special, size: 18, color: incomeColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        groupName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    Text(
                      '${sortedHoldings.length} ตัว',
                      style: TextStyle(fontSize: 13, color: secondaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'มูลค่าปัจจุบัน',
                          style: TextStyle(fontSize: 13, color: secondaryColor),
                        ),
                        Text(
                          formatAmount(groupValueThb),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '${formatAmount(groupValueUsd)} USD',
                          style: TextStyle(fontSize: 13, color: secondaryColor),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'กำไร/ขาดทุน',
                          style: TextStyle(fontSize: 13, color: secondaryColor),
                        ),
                        Text(
                          '${groupPnlPct >= 0 ? '+' : ''}${groupPnlPct.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: groupPnlUsd >= 0
                                ? incomeColor
                                : expenseColor,
                          ),
                        ),
                        Text(
                          '${groupPnlUsd >= 0 ? '+' : ''}${formatAmount(groupPnlThb)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: groupPnlUsd >= 0
                                ? incomeColor
                                : expenseColor,
                          ),
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
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                initialValue: sortType,
                color: isDarkMode ? AppColors.darkSurface : Colors.white,
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
                  Divider(height: 1, color: dividerColor),
                  PortfolioHoldingItemWidget(
                    holding: h,
                    exchangeRate: acc.exchangeRate,
                    totalHoldingsValueUsd: groupValueUsd,
                    isReorderMode: false,
                    onEdit: () =>
                        _openHoldingForm(context, provider, acc.id, h),
                    onChangeLogo: () =>
                        _pickAndUploadHoldingLogo(context, provider, h),
                    onClearLogo: h.logoUrl.isNotEmpty
                        ? () => provider.updateHolding(h.copyWith(logoUrl: ''))
                        : null,
                    onSell: () =>
                        _openHoldingSellForm(context, provider, acc.id, h),
                    onDelete: () => provider.deleteHolding(h.id, acc.id),
                    isDarkMode: isDarkMode,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showGroupReorderDialog(
    BuildContext context,
    List<String> currentGroups,
    bool isDarkMode,
  ) {
    final dialogGroups = List<String>.from(currentGroups);
    final bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                      itemCount: dialogGroups.length,
                      onReorder: (oldIndex, newIndex) {
                        setStateDialog(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = dialogGroups.removeAt(oldIndex);
                          dialogGroups.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final g = dialogGroups[index];
                        return ListTile(
                          key: ValueKey(g),
                          title: Text(g, style: TextStyle(color: textColor)),
                          trailing: Icon(
                            Icons.drag_handle,
                            color: dividerColor,
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

  Widget _buildAllStocksTab(
    BuildContext context,
    AccountProvider provider,
    Account acc,
    List<StockHolding> holdings,
    double totalHoldingsValueUsd,
    bool isDarkMode,
  ) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

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

    return Container(
      color: surfaceColor,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: _isReorderMode,
            itemCount: holdings.length,
            onReorder: _isReorderMode
                ? (oldIndex, newIndex) {
                    provider.reorderHoldings(acc.id, oldIndex, newIndex);
                  }
                : (_, _) {},
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final animValue = Curves.easeInOut.transform(animation.value);
                  final elevation = 1 + animValue * 8;
                  final scale = 1 + animValue * 0.02;
                  return Transform.scale(
                    scale: scale,
                    child: Material(
                      elevation: elevation,
                      color: isDarkMode
                          ? AppColors.darkSurface
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      child: child,
                    ),
                  );
                },
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final h = holdings[index];
              return Column(
                key: ValueKey(h.id),
                children: [
                  PortfolioHoldingItemWidget(
                    holding: h,
                    exchangeRate: acc.exchangeRate,
                    totalHoldingsValueUsd: totalHoldingsValueUsd,
                    isReorderMode: _isReorderMode,
                    onEdit: () =>
                        _openHoldingForm(context, provider, acc.id, h),
                    onChangeLogo: () =>
                        _pickAndUploadHoldingLogo(context, provider, h),
                    onClearLogo: h.logoUrl.isNotEmpty
                        ? () => provider.updateHolding(h.copyWith(logoUrl: ''))
                        : null,
                    onSell: () =>
                        _openHoldingSellForm(context, provider, acc.id, h),
                    onDelete: () => provider.deleteHolding(h.id, acc.id),
                    isDarkMode: isDarkMode,
                  ),
                  Divider(height: 1, color: dividerColor),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _TabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

class _SummaryCard extends StatelessWidget {
  final Account account;
  final double totalValue;
  final List<StockHolding> holdings;
  final VoidCallback onRateTap;
  final bool isDarkMode;

  const _SummaryCard({
    required this.account,
    required this.totalValue,
    required this.holdings,
    required this.onRateTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final rate = account.exchangeRate;
    final totalValueUsd =
        account.cashBalance + holdings.fold(0.0, (sum, h) => sum + h.valueUsd);
    final totalCostUsd = holdings.fold(0.0, (sum, h) => sum + h.totalCostUsd);
    final totalCost = holdings.fold(
      0.0,
      (sum, h) => sum + h.totalCostUsd * rate,
    );
    final stocksValueUsd = holdings.fold(0.0, (sum, h) => sum + h.valueUsd);
    final stocksValueThb = stocksValueUsd * rate;
    final pnl = totalCost > 0 ? stocksValueThb - totalCost : 0.0;
    final pnlPct = totalCost > 0 ? (pnl / totalCost * 100) : 0.0;
    final hasCost = totalCost > 0;

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
      color: surfaceColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: account.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: AccountIconWidget(
                        account: account,
                        size: 24,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'มูลค่ารวม',
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondaryColor,
                            ),
                          ),
                          Text(
                            formatAmount(totalValue * rate),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.getAmountColor(
                                totalValue,
                                isDarkMode,
                              ),
                            ),
                          ),
                          Text(
                            '${formatAmount(totalValueUsd)} USD',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onRateTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'อัตราแลกเปลี่ยน',
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondaryColor,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '1 USD = ${rate.toStringAsFixed(2)} THB',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textPrimaryColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              account.autoUpdateRate
                                  ? Icons.sync
                                  : Icons.lock_outline,
                              size: 12,
                              color: account.autoUpdateRate
                                  ? incomeColor
                                  : textSecondaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (hasCost) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'ต้นทุนหุ้นรวม',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondaryColor,
                        ),
                      ),
                      Text(
                        formatAmount(totalCost),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                      Text(
                        '${formatAmount(totalCostUsd)} USD',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'มูลค่าหุ้นรวม',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondaryColor,
                        ),
                      ),
                      Text(
                        formatAmount(stocksValueThb),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                      Text(
                        '${formatAmount(stocksValueUsd)} USD',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
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
                          color: textSecondaryColor,
                        ),
                      ),
                      Text(
                        '${pnl >= 0 ? '+' : ''}${formatAmount(pnl)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: pnl >= 0 ? incomeColor : expenseColor,
                        ),
                      ),
                      Text(
                        '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: pnl >= 0 ? incomeColor : expenseColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CashRow extends StatelessWidget {
  final double cashBalance;
  final double exchangeRate;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _CashRow({
    required this.cashBalance,
    required this.exchangeRate,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final cashBalanceThb = cashBalance * exchangeRate;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimaryColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: incomeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.attach_money, color: incomeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'เงินสด',
                style: TextStyle(fontSize: 16, color: textPrimaryColor),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatAmount(cashBalanceThb),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getAmountColor(cashBalanceThb, isDarkMode),
                  ),
                ),
                Text(
                  '${formatAmount(cashBalance)} USD',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
