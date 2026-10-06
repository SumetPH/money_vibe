import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../services/credit_card_bill_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/app_inset_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 2. Bill Inset Card
// ─────────────────────────────────────────────────────────────────────────────
class CreditCardBillItemCard extends StatelessWidget {
  final CreditCardBill bill;
  final Account account;
  final bool isDarkMode;
  final String dateRangeText;
  final String? statementHint;
  final VoidCallback onTap;

  const CreditCardBillItemCard({
    super.key,
    required this.bill,
    required this.account,
    required this.isDarkMode,
    required this.dateRangeText,
    required this.statementHint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final surfaceVariant = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.sectionHeader;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    final openBillColor = isDarkMode
        ? AppColors.darkTransfer
        : AppColors.transfer;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(color: AppColors.borderFor(isDarkMode), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Bill Tag + Status Badge + Chevron
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bill.isOpen
                          ? openBillColor.withValues(alpha: 0.16)
                          : surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          bill.isOpen
                              ? Icons.timelapse_rounded
                              : Icons.receipt_long_rounded,
                          size: 14,
                          color: bill.isOpen ? openBillColor : textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          bill.isOpen ? 'รอบปัจจุบัน' : bill.billName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: bill.isOpen ? openBillColor : textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildStatusBadge(bill, isDarkMode),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date Range and Statement hint
              Row(
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 16,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateRangeText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  if (statementHint != null) ...[
                    const Spacer(),
                    Text(
                      statementHint!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: AppCardDivider(),
              ),

              // Financial Amounts Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ยอดที่ต้องชำระ',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '฿ ${formatAmount(bill.totalAmount)}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'ชำระแล้ว',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '฿ ${formatAmount(bill.paidAmount)}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: bill.paidAmount == 0
                                ? textSecondary
                                : (isDarkMode
                                      ? AppColors.darkIncome
                                      : AppColors.income),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Remaining amount or Carried over pill
              if (bill.remainingAmount != 0 || bill.carriedOverAmount != 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadii.large),
                  ),
                  child: Column(
                    children: [
                      if (bill.remainingAmount != 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              bill.remainingAmount > 0
                                  ? 'คงเหลือที่ต้องชำระ'
                                  : 'ชำระเกิน',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            Text(
                              '${bill.remainingAmount > 0 ? '-' : '+'}฿ ${formatAmount(bill.remainingAmount.abs())}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: bill.remainingAmount > 0
                                    ? (isDarkMode
                                          ? AppColors.darkExpense
                                          : AppColors.expense)
                                    : (isDarkMode
                                          ? AppColors.darkIncome
                                          : AppColors.income),
                              ),
                            ),
                          ],
                        ),
                      if (bill.remainingAmount != 0 &&
                          bill.carriedOverAmount != 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: AppCardDivider(),
                        ),
                      if (bill.carriedOverAmount != 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              bill.carriedOverAmount > 0
                                  ? 'ยอดค้างยกมาจากรอบก่อน'
                                  : 'ยอดชำระเกินยกมา',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            Text(
                              '${bill.carriedOverAmount > 0 ? '-' : '+'}฿ ${formatAmount(bill.carriedOverAmount.abs())}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: bill.carriedOverAmount > 0
                                    ? (isDarkMode
                                          ? AppColors.darkExpense
                                          : AppColors.expense)
                                    : (isDarkMode
                                          ? AppColors.darkIncome
                                          : AppColors.income),
                              ),
                            ),
                          ],
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

  Widget _buildStatusBadge(CreditCardBill bill, bool isDarkMode) {
    Color color;
    String text;

    if (bill.isOverpaid) {
      color = isDarkMode ? AppColors.darkIncome : AppColors.income;
      text = 'ชำระเกิน';
    } else if (bill.isFullyPaid) {
      color = isDarkMode ? AppColors.darkIncome : AppColors.income;
      text = 'ชำระครบ';
    } else if (bill.hasPartialPaid) {
      color = isDarkMode ? AppColors.darkFabYellow : AppColors.fabYellow;
      text = 'ชำระบางส่วน';
    } else if (bill.isOpen) {
      color = isDarkMode ? AppColors.darkTransfer : AppColors.transfer;
      text = 'กำลังใช้งาน';
    } else {
      color = isDarkMode ? AppColors.darkExpense : AppColors.expense;
      text = 'ยังไม่ชำระ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
