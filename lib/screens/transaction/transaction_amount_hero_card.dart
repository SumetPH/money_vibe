import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/calculator_text_field_config.dart';

class TransactionAmountHeroCard extends StatelessWidget {
  final TransactionType type;
  final TextEditingController amountController;
  final FocusNode amountFocusNode;
  final TextEditingController toAmountController;
  final FocusNode toAmountFocusNode;
  final Account? selectedAccount;
  final Account? selectedToAccount;
  final double accountBalance;
  final bool isDarkMode;

  const TransactionAmountHeroCard({
    super.key,
    required this.type,
    required this.amountController,
    required this.amountFocusNode,
    required this.toAmountController,
    required this.toAmountFocusNode,
    required this.selectedAccount,
    required this.selectedToAccount,
    required this.accountBalance,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final surfaceVariant = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.sectionHeader;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    final fromCurrency = selectedAccount?.currency == 'USD' ? 'USD' : 'THB';
    final toCurrency = selectedToAccount?.currency == 'USD' ? 'USD' : 'THB';
    final isCrossCurrency =
        type == TransactionType.transfer &&
        selectedAccount != null &&
        selectedToAccount != null &&
        selectedAccount!.currency != selectedToAccount!.currency;

    final isAdjust =
        type == TransactionType.increaseBalance ||
        type == TransactionType.decreaseBalance;

    final typeColor = switch (type) {
      TransactionType.income || TransactionType.increaseBalance =>
        isDarkMode ? AppColors.darkIncome : AppColors.income,
      TransactionType.expense || TransactionType.decreaseBalance =>
        isDarkMode ? AppColors.darkExpense : AppColors.expense,
      TransactionType.transfer =>
        isDarkMode ? AppColors.darkTransfer : AppColors.transfer,
      TransactionType.debtRepay || TransactionType.debtTransfer =>
        isDarkMode ? AppColors.darkDebtTransfer : AppColors.debtTransfer,
    };

    final amountLabel = switch (type) {
      TransactionType.debtRepay => 'เงินต้น',
      TransactionType.debtTransfer => 'ยอดโยก',
      TransactionType.increaseBalance => 'ยอดปรับเพิ่ม',
      TransactionType.decreaseBalance => 'ยอดปรับลด',
      _ => 'จำนวนเงิน',
    };

    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        side: BorderSide(color: AppColors.borderFor(isDarkMode), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (!amountFocusNode.hasFocus) {
            amountFocusNode.requestFocus();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.xLarge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row inside card: Label + Currency badge
              Row(
                children: [
                  Text(
                    amountLabel,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Text(
                      fromCurrency,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Primary amount row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    fromCurrency == 'USD' ? '\$ ' : '฿ ',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: typeColor,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      focusNode: amountFocusNode,
                      readOnly: calculatorTextFieldReadOnly,
                      showCursor: true,
                      keyboardType: calculatorTextInputType,
                      inputFormatters: calculatorTextInputFormatters,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? AppColors.darkDivider
                              : AppColors.divider,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Cross-currency conversion field
              if (isCrossCurrency) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: AppCardDivider(),
                ),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        size: 14,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'จำนวนที่ได้รับปลายทาง',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                      child: Text(
                        toCurrency,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      toCurrency == 'USD' ? '\$ ' : '฿ ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: toAmountController,
                        focusNode: toAmountFocusNode,
                        readOnly: calculatorTextFieldReadOnly,
                        showCursor: true,
                        keyboardType: calculatorTextInputType,
                        inputFormatters: calculatorTextInputFormatters,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode
                                ? AppColors.darkDivider
                                : AppColors.divider,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Balance preview badge (for increase/decrease balance)
              if (isAdjust) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadii.large),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ยอดคงเหลือหลังปรับ:',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        '฿ ${NumberFormat('#,##0.00').format(accountBalance)}',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
