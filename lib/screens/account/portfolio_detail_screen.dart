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
    return Consumer<AccountProvider>(
      builder: (context, provider, _) {
        final acc = provider.findById(widget.account.id) ?? widget.account;
        final holdings = provider.getHoldings(acc.id);
        final transactions = context.read<TransactionProvider>().transactions;
        final totalValue = provider.getBalance(acc.id, transactions);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(acc.name),
            actions: [
              if (_isRefreshing)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
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
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showHoldingSheet(context, provider, acc.id, null),
            backgroundColor: AppColors.fabYellow,
            child: const Icon(Icons.add, color: Colors.white),
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
                ),

                // Cash balance row
                _SectionHeader(title: 'เงินสดใน Broker'),
                _CashRow(
                  cashBalance: acc.cashBalance,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountFormScreen(account: acc),
                    ),
                  ),
                ),

                // Holdings
                _SectionHeader(title: 'หุ้น US (${holdings.length} ตัว)'),
                if (holdings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'ยังไม่มีหุ้น กด + เพื่อเพิ่ม',
                        style: TextStyle(color: AppColors.textSecondary),
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
                              color: AppColors.surface,
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
                        onTap: () =>
                            _showHoldingSheet(context, provider, acc.id, h),
                        onDelete: () => provider.deleteHolding(h.id, acc.id),
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
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var autoUpdate = acc.autoUpdateRate;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('อัตราแลกเปลี่ยน'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: !autoUpdate,
                  decoration: const InputDecoration(
                    labelText: 'USD/THB',
                    suffixText: 'บาท',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Auto-update จาก API',
                        style: TextStyle(fontSize: 14),
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
                child: const Text('ยกเลิก'),
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
                child: const Text('บันทึก'),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
      ),
    );
  }

  void _showMenuSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('เพิ่มหุ้นใหม่'),
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
              leading: const Icon(Icons.reorder),
              title: const Text('จัดเรียงลำดับ'),
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

  const _SummaryCard({
    required this.account,
    required this.totalValue,
    required this.holdings,
    required this.onRateTap,
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

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
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
                    const Text(
                      'มูลค่ารวม',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${formatAmount(totalValue)} บาท',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amountColor(totalValue),
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
                    const Text(
                      'อัตราแลกเปลี่ยน',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '1 USD = ${rate.toStringAsFixed(2)} THB',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          account.autoUpdateRate
                              ? Icons.sync
                              : Icons.lock_outline,
                          size: 12,
                          color: account.autoUpdateRate
                              ? AppColors.income
                              : AppColors.textSecondary,
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
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ต้นทุนหุ้นรวม',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${formatAmount(totalCost)} บาท',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'กำไร/ขาดทุนหุ้น',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${pnl >= 0 ? '+' : ''}${formatAmount(pnl)} บาท  (${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: pnl >= 0 ? AppColors.income : AppColors.expense,
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
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CashRow extends StatelessWidget {
  final double cashBalance;
  final VoidCallback onTap;

  const _CashRow({required this.cashBalance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            const Expanded(
              child: Text(
                'เงินสด',
                style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
            Text(
              '${formatAmount(cashBalance)} บาท',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.amountColor(cashBalance),
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
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HoldingItem({
    super.key,
    required this.holding,
    required this.exchangeRate,
    this.isReorderMode = false,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final valueTHB = holding.valueUsd * exchangeRate;
    final hasCost = holding.costBasisUsd > 0;
    final pnlTHB = holding.unrealizedPnlUsd * exchangeRate;
    final pnlPct = holding.unrealizedPnlPct;

    return Column(
      children: [
        InkWell(
          onTap: isReorderMode ? null : onTap,
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Drag handle (only visible in reorder mode)
                if (isReorderMode) ...[
                  const Icon(
                    Icons.drag_indicator,
                    color: AppColors.divider,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                // Ticker badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.header.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    holding.ticker,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.header,
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
                        holding.name.isEmpty ? holding.ticker : holding.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_formatShares(holding.shares)} หุ้น',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (hasCost)
                        Text(
                          'ทุน ${holding.costBasisUsd.toStringAsFixed(2)} USD',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      Text(
                        'ราคา ${holding.priceUsd.toStringAsFixed(2)} USD',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hasCost)
                      Text(
                        '${pnlTHB >= 0 ? '+' : ''}${formatAmount(pnlTHB)} (${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: pnlTHB >= 0
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      )
                    else
                      Text(
                        '\$${formatAmount(holding.valueUsd)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                if (!isReorderMode)
                  GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_horiz,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }

  String _formatShares(double shares) {
    if (shares == shares.truncateToDouble()) {
      return shares.toInt().toString();
    }
    return shares.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '');
  }

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.expense,
              ),
              title: Text(
                'ลบ ${holding.ticker}',
                style: const TextStyle(color: AppColors.expense),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('แก้ไข ${holding.ticker}'),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบหุ้น'),
        content: Text('คุณต้องการลบ ${holding.ticker} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
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

  const _HoldingFormSheet({
    required this.portfolioId,
    required this.existing,
    required this.onSave,
    required this.generateId,
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
                  color: Colors.grey.shade300,
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
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _save,
                    child: const Text(
                      'บันทึก',
                      style: TextStyle(
                        color: AppColors.header,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _FormRow(
              label: 'Ticker',
              child: TextField(
                controller: _tickerController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'เช่น AAPL',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const Divider(height: 1, indent: 16),
            _FormRow(
              label: 'ชื่อบริษัท',
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'เช่น Apple Inc.',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const Divider(height: 1, indent: 16),
            _FormRow(
              label: 'จำนวนหุ้น',
              child: TextField(
                controller: _sharesController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  hintText: '0',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const Divider(height: 1, indent: 16),
            _FormRow(
              label: 'ราคาทุน (USD)',
              child: TextField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  hintText: '0.00',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const Divider(height: 1, indent: 16),
            _FormRow(
              label: 'ราคาปัจจุบัน (USD)',
              child: TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  hintText: '0.00',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(fontSize: 15),
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

  const _FormRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
