import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/stock_holding.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../main.dart';
import 'app_modal_bottom_sheet.dart';

/// วิดเจ็ตแสดงข้อมูลหุ้นถือครองแต่ละตัวในพอร์ต (Deep Module)
/// ควบรวมตรรกะคำนวณกำไร/ขาดทุน Trailing Stop และเมนูย่อยเบ็ดเสร็จในตัวเอง
/// รองรับการ collapse/expand รายละเอียดด้วยการกดที่ปุ่มลูกศร
class PortfolioHoldingItemWidget extends StatefulWidget {
  final StockHolding holding;
  final double exchangeRate;
  final String currencyCode;
  final double totalHoldingsValueUsd;
  final bool isReorderMode;
  final VoidCallback onEdit;
  final VoidCallback onChangeLogo;
  final VoidCallback? onClearLogo;
  final VoidCallback onSell;
  final VoidCallback onBuy;
  final VoidCallback onDelete;
  final bool isDarkMode;

  const PortfolioHoldingItemWidget({
    super.key,
    required this.holding,
    required this.exchangeRate,
    required this.currencyCode,
    required this.totalHoldingsValueUsd,
    this.isReorderMode = false,
    required this.onEdit,
    required this.onChangeLogo,
    required this.onClearLogo,
    required this.onSell,
    required this.onBuy,
    required this.onDelete,
    required this.isDarkMode,
  });

  @override
  State<PortfolioHoldingItemWidget> createState() =>
      _PortfolioHoldingItemWidgetState();
}

