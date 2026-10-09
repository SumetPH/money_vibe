import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/app_inset_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. Hero Summary Card
// ─────────────────────────────────────────────────────────────────────────────
class CreditCardBillHeroCard extends StatelessWidget {
  final Account account;
  final double totalUnpaid;
  final double openCycleAmount;
  final double pastPending;
  final bool isDarkMode;

  const CreditCardBillHeroCard({
    super.key,
    required this.account,
    required this.totalUnpaid,
    required this.openCycleAmount,
    required this.pastPending,
    required this.isDarkMode,
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

    // ค้างชำระ = มีบิลที่ตัดรอบแล้วยังจ่ายไม่ครบ; ยอดรอบปัจจุบันยังไม่ถือว่าค้าง
    final hasPending = pastPending > 0;
    final hasOpenCycle = openCycleAmount > 0;
    final statusColor = hasPending
        ? (isDarkMode ? AppColors.darkExpense : AppColors.expense)
        : hasOpenCycle
        ? (isDarkMode ? AppColors.darkTransfer : AppColors.transfer)
        : (isDarkMode ? AppColors.darkIncome : AppColors.income);
    final statusIcon = hasPending
        ? Icons.warning_amber_rounded
        : hasOpenCycle
        ? Icons.schedule_rounded
        : Icons.check_circle_rounded;
    final statusLabel = hasPending
        ? 'มียอดค้างชำระ'
        : hasOpenCycle
        ? 'รอตัดรอบ'
        : 'ชำระครบแล้ว';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(color: AppColors.borderFor(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Label + Statement Day Tag
          Row(
            children: [
              Text(
                'ยอดรอชำระรวม',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const Spacer(),
              if (account.statementDay != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadii.large),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'สรุปยอดทุกวันที่ ${account.statementDay}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Big Bold Total Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '฿ ${formatAmount(totalUnpaid)}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: hasPending ? statusColor : textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const AppCardDivider(),
          const SizedBox(height: 14),

          // Breakdown: Open Cycle vs Past Bills
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รอบปัจจุบัน (ยังไม่ตัดรอบ)',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '฿ ${formatAmount(openCycleAmount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: AppColors.borderFor(isDarkMode),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รอบบิลที่ตัดยอดแล้ว',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '฿ ${formatAmount(pastPending)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: pastPending > 0
                            ? (isDarkMode
                                  ? AppColors.darkExpense
                                  : AppColors.expense)
                            : textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
