import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/stock_holding.dart';
import '../theme/app_colors.dart';
import '../main.dart';

/// วิดเจ็ตแสดงข้อมูลหุ้นถือครองแต่ละตัวในพอร์ต (Deep Module)
/// ควบรวมตรรกะคำนวณกำไร/ขาดทุน Trailing Stop และเมนูย่อยเบ็ดเสร็จในตัวเอง
class PortfolioHoldingItemWidget extends StatelessWidget {
  final StockHolding holding;
  final double exchangeRate;
  final double totalHoldingsValueUsd;
  final bool isReorderMode;
  final VoidCallback onEdit;
  final VoidCallback onChangeLogo;
  final VoidCallback? onClearLogo;
  final VoidCallback onDelete;
  final bool isDarkMode;

  const PortfolioHoldingItemWidget({
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
    final sellPlanStatus = _buildSellPlanStatus();

    return Column(
      children: [
        GestureDetector(
          onTap: isReorderMode ? null : onEdit,
          onLongPress: isReorderMode ? null : () => _openListMenu(context),
          child: Container(
            color: surfaceColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Drag handle (only visible in reorder mode)
                if (isReorderMode) ...[
                  Icon(Icons.drag_indicator, color: dividerColor, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                HoldingThumbnailWidget(
                                  ticker: holding.ticker,
                                  logoUrl: holding.logoUrl,
                                  accentColor: headerColor,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      holding.ticker,
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
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatAmount(valueTHB),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${formatAmount(holding.valueUsd)} USD',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Value + P&L
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: pnlTHB >= 0
                                        ? incomeColor
                                        : expenseColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${pnlTHB >= 0 ? '+' : ''}${formatAmount(pnlTHB)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: pnlTHB >= 0
                                        ? incomeColor
                                        : expenseColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'จำนวนหุ้น',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textSecondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  holding.shares.toStringAsFixed(4),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textPrimaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'ราคา',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textSecondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  holding.priceUsd.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textPrimaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'ต้นทุนต่อหุ้น',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textSecondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  holding.costBasisUsd.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textPrimaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'ต้นทุนรวม',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textSecondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  holding.totalCostUsd.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textPrimaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (sellPlanStatus != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: sellPlanStatus.backgroundColor,
                            borderRadius: BorderRadius.circular(10),
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
              ],
            ),
          ),
        ),
      ],
    );
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

  _SellPlanStatusHelper? _buildSellPlanStatus() {
    if (!holding.sellPlanEnabled ||
        !holding.canCalculateSellPlan ||
        holding.takeProfitPct <= 0 ||
        holding.trailingStopPct <= 0) {
      return null;
    }

    final currentPnlPct = holding.unrealizedPnlPct;
    final textSecondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final peakProfitPct = holding.peakProfitPct;

    if (peakProfitPct == null) {
      return _SellPlanStatusHelper(
        title: 'ยังไม่ถึงเป้า',
        message:
            'เป้า ${_formatSignedPct(holding.takeProfitPct)} • ตอนนี้ ${_formatSignedPct(currentPnlPct)}',
        textColor: textSecondaryColor,
        backgroundColor: surfaceColor,
      );
    }

    final trailingStopTriggerPct = math.max(
      holding.takeProfitPct,
      peakProfitPct - holding.trailingStopPct,
    );
    final trailingStopPrice = _calculateStopPrice(
      costBasisUsd: holding.costBasisUsd,
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
    return _SellPlanStatusHelper(
      title: 'ถึงเป้าแล้ว รอ Trailing Stop',
      message:
          'Stop \$${trailingStopPrice.toStringAsFixed(2)} • ${_formatSignedPct(trailingStopTriggerPct)} • เหลืออีก ${remainingPct.toStringAsFixed(2)}%',
      textColor: incomeColor,
      backgroundColor: surfaceColor,
    );
  }

  String _formatSignedPct(double value) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%';
  }

  double _calculateStopPrice({
    required double costBasisUsd,
    required double stopProfitPct,
  }) {
    return costBasisUsd * (1 + (stopProfitPct / 100));
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

  const HoldingThumbnailWidget({
    super.key,
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
  }
}
