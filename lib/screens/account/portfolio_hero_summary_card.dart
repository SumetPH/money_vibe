import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/stock_holding.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/account_icon_widget.dart';
import '../../main.dart';

class PortfolioHeroSummaryCard extends StatelessWidget {
  final Account account;
  final double totalValue;
  final List<StockHolding> holdings;
  final VoidCallback onRateTap;
  final VoidCallback onCashTap;
  final bool isDarkMode;

  const PortfolioHeroSummaryCard({
    super.key,
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

          const AppCardDivider(),

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

          const AppCardDivider(),

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
