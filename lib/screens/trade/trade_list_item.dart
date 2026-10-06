import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/stock_trade.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import 'trade_tracker_models.dart';

class TradeListItem extends StatelessWidget {
  final StockTrade trade;
  final String portfolioName;
  final bool isDarkMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TradeListItem({
    super.key,
    required this.trade,
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
    final pnlColor = AppColors.getAmountColor(trade.realizedPnlUsd, isDarkMode);
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
              padding: trade.logoUrl.isEmpty
                  ? EdgeInsets.zero
                  : const EdgeInsets.all(6),
              child: trade.logoUrl.isEmpty
                  ? TradeTickerFallback(
                      ticker: trade.ticker,
                      color: thumbnailColor,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      child: kIsWeb
                          // Match the account icon workaround for Web image lifetime.
                          ? Image.network(
                              trade.logoUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                  ? child
                                  : TradeTickerFallback(
                                      ticker: trade.ticker,
                                      color: thumbnailColor,
                                    ),
                              errorBuilder: (context, error, stackTrace) =>
                                  TradeTickerFallback(
                                    ticker: trade.ticker,
                                    color: thumbnailColor,
                                  ),
                            )
                          : CachedNetworkImage(
                              imageUrl: trade.logoUrl,
                              fit: BoxFit.contain,
                              placeholder: (_, _) => TradeTickerFallback(
                                ticker: trade.ticker,
                                color: thumbnailColor,
                              ),
                              errorWidget: (_, _, _) => TradeTickerFallback(
                                ticker: trade.ticker,
                                color: thumbnailColor,
                              ),
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                            ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          trade.ticker,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (trade.pnlSource == PnlSource.broker) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppColors.darkTransfer.withValues(alpha: 0.2)
                                : AppColors.transfer.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadii.tiny),
                            border: Border.all(
                              color: isDarkMode
                                  ? AppColors.darkTransfer
                                  : AppColors.transfer,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'Broker',
                            style: TextStyle(
                              fontSize: 9,
                              color: isDarkMode
                                  ? AppColors.darkTransfer
                                  : AppColors.transfer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$portfolioName • ${formatTradeDate(trade.soldAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: secondaryColor, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatTradeShares(trade.sharesSold)} shares • ${trade.sellPriceUsd.toStringAsFixed(4)} USD',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: secondaryColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${trade.realizedPnlUsd >= 0 ? '+' : ''}${formatAmount(trade.realizedPnlUsd)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: pnlColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatAmount(trade.cashReceivedUsd)} USD',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    final pnlColor = AppColors.getAmountColor(trade.realizedPnlUsd, isDarkMode);
    final thumbnailColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.header;

    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: thumbnailColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                        padding: trade.logoUrl.isEmpty
                            ? EdgeInsets.zero
                            : const EdgeInsets.all(6),
                        child: trade.logoUrl.isEmpty
                            ? TradeTickerFallback(
                                ticker: trade.ticker,
                                color: thumbnailColor,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.small,
                                ),
                                child: kIsWeb
                                    // Match the account icon workaround for Web image lifetime.
                                    ? Image.network(
                                        trade.logoUrl,
                                        fit: BoxFit.contain,
                                        loadingBuilder:
                                            (context, child, progress) =>
                                                progress == null
                                                ? child
                                                : TradeTickerFallback(
                                                    ticker: trade.ticker,
                                                    color: thumbnailColor,
                                                  ),
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                TradeTickerFallback(
                                                  ticker: trade.ticker,
                                                  color: thumbnailColor,
                                                ),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: trade.logoUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (_, _) =>
                                            TradeTickerFallback(
                                              ticker: trade.ticker,
                                              color: thumbnailColor,
                                            ),
                                        errorWidget: (_, _, _) =>
                                            TradeTickerFallback(
                                              ticker: trade.ticker,
                                              color: thumbnailColor,
                                            ),
                                        fadeInDuration: Duration.zero,
                                        fadeOutDuration: Duration.zero,
                                      ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    trade.ticker,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (trade.pnlSource == PnlSource.broker) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? AppColors.darkTransfer.withValues(
                                              alpha: 0.2,
                                            )
                                          : AppColors.transfer.withValues(
                                              alpha: 0.1,
                                            ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.tiny,
                                      ),
                                      border: Border.all(
                                        color: isDarkMode
                                            ? AppColors.darkTransfer
                                            : AppColors.transfer,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      'Broker P/L',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDarkMode
                                            ? AppColors.darkTransfer
                                            : AppColors.transfer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$portfolioName • ${formatTradeDate(trade.soldAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${trade.realizedPnlUsd >= 0 ? '+' : ''}${formatAmount(trade.realizedPnlUsd)}',
                        style: TextStyle(
                          color: pnlColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const AppCardDivider(),
                  const SizedBox(height: 12),
                  TradeDetailRow(
                    label: 'จำนวน',
                    value: formatTradeShares(trade.sharesSold),
                    isDarkMode: isDarkMode,
                  ),
                  TradeDetailRow(
                    label: 'ราคาขาย',
                    value: '${trade.sellPriceUsd.toStringAsFixed(4)} USD',
                    isDarkMode: isDarkMode,
                  ),
                  TradeDetailRow(
                    label: 'ราคาทุน',
                    value: '${trade.costBasisUsd.toStringAsFixed(4)} USD',
                    isDarkMode: isDarkMode,
                  ),
                  TradeDetailRow(
                    label: 'เงินสดรับสุทธิ (Net)',
                    value: '${formatAmount(trade.cashReceivedUsd)} USD',
                    isDarkMode: isDarkMode,
                  ),
                  if (trade.grossProceedsUsd != null ||
                      (trade.brokerFeeUsd != null &&
                          trade.brokerFeeUsd! > 0)) ...[
                    const SizedBox(height: 10),
                    const AppCardDivider(),
                    const SizedBox(height: 10),
                    if (trade.grossProceedsUsd != null)
                      TradeDetailRow(
                        label: 'มูลค่าขายรวม (Gross)',
                        value: '${formatAmount(trade.grossProceedsUsd!)} USD',
                        isDarkMode: isDarkMode,
                      ),
                    if (trade.brokerFeeUsd != null && trade.brokerFeeUsd! > 0)
                      TradeDetailRow(
                        label: 'ค่าธรรมเนียม Broker',
                        value: '${formatAmount(trade.brokerFeeUsd!)} USD',
                        isDarkMode: isDarkMode,
                      ),
                    if (trade.exchangeFeeUsd != null &&
                        trade.exchangeFeeUsd! > 0)
                      TradeDetailRow(
                        label: 'SEC / Exchange Fee',
                        value: '${formatAmount(trade.exchangeFeeUsd!)} USD',
                        isDarkMode: isDarkMode,
                      ),
                    if (trade.taxFeeUsd != null && trade.taxFeeUsd! > 0)
                      TradeDetailRow(
                        label: 'Tax / VAT',
                        value: '${formatAmount(trade.taxFeeUsd!)} USD',
                        isDarkMode: isDarkMode,
                      ),
                  ],
                  const SizedBox(height: 10),
                  const AppCardDivider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined, color: textColor),
                    title: Text('แก้ไข', style: TextStyle(color: textColor)),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onEdit();
                    },
                  ),
                  const AppCardDivider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, color: dangerColor),
                    title: Text('ลบ', style: TextStyle(color: dangerColor)),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onDelete();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class TradeDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const TradeDetailRow({
    super.key,
    required this.label,
    required this.value,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: secondaryColor, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class TradeTickerFallback extends StatelessWidget {
  final String ticker;
  final Color color;

  const TradeTickerFallback({
    super.key,
    required this.ticker,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        ticker.characters.take(2).toString(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
