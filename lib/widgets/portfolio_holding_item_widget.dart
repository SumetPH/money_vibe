import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/stock_holding.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../main.dart';

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
                    const SizedBox(width: 12),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
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
                            fontWeight: FontWeight.w600,
                            color: sellPlanStatus.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sellPlanStatus.message,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
    final bgColor = widget.isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = widget.isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final expenseColor = widget.isDarkMode
        ? AppColors.darkExpense
        : AppColors.expense;
    final handleColor = widget.isDarkMode
        ? AppColors.darkDivider
        : Colors.grey.shade300;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
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
                borderRadius: BorderRadius.circular(AppRadii.tiny),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: textColor),
              title: Text(
                'แก้ไข ${widget.holding.ticker}',
                style: TextStyle(color: textColor),
              ),
              tileColor: bgColor,
              onTap: () {
                Navigator.pop(context);
                widget.onEdit();
              },
            ),
            ListTile(
              leading: Icon(Icons.sell_outlined, color: textColor),
              title: Text(
                'ขาย ${widget.holding.ticker}',
                style: TextStyle(color: textColor),
              ),
              tileColor: bgColor,
              onTap: () {
                Navigator.pop(context);
                widget.onSell();
              },
            ),
            ListTile(
              leading: Icon(Icons.image_outlined, color: textColor),
              title: Text(
                widget.holding.logoUrl.isEmpty
                    ? 'เพิ่มโลโก้ ${widget.holding.ticker}'
                    : 'เปลี่ยนโลโก้ ${widget.holding.ticker}',
                style: TextStyle(color: textColor),
              ),
              tileColor: bgColor,
              onTap: () {
                Navigator.pop(context);
                widget.onChangeLogo();
              },
            ),
            if (widget.onClearLogo != null)
              ListTile(
                leading: Icon(Icons.hide_image_outlined, color: textColor),
                title: Text(
                  'ลบโลโก้ ${widget.holding.ticker}',
                  style: TextStyle(color: textColor),
                ),
                tileColor: bgColor,
                onTap: () {
                  Navigator.pop(context);
                  widget.onClearLogo!();
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: expenseColor),
              title: Text(
                'ลบ ${widget.holding.ticker}',
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
    final dialogBgColor = widget.isDarkMode
        ? AppColors.darkSurface
        : Colors.white;
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
      return _SellPlanStatusHelper(
        title: 'ขายได้แล้ว (Stop Loss)',
        message:
            'Stop Loss \$${stopLossPrice.toStringAsFixed(2)} • -${widget.holding.stopLossPct.toStringAsFixed(2)}% • ตอนนี้ ${_formatSignedPct(currentPnlPct)}',
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
          return _SellPlanStatusHelper(
            title: 'ขายได้แล้ว',
            message:
                'Stop \$${trailingStopPrice.toStringAsFixed(2)} • ${_formatSignedPct(trailingStopTriggerPct)} • ตอนนี้ ${_formatSignedPct(currentPnlPct)}',
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
              'Stop \$${trailingStopPrice.toStringAsFixed(2)} • ${_formatSignedPct(trailingStopTriggerPct)} • เหลืออีก ${remainingPct.toStringAsFixed(2)}%',
          textColor: incomeColor,
          backgroundColor: surfaceColor,
        );
      }
    }

    // 3. Still active but target/cut not hit yet
    final List<String> parts = [];
    if (widget.holding.takeProfitPct > 0) {
      parts.add('เป้า ${_formatSignedPct(widget.holding.takeProfitPct)}');
    }
    if (widget.holding.trailingStopPct > 0) {
      parts.add('Trail ${widget.holding.trailingStopPct.toStringAsFixed(2)}%');
    }
    if (widget.holding.stopLossPct > 0) {
      parts.add('Cut -${widget.holding.stopLossPct.toStringAsFixed(2)}%');
    }
    parts.add('ตอนนี้ ${_formatSignedPct(currentPnlPct)}');

    return _SellPlanStatusHelper(
      title: 'ยังไม่ถึงเป้า',
      message: parts.join(' • '),
      textColor: textSecondaryColor,
      backgroundColor: surfaceColor,
    );
  }

  String _formatSignedPct(double value) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%';
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
            color: widget.isDarkMode ? AppColors.darkSurface : Colors.white,
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
                color: widget.isDarkMode ? AppColors.darkSurface : Colors.white,
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
              color: widget.isDarkMode ? AppColors.darkSurface : Colors.white,
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
          color: widget.isDarkMode ? AppColors.darkSurface : Colors.white,
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
      crossAxisAlignment: CrossAxisAlignment.end,
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
      borderRadius: BorderRadius.circular(AppRadii.medium),
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

    final logoContainer = Container(
      width: 42,
      height: 42,
      decoration: decoration,
      padding: logoUrl.isEmpty ? EdgeInsets.zero : const EdgeInsets.all(6),
      alignment: Alignment.center,
      child: logoUrl.isEmpty
          ? fallback()
          : ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.small),
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => fallback(),
                errorWidget: (context, url, error) => fallback(),
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
              ),
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
