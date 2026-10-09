import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/stock_purchase.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/group_header.dart';
import 'trade_tracker_models.dart';
import 'trade_summary_panel.dart';
import 'trade_list_item.dart';
import 'trade_tracker_widgets.dart';

class TradePurchaseHistoryTab extends StatelessWidget {
  final List<StockPurchase> purchases;
  final bool isDarkMode;
  final String Function(StockPurchase purchase) portfolioNameOf;
  final ValueChanged<StockPurchase> onEdit;
  final ValueChanged<StockPurchase> onDelete;

  const TradePurchaseHistoryTab({
    super.key,
    required this.purchases,
    required this.isDarkMode,
    required this.portfolioNameOf,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final sections = groupTradePurchasesByMonth(purchases);
    final feeSummary = TradeFeeSummary.fromPurchases(purchases);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: 6)),
        SliverToBoxAdapter(
          child: TradeFeeSummaryPanel(
            summary: feeSummary,
            isDarkMode: isDarkMode,
          ),
        ),
        if (purchases.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: TradeEmptyState(
              isDarkMode: isDarkMode,
              textColor: textColor,
              icon: Icons.add_shopping_cart_outlined,
              message: 'ยังไม่มีประวัติซื้อ',
              description: 'เมื่อซื้อหุ้น รายการจะแสดงที่นี่',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => TradePurchaseMonthSection(
                section: sections[index],
                isDarkMode: isDarkMode,
                portfolioNameOf: portfolioNameOf,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
              childCount: sections.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class TradePurchaseMonthSection extends StatelessWidget {
  final TradePurchaseMonthGroup section;
  final bool isDarkMode;
  final String Function(StockPurchase purchase) portfolioNameOf;
  final ValueChanged<StockPurchase> onEdit;
  final ValueChanged<StockPurchase> onDelete;

  const TradePurchaseMonthSection({
    super.key,
    required this.section,
    required this.isDarkMode,
    required this.portfolioNameOf,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupHeader(
          title: '${tradeMonthFullLabel(section.month)} ${section.year}',
          isDarkMode: isDarkMode,
          trailing: [
            Text(
              '${section.purchases.length} รายการ',
              style: TextStyle(
                color: secondaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        AppInsetCard(
          margin: AppInsetCard.stackedMargin,
          children: [
            Column(
              children: section.purchases
                  .asMap()
                  .entries
                  .map(
                    (entry) => Column(
                      children: [
                        TradePurchaseListItem(
                          purchase: entry.value,
                          portfolioName: portfolioNameOf(entry.value),
                          isDarkMode: isDarkMode,
                          onEdit: () => onEdit(entry.value),
                          onDelete: () => onDelete(entry.value),
                        ),
                        if (entry.key != section.purchases.length - 1)
                          Divider(
                            height: 1,
                            color: AppColors.listDividerFor(isDarkMode),
                          ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ],
    );
  }
}

class TradePurchaseListItem extends StatelessWidget {
  final StockPurchase purchase;
  final String portfolioName;
  final bool isDarkMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TradePurchaseListItem({
    super.key,
    required this.purchase,
    required this.portfolioName,
    required this.isDarkMode,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final thumbnailColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.header;
    return InkWell(
      onTap: onEdit,
      onLongPress: () => _showActionSheet(context),
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: thumbnailColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              padding: purchase.logoUrl.isEmpty
                  ? EdgeInsets.zero
                  : const EdgeInsets.all(6),
              child: purchase.logoUrl.isEmpty
                  ? TradeTickerFallback(
                      ticker: purchase.ticker,
                      color: thumbnailColor,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      child: kIsWeb
                          // Match the account icon workaround for Web image lifetime.
                          ? Image.network(
                              purchase.logoUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                  ? child
                                  : TradeTickerFallback(
                                      ticker: purchase.ticker,
                                      color: thumbnailColor,
                                    ),
                              errorBuilder: (context, error, stackTrace) =>
                                  TradeTickerFallback(
                                    ticker: purchase.ticker,
                                    color: thumbnailColor,
                                  ),
                            )
                          : CachedNetworkImage(
                              imageUrl: purchase.logoUrl,
                              fit: BoxFit.contain,
                              placeholder: (context, url) =>
                                  TradeTickerFallback(
                                    ticker: purchase.ticker,
                                    color: thumbnailColor,
                                  ),
                              errorWidget: (context, url, error) =>
                                  TradeTickerFallback(
                                    ticker: purchase.ticker,
                                    color: thumbnailColor,
                                  ),
                            ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    purchase.ticker,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$portfolioName • ${formatTradeDate(purchase.boughtAt)}',
                    style: TextStyle(color: secondaryColor, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatTradeShares(purchase.sharesBought)} shares • ${purchase.buyPriceUsd.toStringAsFixed(4)} USD',
                    style: TextStyle(color: secondaryColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${formatAmount(purchase.costUsd)}',
                  style: TextStyle(
                    color: isDarkMode ? AppColors.darkIncome : AppColors.income,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatAmount(purchase.cashPaidUsd)} USD',
                  style: TextStyle(color: secondaryColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dangerColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;
    showAppModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.add_shopping_cart_outlined, color: textColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      purchase.ticker,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${formatAmount(purchase.cashPaidUsd)} USD',
                    style: TextStyle(color: secondaryColor, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const AppCardDivider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined, color: textColor),
                title: Text(
                  'แก้ไขประวัติซื้อ',
                  style: TextStyle(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onEdit();
                },
              ),
              const AppCardDivider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline, color: dangerColor),
                title: Text(
                  'ลบประวัติซื้อ',
                  style: TextStyle(color: dangerColor),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
