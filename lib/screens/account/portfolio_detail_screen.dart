import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
import '../../main.dart';
import 'account_form_screen.dart';
import 'holding_form_screen.dart';

class PortfolioDetailScreen extends StatefulWidget {
  final Account account;

  const PortfolioDetailScreen({super.key, required this.account});

  @override
  State<PortfolioDetailScreen> createState() => _PortfolioDetailScreenState();
}

class _PortfolioDetailScreenState extends State<PortfolioDetailScreen> {
  late StockPriceService _priceService;
  late StockLogoStorageService _logoStorageService;
  bool _isRefreshing = false;
  bool _isReorderMode = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _priceService = StockPriceService(apiKey: settings.finnhubApiKey);
    _logoStorageService = StockLogoStorageService();
    if (_priceService.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPrices());
    }
  }

  Future<void> _refreshPrices() async {
    if (_isRefreshing) return;
    final provider = context.read<AccountProvider>();
    final acc = provider.findById(widget.account.id);
    if (acc == null) return;
    final holdings = provider.getHoldings(acc.id);
    if (holdings.isEmpty) return;

    setState(() => _isRefreshing = true);
    try {
      final tickers = holdings.map((h) => h.ticker).toList();
      final tickersNeedingProfile = holdings
          .where((h) => h.logoUrl.isEmpty)
          .map((h) => h.ticker)
          .toSet()
          .toList();
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
      for (final h in holdings) {
        var updatedHolding = h;
        var hasChanges = false;
        final newPrice = prices[h.ticker];
        if (newPrice != null) {
          updatedHolding = updatedHolding.copyWith(priceUsd: newPrice);
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
          await provider.updateHolding(updatedHolding);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('โหลดราคาไม่ได้: $e')));
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
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

        return Scaffold(
          backgroundColor: isDarkMode
              ? AppColors.darkBackground
              : AppColors.background,
          appBar: AppBar(
            title: Text(acc.name),
            actions: [
              if (_isRefreshing)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'อัพเดทราคาหุ้น',
                  onPressed: _refreshPrices,
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountFormScreen(account: acc),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PortfolioAnalyzeScreen(accountId: acc.id),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showMenuSheet(context),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              children: [
                // Summary card
                _SummaryCard(
                  account: acc,
                  totalValue: totalValue,
                  holdings: holdings,
                  onRateTap: () => _editExchangeRate(context, provider, acc),
                  isDarkMode: isDarkMode,
                ),

                // Cash balance row
                _SectionHeader(
                  title: 'เงินสดใน Broker',
                  isDarkMode: isDarkMode,
                ),
                _CashRow(
                  cashBalance: acc.cashBalance,
                  exchangeRate: acc.exchangeRate,
                  onTap: () => _editCashBalance(context, provider, acc),
                  isDarkMode: isDarkMode,
                ),

                // Holdings
                _SectionHeader(
                  title: 'หุ้น US (${holdings.length} ตัว)',
                  isDarkMode: isDarkMode,
                ),
                if (holdings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'ยังไม่มีหุ้น กด + เพื่อเพิ่ม',
                        style: TextStyle(
                          color: isDarkMode
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: _isReorderMode,
                    itemCount: holdings.length,
                    onReorder: _isReorderMode
                        ? (oldIndex, newIndex) {
                            provider.reorderHoldings(
                              acc.id,
                              oldIndex,
                              newIndex,
                            );
                          }
                        : (_, _) {},
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final animValue = Curves.easeInOut.transform(
                            animation.value,
                          );
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
                      return _HoldingItem(
                        key: ValueKey(h.id),
                        holding: h,
                        exchangeRate: acc.exchangeRate,
                        totalHoldingsValueUsd: totalHoldingsValueUsd,
                        isReorderMode: _isReorderMode,
                        onEdit: () =>
                            _openHoldingForm(context, provider, acc.id, h),
                        onChangeLogo: () =>
                            _pickAndUploadHoldingLogo(context, provider, h),
                        onClearLogo: h.logoUrl.isNotEmpty
                            ? () => provider.updateHolding(
                                h.copyWith(logoUrl: ''),
                              )
                            : null,
                        onDelete: () => provider.deleteHolding(h.id, acc.id),
                        isDarkMode: isDarkMode,
                      );
                    },
                  ),

                const SizedBox(height: 80),
              ],
            ),
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
                    suffixText: 'บาท',
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
          generateId: provider.generateId,
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
    final stocksValue = holdings.fold(0.0, (sum, h) => sum + h.valueUsd * rate);
    final pnl = totalCost > 0 ? stocksValue - totalCost : 0.0;
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
                      child: Icon(account.icon, color: account.color, size: 24),
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
                            '${formatAmount(totalValue)} บาท',
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
              GestureDetector(
                onTap: onRateTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'อัตราแลกเปลี่ยน',
                      style: TextStyle(fontSize: 11, color: textSecondaryColor),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ต้นทุนหุ้นรวม',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondaryColor,
                        ),
                      ),
                      Text(
                        '${formatAmount(totalCost)} บาท',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                      Text(
                        '${formatAmount(totalCostUsd)} USD',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'กำไร/ขาดทุนหุ้น',
                      style: TextStyle(fontSize: 13, color: textSecondaryColor),
                    ),
                    Text(
                      '${pnl >= 0 ? '+' : ''}${formatAmount(pnl)} บาท  (${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: pnl >= 0 ? incomeColor : expenseColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDarkMode;
  const _SectionHeader({required this.title, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDarkMode ? AppColors.darkBackground : AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDarkMode
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary,
        ),
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
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.attach_money,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'เงินสด (USD)',
                style: TextStyle(fontSize: 16, color: textPrimaryColor),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatAmount(cashBalance)} USD',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getAmountColor(cashBalance, isDarkMode),
                  ),
                ),
                Text(
                  '${formatAmount(cashBalanceThb)} บาท',
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

class _HoldingItem extends StatelessWidget {
  final StockHolding holding;
  final double exchangeRate;
  final double totalHoldingsValueUsd;
  final bool isReorderMode;
  final VoidCallback onEdit;
  final VoidCallback onChangeLogo;
  final VoidCallback? onClearLogo;
  final VoidCallback onDelete;
  final bool isDarkMode;

  const _HoldingItem({
    super.key,
    required this.holding,
    required this.exchangeRate,
    required this.totalHoldingsValueUsd,
    this.isReorderMode = false,
    required this.onEdit,
    required this.onChangeLogo,
    required this.onClearLogo,
    required this.onDelete,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final valueTHB = holding.valueUsd * exchangeRate;
    final allocationPct = totalHoldingsValueUsd > 0
        ? (holding.valueUsd / totalHoldingsValueUsd) * 100
        : 0.0;
    final hasCost = holding.costBasisUsd > 0;
    final pnlTHB = holding.unrealizedPnlUsd * exchangeRate;
    final pnlPct = holding.unrealizedPnlPct;

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
    final headerColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.header;

    return Column(
      children: [
        GestureDetector(
          onTap: isReorderMode ? null : onEdit,
          onLongPress: isReorderMode ? null : () => _openListMenu(context),
          child: Container(
            color: surfaceColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Drag handle (only visible in reorder mode)
                if (isReorderMode) ...[
                  Icon(Icons.drag_indicator, color: dividerColor, size: 20),
                  const SizedBox(width: 8),
                ],
                _HoldingThumbnail(
                  ticker: holding.ticker,
                  logoUrl: holding.logoUrl,
                  accentColor: headerColor,
                ),
                const SizedBox(width: 12),
                // Name + detail row
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${holding.ticker} ${_formatShares(holding.shares)} หุ้น',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondaryColor,
                        ),
                      ),
                      if (hasCost)
                        Text(
                          'ทุน ${holding.costBasisUsd.toStringAsFixed(2)} USD',
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondaryColor,
                          ),
                        ),
                      Text(
                        'ราคา ${holding.priceUsd.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Value + P&L
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${formatAmount(valueTHB)} บาท',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                    ),
                    if (hasCost)
                      Text(
                        '${pnlTHB >= 0 ? '+' : ''}${formatAmount(pnlTHB)} (${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: pnlTHB >= 0 ? incomeColor : expenseColor,
                        ),
                      )
                    else
                      Text(
                        '\$${formatAmount(holding.valueUsd)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondaryColor,
                        ),
                      ),
                    Text(
                      '${allocationPct.toStringAsFixed(2)}%',
                      style: TextStyle(fontSize: 12, color: textSecondaryColor),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: dividerColor),
      ],
    );
  }

  String _formatShares(double shares) {
    if (shares == shares.truncateToDouble()) {
      return shares.toInt().toString();
    }
    return shares.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '');
  }

  void _openListMenu(BuildContext context) {
    final bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;
    final handleColor = isDarkMode
        ? AppColors.darkDivider
        : Colors.grey.shade300;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
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
              leading: Icon(Icons.edit_outlined, color: textColor),
              title: Text(
                'แก้ไข ${holding.ticker}',
                style: TextStyle(color: textColor),
              ),
              tileColor: bgColor,
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            ListTile(
              leading: Icon(Icons.image_outlined, color: textColor),
              title: Text(
                holding.logoUrl.isEmpty
                    ? 'เพิ่มโลโก้ ${holding.ticker}'
                    : 'เปลี่ยนโลโก้ ${holding.ticker}',
                style: TextStyle(color: textColor),
              ),
              tileColor: bgColor,
              onTap: () {
                Navigator.pop(context);
                onChangeLogo();
              },
            ),
            if (onClearLogo != null)
              ListTile(
                leading: Icon(Icons.hide_image_outlined, color: textColor),
                title: Text(
                  'ลบโลโก้ ${holding.ticker}',
                  style: TextStyle(color: textColor),
                ),
                tileColor: bgColor,
                onTap: () {
                  Navigator.pop(context);
                  onClearLogo!();
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: expenseColor),
              title: Text(
                'ลบ ${holding.ticker}',
                style: TextStyle(color: expenseColor),
              ),
              tileColor: bgColor,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final dialogBgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBgColor,
        title: Text('ยืนยันการลบหุ้น', style: TextStyle(color: textColor)),
        content: Text(
          'คุณต้องการลบ ${holding.ticker} ใช่หรือไม่?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ยกเลิก', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: expenseColor),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }
}

class _HoldingThumbnail extends StatelessWidget {
  final String ticker;
  final String logoUrl;
  final Color accentColor;

  const _HoldingThumbnail({
    required this.ticker,
    required this.logoUrl,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: accentColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    );

    Widget fallback() => Center(
      child: Text(
        ticker,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: accentColor,
        ),
        textAlign: TextAlign.center,
      ),
    );

    return Container(
      width: 42,
      height: 42,
      decoration: decoration,
      padding: logoUrl.isEmpty ? EdgeInsets.zero : const EdgeInsets.all(6),
      alignment: Alignment.center,
      child: logoUrl.isEmpty
          ? fallback()
          : ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                logoUrl,
                fit: BoxFit.contain,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return fallback();
                },
                errorBuilder: (_, _, _) => fallback(),
              ),
            ),
    );
  }
}
