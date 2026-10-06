import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../models/stock_holding.dart';
import '../../providers/account_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/portfolio_holding_item_widget.dart';
import '../../main.dart';

typedef PortfolioHoldingAction =
    void Function(BuildContext context, StockHolding holding);

class PortfolioGroupSection extends StatelessWidget {
  final String groupName;
  final List<StockHolding> groupHoldings;
  final Account acc;
  final bool isDarkMode;
  final AccountProvider provider;
  final String sortType;
  final ValueChanged<String> onSortTypeChanged;
  final PortfolioHoldingAction onEdit;
  final PortfolioHoldingAction onChangeLogo;
  final PortfolioHoldingAction onSell;
  final PortfolioHoldingAction onBuy;

  const PortfolioGroupSection({
    super.key,
    required this.groupName,
    required this.groupHoldings,
    required this.acc,
    required this.isDarkMode,
    required this.provider,
    required this.sortType,
    required this.onSortTypeChanged,
    required this.onEdit,
    required this.onChangeLogo,
    required this.onSell,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
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
                  onSelected: (val) => onSortTypeChanged(val),
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
                      onEdit: () => onEdit(context, h),
                      onChangeLogo: () => onChangeLogo(context, h),
                      onClearLogo: h.logoUrl.isNotEmpty
                          ? () =>
                                provider.updateHolding(h.copyWith(logoUrl: ''))
                          : null,
                      onSell: () => onSell(context, h),
                      onBuy: () => onBuy(context, h),
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
}