class _PortfolioHoldingItemWidgetState extends State<PortfolioHoldingItemWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  void _toggleExpand() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final isUsd = widget.currencyCode == 'USD';
    final displayValue = isUsd
        ? widget.holding.valueUsd * widget.exchangeRate
        : widget.holding.valueUsd;
    final allocationPct = widget.totalHoldingsValueUsd > 0
        ? (widget.holding.valueUsd / widget.totalHoldingsValueUsd) * 100
        : 0.0;
    final displayPnl = isUsd
        ? widget.holding.unrealizedPnlUsd * widget.exchangeRate
        : widget.holding.unrealizedPnlUsd;
    final pnlPct = widget.holding.unrealizedPnlPct;

    final surfaceColor = widget.isDarkMode
        ? AppColors.darkSurface
        : AppColors.surface;
    final textPrimaryColor = widget.isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = widget.isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = widget.isDarkMode
        ? AppColors.darkDivider
        : AppColors.divider;
    final incomeColor = widget.isDarkMode
        ? AppColors.darkIncome
        : AppColors.income;
    final expenseColor = widget.isDarkMode
        ? AppColors.darkExpense
        : AppColors.expense;
    final headerColor = widget.isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.header;
    final sellPlanStatus = _buildSellPlanStatus();

    return Column(
      children: [
        // ── แถวหลัก (เห็นเสมอ) ──────────────────────────────────────────
        Material(
          color: surfaceColor,
          child: InkWell(
            onTap: widget.isReorderMode ? null : _toggleExpand,
            onLongPress: widget.isReorderMode
                ? null
                : () => _openListMenu(context),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Drag handle (only visible in reorder mode)
                  if (widget.isReorderMode) ...[
                    Icon(Icons.drag_indicator, color: dividerColor, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Row(
                      children: [
                        HoldingThumbnailWidget(
                          ticker: widget.holding.ticker,
                          logoUrl: widget.holding.logoUrl,
                          accentColor: headerColor,
                          badge: _buildSellPlanBadgeWidget(),
                        ),
                        const SizedBox(width: 12),
                        // Ticker + allocation
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.holding.ticker,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${allocationPct.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // มูลค่า
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatAmount(displayValue),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (isUsd)
                                Text(
                                  '${formatAmount(widget.holding.valueUsd)} ${widget.currencyCode}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondaryColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // P&L
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: displayPnl >= 0
                                      ? incomeColor
                                      : expenseColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${displayPnl >= 0 ? '+' : ''}${formatAmount(displayPnl)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: displayPnl >= 0
                                      ? incomeColor
                                      : expenseColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── ส่วนรายละเอียด (collapse/expand) ────────────────────────────
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Container(
            color: surfaceColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                Divider(height: 1, color: dividerColor),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DetailCell(
                        label: 'จำนวนหุ้น',
                        value: formatStockHoldingShares(widget.holding.shares),
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DetailCell(
                        label: 'ต้นทุนรวม',
                        value: widget.holding.totalCostUsd.toStringAsFixed(2),
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _DetailCell(
                        label: 'ต้นทุนต่อหุ้น',
                        value: formatStockHoldingCostBasis(
                          widget.holding.costBasisUsd,
                        ),
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DetailCell(
                        label: 'ราคาปัจจุบัน',
                        value: widget.holding.priceUsd.toStringAsFixed(2),
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                if (sellPlanStatus != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: sellPlanStatus.backgroundColor,
                      borderRadius: BorderRadius.circular(AppRadii.large),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sellPlanStatus.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sellPlanStatus.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sellPlanStatus.message,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: sellPlanStatus.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }

  void _openListMenu(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;
    final accentColor = isDarkMode
        ? AppColors.darkFabYellow
        : AppColors.fabYellow;

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppModalBottomSheetHeader(title: widget.holding.ticker),
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
                    ListTile(
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: incomeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: incomeColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'แก้ไข ${widget.holding.ticker}',
                        style: TextStyle(color: textColor, fontSize: 15),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onEdit();
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 58,
                      endIndent: 16,
                      color: dividerColor.withValues(alpha: 0.3),
                    ),
                    ListTile(
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                        child: Icon(
                          Icons.add_shopping_cart_rounded,
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'ซื้อ ${widget.holding.ticker}',
                        style: TextStyle(color: textColor, fontSize: 15),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onBuy();
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 58,
                      endIndent: 16,
                      color: dividerColor.withValues(alpha: 0.3),
                    ),
                    ListTile(
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: expenseColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                        child: Icon(
                          Icons.sell_rounded,
                          color: expenseColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'ขาย ${widget.holding.ticker}',
                        style: TextStyle(color: textColor, fontSize: 15),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onSell();
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 58,
                      endIndent: 16,
                      color: dividerColor.withValues(alpha: 0.3),
                    ),
                    ListTile(
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          color: textColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        widget.holding.logoUrl.isEmpty
                            ? 'เพิ่มโลโก้ ${widget.holding.ticker}'
                            : 'เปลี่ยนโลโก้ ${widget.holding.ticker}',
                        style: TextStyle(color: textColor, fontSize: 15),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onChangeLogo();
                      },
                    ),
                    if (widget.onClearLogo != null) ...[
                      Divider(
                        height: 1,
                        indent: 58,
                        endIndent: 16,
                        color: dividerColor.withValues(alpha: 0.3),
                      ),
                      ListTile(
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: textSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
                          ),
                          child: Icon(
                            Icons.hide_image_outlined,
                            color: textSecondary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'ลบโลโก้ ${widget.holding.ticker}',
                          style: TextStyle(color: textColor, fontSize: 15),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onClearLogo!();
                        },
                      ),
                    ],
                    Divider(
                      height: 1,
                      indent: 58,
                      endIndent: 16,
                      color: dividerColor.withValues(alpha: 0.3),
                    ),
                    ListTile(
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: expenseColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: expenseColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'ลบ ${widget.holding.ticker}',
                        style: TextStyle(color: expenseColor, fontSize: 15),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final dialogBgColor = widget.isDarkMode
        ? AppColors.darkSurface
        : AppColors.surface;
    final textColor = widget.isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final expenseColor = widget.isDarkMode
        ? AppColors.darkExpense
        : AppColors.expense;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBgColor,
        title: Text('ยืนยันการลบหุ้น', style: TextStyle(color: textColor)),
        content: Text(
          'คุณต้องการลบ ${widget.holding.ticker} ใช่หรือไม่?',
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
              widget.onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: expenseColor),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }

  _SellPlanStatusHelper? _buildSellPlanStatus() {
    if (!widget.holding.sellPlanEnabled ||
        !widget.holding.canCalculateSellPlan) {
      return null;
    }

    if (widget.holding.takeProfitPct <= 0 &&
        widget.holding.trailingStopPct <= 0 &&
        widget.holding.stopLossPct <= 0) {
      return null;
    }

    final currentPnlPct = widget.holding.unrealizedPnlPct;
    final textSecondaryColor = widget.isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final incomeColor = widget.isDarkMode
        ? AppColors.darkIncome
        : AppColors.income;
    final expenseColor = widget.isDarkMode
        ? AppColors.darkExpense
        : AppColors.expense;
    final surfaceColor = widget.isDarkMode
        ? AppColors.darkSurface
        : AppColors.surface;

    // 1. Check Stop Loss
    if (widget.holding.stopLossPct > 0 &&
        currentPnlPct <= -widget.holding.stopLossPct) {
      final stopLossPrice =
          widget.holding.costBasisUsd *
          (1 - (widget.holding.stopLossPct / 100));
      final stopLossTriggerPct = -widget.holding.stopLossPct;
      final distancePct = stopLossTriggerPct - currentPnlPct;
      return _SellPlanStatusHelper(
        title: 'แตะ Stop Loss แล้ว',
        message:
            'Stop: \$${stopLossPrice.toStringAsFixed(2)} (${_formatSignedPct(stopLossTriggerPct)})\nตอนนี้: ${_formatSignedPct(currentPnlPct)} ต่ำกว่า stop ${_formatAbsPct(distancePct)}',
        textColor: expenseColor,
        backgroundColor: surfaceColor,
      );
    }

    // 2. Check Trailing Stop after profit tracking has started.
    if (widget.holding.trailingStopPct > 0) {
      final trailingStopTriggerPct = _resolveTrailingStopTriggerPct();
      if (trailingStopTriggerPct != null) {
        final trailingStopPrice = _calculateStopPrice(
          costBasisUsd: widget.holding.costBasisUsd,
          stopProfitPct: trailingStopTriggerPct,
        );
        if (currentPnlPct <= trailingStopTriggerPct) {
          final distancePct = trailingStopTriggerPct - currentPnlPct;
          return _SellPlanStatusHelper(
            title: 'แตะ Trailing Stop แล้ว',
            message:
                'Stop: \$${trailingStopPrice.toStringAsFixed(2)} (${_formatSignedPct(trailingStopTriggerPct)})\nตอนนี้: ${_formatSignedPct(currentPnlPct)} ต่ำกว่า stop ${_formatAbsPct(distancePct)}',
            textColor: expenseColor,
            backgroundColor: surfaceColor,
          );
        }

        final remainingPct = currentPnlPct - trailingStopTriggerPct;
        final waitingTitle = widget.holding.takeProfitPct > 0
            ? 'ถึงเป้าแล้ว รอ Trailing Stop'
            : 'กำลังใช้ Trailing Stop';
        return _SellPlanStatusHelper(
          title: waitingTitle,
          message:
              'Stop: \$${trailingStopPrice.toStringAsFixed(2)} (${_formatSignedPct(trailingStopTriggerPct)})\nตอนนี้: ${_formatSignedPct(currentPnlPct)} สูงกว่า stop ${_formatAbsPct(remainingPct)}',
          textColor: incomeColor,
          backgroundColor: surfaceColor,
        );
      }
    }

    // 3. Still active but target/cut not hit yet
    final List<String> rules = [];
    if (widget.holding.takeProfitPct > 0) {
      rules.add('เป้า ${_formatSignedPct(widget.holding.takeProfitPct)}');
    }
    if (widget.holding.trailingStopPct > 0) {
      rules.add('Trail ${widget.holding.trailingStopPct.toStringAsFixed(2)}%');
    }
    if (widget.holding.stopLossPct > 0) {
      rules.add('Cut -${widget.holding.stopLossPct.toStringAsFixed(2)}%');
    }

    var title = 'แผนขายยังไม่ทำงาน';
    var currentLine = 'ตอนนี้: ${_formatSignedPct(currentPnlPct)}';
    if (widget.holding.takeProfitPct > 0) {
      final gapPct = widget.holding.takeProfitPct - currentPnlPct;
      if (gapPct > 0) {
        title = 'รอถึง Take Profit';
        currentLine =
            'ตอนนี้: ${_formatSignedPct(currentPnlPct)} ขาดอีก ${_formatAbsPct(gapPct)}';
      } else {
        title = 'ถึงเป้าแล้ว รอ Trailing Stop';
        currentLine =
            'ตอนนี้: ${_formatSignedPct(currentPnlPct)} รอเก็บจุดสูงสุด';
      }
    } else if (widget.holding.trailingStopPct > 0) {
      title = 'รอเริ่ม Trailing Stop';
      currentLine = currentPnlPct > 0
          ? 'ตอนนี้: ${_formatSignedPct(currentPnlPct)} รอเก็บจุดสูงสุด'
          : 'ตอนนี้: ${_formatSignedPct(currentPnlPct)} รอกำไรเป็นบวก';
    }

    return _SellPlanStatusHelper(
      title: title,
      message: '${rules.join(' • ')}\n$currentLine',
      textColor: textSecondaryColor,
      backgroundColor: surfaceColor,
    );
  }

  String _formatSignedPct(double value) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%';
  }

  String _formatAbsPct(double value) {
    return '${value.abs().toStringAsFixed(2)}%';
  }

  double? _resolveTrailingStopTriggerPct() {
    final peakProfitPct = widget.holding.peakProfitPct;
    if (peakProfitPct == null) return null;
    return peakProfitPct - widget.holding.trailingStopPct;
  }

  double _calculateStopPrice({
    required double costBasisUsd,
    required double stopProfitPct,
  }) {
    return costBasisUsd * (1 + (stopProfitPct / 100));
  }

  Widget? _buildSellPlanBadgeWidget() {
    if (!widget.holding.sellPlanEnabled ||
        !widget.holding.canCalculateSellPlan) {
      return null;
    }

    if (widget.holding.takeProfitPct <= 0 &&
        widget.holding.trailingStopPct <= 0 &&
        widget.holding.stopLossPct <= 0) {
      return null;
    }

    final currentPnlPct = widget.holding.unrealizedPnlPct;
    final incomeColor = widget.isDarkMode
        ? AppColors.darkIncome
        : AppColors.income;
    final expenseColor = widget.isDarkMode
        ? AppColors.darkExpense
        : AppColors.expense;

    // 1. Check Stop Loss
    if (widget.holding.stopLossPct > 0 &&
        currentPnlPct <= -widget.holding.stopLossPct) {
      // ขายได้แล้ว (Stop Loss!) - Show a prominent red warning badge with a white exclamation mark
      return Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          color: expenseColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.isDarkMode
                ? AppColors.darkSurface
                : AppColors.surface,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: expenseColor.withValues(alpha: 0.3),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
      );
    }

    // 2. Check Trailing Stop after profit tracking has started.
    if (widget.holding.trailingStopPct > 0) {
      final trailingStopTriggerPct = _resolveTrailingStopTriggerPct();
      if (trailingStopTriggerPct != null) {
        if (currentPnlPct <= trailingStopTriggerPct) {
          // ขายได้แล้ว (Sell signal!) - Show a prominent red warning badge with a white exclamation mark
          return Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: expenseColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isDarkMode
                    ? AppColors.darkSurface
                    : AppColors.surface,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: expenseColor.withValues(alpha: 0.3),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          );
        }

        // ถึงเป้าแล้ว รอ Trailing Stop - Show a green badge with trending_up icon
        return Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: incomeColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isDarkMode
                  ? AppColors.darkSurface
                  : AppColors.surface,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: incomeColor.withValues(alpha: 0.3),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 8,
            ),
          ),
        );
      }
    }

    // ยังไม่ถึงเป้า - Show a tiny blue dot representing sell plan is active
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: Colors.blue.shade400,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isDarkMode ? AppColors.darkSurface : AppColors.surface,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: expenseColor.withValues(alpha: 0.3),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// Helper widget สำหรับแสดง label + value ในส่วนรายละเอียดหุ้น
class _DetailCell extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimaryColor;
  final Color textSecondaryColor;

  const _DetailCell({
    required this.label,
    required this.value,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: textPrimaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SellPlanStatusHelper {
  final String title;
  final String message;
  final Color textColor;
  final Color backgroundColor;

  const _SellPlanStatusHelper({
    required this.title,
    required this.message,
    required this.textColor,
    required this.backgroundColor,
  });
}

/// วิดเจ็ตสำหรับแสดงรูปโลโก้หุ้นขนาดย่อ
class HoldingThumbnailWidget extends StatelessWidget {
  final String ticker;
  final String logoUrl;
  final Color accentColor;
  final Widget? badge;

  const HoldingThumbnailWidget({
    super.key,
    required this.ticker,
    required this.logoUrl,
    required this.accentColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: accentColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadii.large),
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

    final image = kIsWeb
        ? Image.network(
            logoUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallback(),
            errorBuilder: (context, error, stackTrace) => fallback(),
          )
        : CachedNetworkImage(
            imageUrl: logoUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => fallback(),
            errorWidget: (context, url, error) => fallback(),
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
          );

    final logoContainer = Container(
      width: 40,
      height: 40,
      decoration: decoration,
      alignment: Alignment.center,
      child: logoUrl.isEmpty
          ? fallback()
          : ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.large),
              child: image,
            ),
    );

    if (badge != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          logoContainer,
          Positioned(top: -4, right: -4, child: badge!),
        ],
      );
    }

    return logoContainer;
  }
}
