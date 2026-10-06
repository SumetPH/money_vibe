import 'package:flutter/material.dart';
import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/app_inset_card.dart';

class RecurringRemainingSummary extends StatelessWidget {
  final List<DateTime> upcoming;
  final List<DateTime> past;
  final RecurringTransaction recurring;
  final Map<DateTime, RecurringOccurrence> occurrencesByDay;
  final Map<String, AppTransaction> transactionsById;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color typeColor;
  final bool hasEndDate;

  const RecurringRemainingSummary({
    super.key,
    required this.upcoming,
    required this.past,
    required this.recurring,
    required this.occurrencesByDay,
    required this.transactionsById,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.typeColor,
    required this.hasEndDate,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate occurrences by status (both upcoming and past)
    int doneCount = 0;
    int pendingCount = 0;
    int skippedCount = 0;
    double doneAmount = 0;
    double pendingAmount = 0;
    double skippedAmount = 0;

    // Process all dates (upcoming + past)
    final allDates = [...upcoming, ...past];
    for (final date in allDates) {
      final occ = occurrencesByDay[DateTime(date.year, date.month, date.day)];
      final status = occ?.status ?? OccurrenceStatus.pending;
      final amount = _amountForOccurrence(occ);
      switch (status) {
        case OccurrenceStatus.done:
          doneCount++;
          doneAmount += amount;
        case OccurrenceStatus.pending:
          pendingCount++;
          pendingAmount += amount;
        case OccurrenceStatus.skipped:
          skippedCount++;
          skippedAmount += amount;
      }
    }

    final totalCount = doneCount + pendingCount + skippedCount;
    final totalAmount = doneAmount + pendingAmount + skippedAmount;

    // Only show summary if there are done or skipped items
    if (totalCount == 0 || (doneCount == 0 && skippedCount == 0)) {
      return const SizedBox.shrink();
    }

    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final incomeColor = isDark ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDark ? AppColors.darkExpense : AppColors.expense;
    final isIncome = recurring.transactionType == TransactionType.income;
    final actionWord = isIncome ? 'รับ' : 'จ่าย';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: typeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: typeColor),
              const SizedBox(width: 8),
              Text(
                'สรุปยอดทั้งหมด',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Done
          if (doneCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: incomeColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$actionWordแล้ว',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '$doneCount รายการ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${formatAmount(doneAmount)} บาท',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: incomeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Pending (only show if has end date)
          if (pendingCount > 0 && hasEndDate) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'รอ$actionWord',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '$pendingCount รายการ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${formatAmount(pendingAmount)} บาท',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: expenseColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Skipped
          if (skippedCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ข้ามแล้ว',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '$skippedCount รายการ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${formatAmount(skippedAmount)} บาท',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Divider (only show if has end date)
          if (hasEndDate) ...[
            const AppCardDivider(),
            const SizedBox(height: 8),
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'รวมทั้งหมด',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '$totalCount รายการ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${formatAmount(totalAmount)} บาท',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  double _amountForOccurrence(RecurringOccurrence? occurrence) {
    final transactionId = occurrence?.transactionId;
    if (transactionId == null || transactionId.isEmpty) {
      return recurring.amount;
    }

    final linkedTransaction = transactionsById[transactionId];
    return linkedTransaction?.amount ?? recurring.amount;
  }
}
