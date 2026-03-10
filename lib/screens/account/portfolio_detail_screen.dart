import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../models/stock_holding.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/stock_price_service.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';
import 'account_form_screen.dart';

class PortfolioDetailScreen extends StatefulWidget {
  final Account account;

  const PortfolioDetailScreen({super.key, required this.account});

  @override
  State<PortfolioDetailScreen> createState() => _PortfolioDetailScreenState();
}

class _PortfolioDetailScreenState extends State<PortfolioDetailScreen> {
  late StockPriceService _priceService;
  bool _isRefreshing = false;
  bool _isReorderMode = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _priceService = StockPriceService(apiKey: settings.finnhubApiKey);
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
      final futures = await Future.wait([
        _priceService.fetchPrices(tickers),
        _priceService.fetchUsdThbRate(),
      ]);

      final prices = futures[0] as Map<String, double>;
      final rate = futures[1] as double;

      if (acc.autoUpdateRate) {
        provider.updateAccount(acc.copyWith(exchangeRate: rate));
      }
      for (final h in holdings) {
        final newPrice = prices[h.ticker];
        if (newPrice != null) {
          provider.updateHolding(h.copyWith(priceUsd: newPrice));
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
                icon: const Icon(Icons.more_horiz),
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountFormScreen(account: acc),
                    ),
                  ),
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
                        isReorderMode: _isReorderMode,
                        onEdit: () =>
                            _showHoldingSheet(context, provider, acc.id, h),
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

  void _showHoldingSheet(
    BuildContext context,
    AccountProvider provider,
    String portfolioId,
    StockHolding? existing,
  ) {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HoldingFormSheet(
        portfolioId: portfolioId,
        existing: existing,
        onSave: (holding) {
          if (existing == null) {
            provider.addHolding(holding);
          } else {
            provider.updateHolding(holding);
          }
        },
        generateId: provider.generateId,
        isDarkMode: isDarkMode,
      ),
    );
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
              leading: Icon(Icons.add_circle_outline, color: textColor),
              title: Text('เพิ่มหุ้นใหม่', style: TextStyle(color: textColor)),
              tileColor: bgColor,
              onTap: () {
                Navigator.pop(context);
                _showHoldingSheet(
                  context,
                  context.read<AccountProvider>(),
                  widget.account.id,
                  null,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.reorder, color: textColor),
              title: Text('จัดเรียงลำดับ', style: TextStyle(color: textColor)),
              tileColor: bgColor,
              trailing: Switch(
                value: _isReorderMode,
                onChanged: (value) {
                  setState(() => _isReorderMode = value);
                  Navigator.pop(context);
                },
              ),
              onTap: () {
                setState(() => _isReorderMode = !_isReorderMode);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
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
            crossAxisAlignment: CrossAxisAlignment.end,
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
  final VoidCallback onTap;
  final bool isDarkMode;

  const _CashRow({
    required this.cashBalance,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimaryColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

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
            Text(
              '${formatAmount(cashBalance)} USD',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.getAmountColor(cashBalance, isDarkMode),
              ),
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
  final bool isReorderMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDarkMode;

  const _HoldingItem({
    super.key,
    required this.holding,
    required this.exchangeRate,
    this.isReorderMode = false,
    required this.onEdit,
    required this.onDelete,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final valueTHB = holding.valueUsd * exchangeRate;
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
          onLongPress: () => _openListMenu(context),
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
                // Ticker badge
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: headerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    holding.ticker,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: headerColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                // Name + detail row
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatShares(holding.shares)} หุ้น',
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

class _HoldingFormSheet extends StatefulWidget {
  final String portfolioId;
  final StockHolding? existing;
  final void Function(StockHolding) onSave;
  final String Function() generateId;
  final bool isDarkMode;

  const _HoldingFormSheet({
    required this.portfolioId,
    required this.existing,
    required this.onSave,
    required this.generateId,
    required this.isDarkMode,
  });

  @override
  State<_HoldingFormSheet> createState() => _HoldingFormSheetState();
}

class _HoldingFormSheetState extends State<_HoldingFormSheet> {
  final _tickerController = TextEditingController();
  final _nameController = TextEditingController();
  final _sharesController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    if (h != null) {
      _tickerController.text = h.ticker;
      _nameController.text = h.name;
      _sharesController.text = _formatNum(h.shares);
      _priceController.text = _formatNum(h.priceUsd);
      if (h.costBasisUsd > 0) _costController.text = _formatNum(h.costBasisUsd);
    }
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _nameController.dispose();
    _sharesController.dispose();
    _priceController.dispose();
    _costController.dispose();
    super.dispose();
  }

  String _formatNum(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }

  void _save() {
    final ticker = _tickerController.text.trim().toUpperCase();
    if (ticker.isEmpty) return;
    final shares = double.tryParse(_sharesController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final cost = double.tryParse(_costController.text.trim()) ?? 0;

    final holding = StockHolding(
      id: widget.existing?.id ?? widget.generateId(),
      portfolioId: widget.portfolioId,
      ticker: ticker,
      name: _nameController.text.trim(),
      shares: shares,
      priceUsd: price,
      costBasisUsd: cost,
      sortOrder: widget.existing?.sortOrder ?? 0,
    );
    widget.onSave(holding);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final handleColor = isDarkMode
        ? AppColors.darkDivider
        : Colors.grey.shade300;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    widget.existing == null ? 'เพิ่มหุ้น' : 'แก้ไขหุ้น',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _save,
                    child: Text(
                      'บันทึก',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: dividerColor),
            _FormRow(
              label: 'Ticker',
              labelColor: textSecondaryColor,
              backgroundColor: isDarkMode
                  ? AppColors.darkSurface
                  : Colors.white,
              child: TextField(
                controller: _tickerController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.end,
                decoration: InputDecoration(
                  hintText: 'เช่น AAPL',
                  hintStyle: TextStyle(color: textSecondaryColor),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: TextStyle(fontSize: 15, color: textColor),
              ),
            ),
            Divider(height: 1, color: dividerColor),
            _FormRow(
              label: 'จำนวนหุ้น',
              labelColor: textSecondaryColor,
              backgroundColor: isDarkMode
                  ? AppColors.darkSurface
                  : Colors.white,
              child: TextField(
                controller: _sharesController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: textSecondaryColor),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: TextStyle(fontSize: 15, color: textColor),
              ),
            ),
            Divider(height: 1, color: dividerColor),
            _FormRow(
              label: 'ราคาทุน (USD)',
              labelColor: textSecondaryColor,
              backgroundColor: isDarkMode
                  ? AppColors.darkSurface
                  : Colors.white,
              child: TextField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: textSecondaryColor),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                ),
                style: TextStyle(fontSize: 15, color: textColor),
              ),
            ),
            const Divider(height: 1),
            _FormRow(
              label: 'ราคาปัจจุบัน (USD)',
              labelColor: textSecondaryColor,
              backgroundColor: isDarkMode
                  ? AppColors.darkSurface
                  : Colors.white,
              child: TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: textSecondaryColor),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: TextStyle(fontSize: 15, color: textColor),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final String label;
  final Widget child;
  final Color? labelColor;
  final Color? backgroundColor;

  const _FormRow({
    required this.label,
    required this.child,
    this.labelColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: labelColor ?? AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
