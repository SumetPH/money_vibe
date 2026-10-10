import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../providers/category_provider.dart';
import '../../widgets/account_icon_widget.dart';

class TransactionListItem extends StatelessWidget {
  final AppTransaction tx;
  final AccountProvider accountProvider;
  final CategoryProvider catProvider;
  final VoidCallback onTap;
  final bool isDarkMode;
  final String? viewingAccountId;

  const TransactionListItem({
    super.key,
    required this.tx,
    required this.accountProvider,
    required this.catProvider,
    required this.onTap,
    required this.isDarkMode,
    this.viewingAccountId,
  });

  @override
  Widget build(BuildContext context) {
    final account = accountProvider.findById(tx.accountId);
    final toAccount = tx.toAccountId != null
        ? accountProvider.findById(tx.toAccountId!)
        : null;
    final category = tx.categoryId != null
        ? catProvider.findById(tx.categoryId!)
        : null;

    final typeColor = _typeColor(tx.type, isDarkMode);
    double displayAmount = tx.type.isExpenseLike || tx.type.isDecreaseBalance
        ? -tx.amount
        : tx.amount;

    if (viewingAccountId != null) {
      if ((tx.type == TransactionType.debtRepay ||
              tx.type == TransactionType.debtTransfer) &&
          tx.toAccountId == viewingAccountId) {
        displayAmount = tx.amount;
      } else if (tx.type == TransactionType.transfer) {
        if (tx.accountId == viewingAccountId) {
          displayAmount = -tx.amount;
        } else if (tx.toAccountId == viewingAccountId) {
          displayAmount = tx.toAmount ?? tx.amount;
        }
      }
    }

    final currency = viewingAccountId != null
        ? (viewingAccountId == tx.toAccountId
              ? toAccount?.currency
              : account?.currency)
        : account?.currency;

    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimaryColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final note = tx.note?.trim();
    final subLabel = _buildSubLabel(category?.name, note);
    final amountColor =
        (tx.type == TransactionType.transfer && viewingAccountId == null)
        ? (isDarkMode ? AppColors.darkTransfer : AppColors.transfer)
        : (tx.type == TransactionType.debtRepay && viewingAccountId == null)
        ? (isDarkMode ? AppColors.darkExpense : AppColors.expense)
        : (tx.type == TransactionType.debtTransfer && viewingAccountId == null)
        ? (isDarkMode ? AppColors.darkDebtTransfer : AppColors.debtTransfer)
        : AppColors.getAmountColor(displayAmount, isDarkMode);
    final amountText =
        (tx.type == TransactionType.transfer && viewingAccountId == null)
        ? '฿ ${formatAmount(tx.amount)}${account?.currency == 'THB' ? '' : ' ${account?.currency ?? ''}'}'
        : '${displayAmount < 0
              ? '-'
              : displayAmount > 0
              ? '+'
              : ''}฿ ${formatAmount(displayAmount.abs())}${currency == 'THB' ? '' : ' ${currency ?? ''}'}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.xLarge),
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (category?.color ?? typeColor).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              child: Icon(
                tx.type == TransactionType.debtTransfer
                    ? Icons.account_tree
                    : tx.type == TransactionType.transfer
                    ? Icons.swap_horiz
                    : tx.type == TransactionType.debtRepay
                    ? Icons.payment
                    : (category?.icon ?? Icons.receipt),
                color: category?.color ?? typeColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAccountWidget(
                    account,
                    toAccount,
                    tx,
                    textPrimaryColor,
                    isDarkMode,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(fontSize: 13, color: textSecondaryColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(tx.dateTime),
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(TransactionType type, bool isDarkMode) {
    if (isDarkMode) {
      switch (type) {
        case TransactionType.income:
          return AppColors.darkIncome;
        case TransactionType.expense:
          return AppColors.darkExpense;
        case TransactionType.transfer:
          return AppColors.darkTransfer;
        case TransactionType.debtRepay:
          return AppColors.darkDebtRepay;
        case TransactionType.debtTransfer:
          return AppColors.darkDebtTransfer;
        case TransactionType.increaseBalance:
          return AppColors.darkIncome;
        case TransactionType.decreaseBalance:
          return AppColors.darkExpense;
      }
    }
    switch (type) {
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.transfer:
        return AppColors.transfer;
      case TransactionType.debtRepay:
        return AppColors.debtRepay;
      case TransactionType.debtTransfer:
        return AppColors.debtTransfer;
      case TransactionType.increaseBalance:
        return AppColors.income;
      case TransactionType.decreaseBalance:
        return AppColors.expense;
    }
  }

  Widget _buildAccountWidget(
    Account? account,
    Account? toAccount,
    AppTransaction tx,
    Color textPrimaryColor,
    bool isDarkMode,
  ) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: textPrimaryColor,
    );

    if (tx.type.usesDestinationAccount) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (account != null) ...[
            AccountIconWidget(
              account: account,
              size: 16,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              account?.name ?? '-',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('→', style: style),
          ),
          if (toAccount != null) ...[
            AccountIconWidget(
              account: toAccount,
              size: 16,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              toAccount?.name ?? '-',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    String prefix = '';
    if (tx.type.isIncreaseBalance || tx.type.isDecreaseBalance) {
      prefix = tx.type == TransactionType.increaseBalance
          ? 'ปรับเพิ่ม '
          : 'ปรับลด ';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefix.isNotEmpty) Text(prefix, style: style),
        if (account != null) ...[
          AccountIconWidget(account: account, size: 16, isDarkMode: isDarkMode),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            account?.name ?? '-',
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _buildSubLabel(String? categoryName, String? note) {
    final parts = <String>[
      if (categoryName != null && categoryName.isNotEmpty) categoryName,
      if (note != null && note.isNotEmpty) note,
    ];
    return parts.join(' • ');
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
