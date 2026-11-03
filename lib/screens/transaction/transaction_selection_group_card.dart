import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../providers/account_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/app_inset_card.dart';

class TransactionSelectionGroupCard extends StatelessWidget {
  final TransactionType type;
  final List<Account> accounts;
  final Account? selectedAccount;
  final Account? selectedToAccount;
  final Account? selectedDebtAccount;
  final Category? selectedCategory;
  final List<Category> categories;
  final AccountProvider accountProvider;
  final List<AppTransaction> transactions;
  final bool isDarkMode;
  final ValueChanged<bool> onPickAccount;
  final VoidCallback onPickDebtAccount;
  final VoidCallback onClearAccount;
  final VoidCallback onPickCategory;

  const TransactionSelectionGroupCard({
    super.key,
    required this.type,
    required this.accounts,
    required this.selectedAccount,
    required this.selectedToAccount,
    required this.selectedDebtAccount,
    required this.selectedCategory,
    required this.categories,
    required this.accountProvider,
    required this.transactions,
    required this.isDarkMode,
    required this.onPickAccount,
    required this.onPickDebtAccount,
    required this.onClearAccount,
    required this.onPickCategory,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDarkMode ? AppColors.darkSurface : AppColors.surface;

    final bool isDebtRepay = type == TransactionType.debtRepay;
    final bool isDebtTransfer = type == TransactionType.debtTransfer;
    final bool isExchange = type == TransactionType.exchange;
    final bool isTransfer = type == TransactionType.transfer || isExchange;
    final bool isAdjust =
        type == TransactionType.increaseBalance ||
        type == TransactionType.decreaseBalance;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(color: AppColors.borderFor(isDarkMode)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (isDebtRepay) ...[
            // 1. Debt Account
            TransactionSelectionRow(
              title: selectedDebtAccount?.name ?? 'เลือกบัญชีหนี้สิน',
              subtitle: selectedDebtAccount != null
                  ? 'ยอดหนี้ ${CurrencyUtils.formatWithSymbol(accountProvider.getBalance(selectedDebtAccount!.id, transactions), selectedDebtAccount!.currency)}'
                  : 'หนี้สินที่ต้องการชำระ',
              subtitleColor: selectedDebtAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedDebtAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedDebtAccount != null
                  ? AccountIconWidget(
                      account: selectedDebtAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.credit_card_rounded,
                      Colors.orange,
                      isDarkMode,
                    ),
              onTap: onPickDebtAccount,
              isDarkMode: isDarkMode,
            ),
            const AppCardDivider(),
            // 2. Payment Source Account
            TransactionSelectionRow(
              title: selectedAccount?.name ?? 'เลือกบัญชีที่ใช้ชำระ',
              subtitle: selectedAccount != null
                  ? 'คงเหลือ ${CurrencyUtils.formatWithSymbol(accountProvider.getBalance(selectedAccount!.id, transactions), selectedAccount!.currency)}'
                  : 'ปล่อยว่างได้หากชำระภายนอก',
              subtitleColor: selectedAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedAccount != null
                  ? AccountIconWidget(
                      account: selectedAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.account_balance_wallet_outlined,
                      isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      isDarkMode,
                    ),
              trailing: selectedAccount != null
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'ล้างบัญชี',
                      onPressed: onClearAccount,
                    )
                  : null,
              onTap: () => onPickAccount(false),
              isDarkMode: isDarkMode,
            ),
            const AppCardDivider(),
            // 3. Category (Optional)
            TransactionSelectionRow(
              title: selectedCategory?.name ?? 'เลือกหมวดหมู่',
              subtitle: selectedCategory != null
                  ? 'หมวดหมู่รายการ'
                  : 'ปล่อยว่างได้',
              iconWidget: selectedCategory != null
                  ? _categoryIconBox(selectedCategory!)
                  : _defaultIconBox(
                      Icons.category_outlined,
                      isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      isDarkMode,
                    ),
              onTap: onPickCategory,
              isDarkMode: isDarkMode,
            ),
          ] else if (isDebtTransfer) ...[
            // 1. From Debt Account
            TransactionSelectionRow(
              title: selectedAccount?.name ?? 'เลือกบัญชีหนี้สินต้นทาง',
              subtitle: selectedAccount != null
                  ? 'ยอดหนี้ ${CurrencyUtils.formatWithSymbol(accountProvider.getBalance(selectedAccount!.id, transactions), selectedAccount!.currency)}'
                  : 'โอนออกจากหนี้สินนี้',
              subtitleColor: selectedAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedAccount != null
                  ? AccountIconWidget(
                      account: selectedAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.account_tree_outlined,
                      Colors.orange,
                      isDarkMode,
                    ),
              onTap: () => onPickAccount(false),
              isDarkMode: isDarkMode,
            ),
            const AppCardDivider(),
            // 2. To Debt Account
            TransactionSelectionRow(
              title: selectedDebtAccount?.name ?? 'เลือกบัญชีหนี้สินปลายทาง',
              subtitle: selectedDebtAccount != null
                  ? 'ยอดหนี้ ${CurrencyUtils.formatWithSymbol(accountProvider.getBalance(selectedDebtAccount!.id, transactions), selectedDebtAccount!.currency)}'
                  : 'โอนเข้าสู่หนี้สินนี้',
              subtitleColor: selectedDebtAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedDebtAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedDebtAccount != null
                  ? AccountIconWidget(
                      account: selectedDebtAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.account_tree_rounded,
                      Colors.orange,
                      isDarkMode,
                    ),
              onTap: onPickDebtAccount,
              isDarkMode: isDarkMode,
            ),
            const AppCardDivider(),
            // 3. Category (Optional)
            TransactionSelectionRow(
              title: selectedCategory?.name ?? 'เลือกหมวดหมู่',
              subtitle: selectedCategory != null
                  ? 'หมวดหมู่รายการ'
                  : 'ปล่อยว่างได้',
              iconWidget: selectedCategory != null
                  ? _categoryIconBox(selectedCategory!)
                  : _defaultIconBox(
                      Icons.category_outlined,
                      isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      isDarkMode,
                    ),
              onTap: onPickCategory,
              isDarkMode: isDarkMode,
            ),
          ] else if (isTransfer) ...[
            // Transfer: From Account
            TransactionSelectionRow(
              title: selectedAccount?.name ?? 'เลือกบัญชีต้นทาง',
              subtitle: selectedAccount != null
                  ? 'คงเหลือ ${CurrencyUtils.formatWithSymbol(accountProvider.getBalance(selectedAccount!.id, transactions), selectedAccount!.currency)}'
                  : isExchange
                  ? 'จ่ายจากบัญชีนี้'
                  : 'โอนออกจากบัญชีนี้',
              subtitleColor: selectedAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedAccount != null
                  ? AccountIconWidget(
                      account: selectedAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.account_balance_wallet_outlined,
                      Colors.blue,
                      isDarkMode,
                    ),
              onTap: () => onPickAccount(false),
              isDarkMode: isDarkMode,
            ),
            const AppCardDivider(),
            // Transfer: To Account
            TransactionSelectionRow(
              title: selectedToAccount?.name ?? 'เลือกบัญชีปลายทาง',
              subtitle: selectedToAccount != null
                  ? 'คงเหลือ ${CurrencyUtils.formatWithSymbol(accountProvider.getBalance(selectedToAccount!.id, transactions), selectedToAccount!.currency)}'
                  : isExchange
                  ? 'รับเงินที่แลกเข้าบัญชีนี้ (คนละสกุล)'
                  : 'โอนเข้าสู่บัญชีนี้',
              subtitleColor: selectedToAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedToAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedToAccount != null
                  ? AccountIconWidget(
                      account: selectedToAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.input_rounded,
                      Colors.blue,
                      isDarkMode,
                    ),
              onTap: () => onPickAccount(true),
              isDarkMode: isDarkMode,
            ),
          ] else if (isAdjust) ...[
            // Adjust balance: Only Account
            TransactionSelectionRow(
              title: selectedAccount?.name ?? 'เลือกบัญชี',
              subtitle: selectedAccount != null
                  ? 'คงเหลือปัจจุบัน ${CurrencyUtils.formatWithSymbol(accountProvider.getBalance(selectedAccount!.id, transactions), selectedAccount!.currency)}'
                  : 'แตะเพื่อเลือกบัญชี',
              subtitleColor: selectedAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedAccount != null
                  ? AccountIconWidget(
                      account: selectedAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.account_balance_wallet_outlined,
                      isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      isDarkMode,
                    ),
              onTap: () => onPickAccount(false),
              isDarkMode: isDarkMode,
            ),
          ] else ...[
            // Default: Income & Expense
            // Row 1: Account
            TransactionSelectionRow(
              title: selectedAccount?.name ?? 'เลือกบัญชี',
              subtitle: selectedAccount != null
                  ? 'คงเหลือ ${CurrencyUtils.formatWithSymbol(accountProvider.getBalance(selectedAccount!.id, transactions), selectedAccount!.currency)}'
                  : 'แตะเพื่อเลือกบัญชี',
              subtitleColor: selectedAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedAccount != null
                  ? AccountIconWidget(
                      account: selectedAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.account_balance_wallet_outlined,
                      isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      isDarkMode,
                    ),
              onTap: () => onPickAccount(false),
              isDarkMode: isDarkMode,
            ),
            const AppCardDivider(),
            // Row 2: Category
            TransactionSelectionRow(
              title: selectedCategory?.name ?? 'เลือกหมวดหมู่',
              subtitle: selectedCategory != null
                  ? 'หมวดหมู่รายการ'
                  : 'แตะเพื่อเลือกหมวดหมู่',
              iconWidget: selectedCategory != null
                  ? _categoryIconBox(selectedCategory!)
                  : _defaultIconBox(
                      Icons.category_outlined,
                      isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      isDarkMode,
                    ),
              onTap: onPickCategory,
              isDarkMode: isDarkMode,
            ),
          ],
        ],
      ),
    );
  }

  static Widget _defaultIconBox(IconData icon, Color color, bool isDarkMode) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  static Widget _categoryIconBox(Category cat) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cat.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Icon(cat.icon, color: cat.color, size: 20),
    );
  }
}

class TransactionSelectionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final Widget iconWidget;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isDarkMode;

  const TransactionSelectionRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    required this.iconWidget,
    this.trailing,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.xLarge),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor ?? textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: textSecondary,
                ),
          ],
        ),
      ),
    );
  }
}
