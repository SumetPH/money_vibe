import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';

class TransactionListHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDarkMode;

  /// สีไอคอนและขอบเมื่อ action กำลังทำงานอยู่ (เช่น มีคำค้นหา)
  final Color? activeColor;

  const TransactionListHeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    required this.isDarkMode,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          side: BorderSide(
            color: activeColor ?? AppColors.borderFor(isDarkMode),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            color:
                activeColor ??
                (isDarkMode
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class TransactionCashFlowSummary extends StatelessWidget {
  final double income;
  final double expense;
  final String periodLabel;
  final bool isDarkMode;
  final bool hidePeriodSelector;
  final VoidCallback? onSelectPeriod;

  /// กรองตามหมวด (ประเภทเดียว): แสดงเฉพาะฝั่งที่มียอด และซ่อนสุทธิถ้ามีฝั่งเดียว
  final bool isSingleType;

  /// เปิดจากบัญชี: ยอดคือเงินเข้า/ออกของบัญชี (รวมโอน/ปรับยอด) ไม่ใช่รายรับรายจ่ายจริง
  final bool isAccountFlow;
  final String title;

  const TransactionCashFlowSummary({
    super.key,
    required this.income,
    required this.expense,
    required this.periodLabel,
    required this.isDarkMode,
    required this.hidePeriodSelector,
    required this.onSelectPeriod,
    this.isSingleType = false,
    this.isAccountFlow = false,
    this.title = 'กระแสเงินสด',
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final surface = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;
    final net = income - expense;
    final showIncome = !isSingleType || income > 0;
    final showExpense = !isSingleType || expense > 0 || !showIncome;
    final showNet = showIncome && showExpense;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(color: AppColors.borderFor(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!hidePeriodSelector)
                InkWell(
                  onTap: onSelectPeriod,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        periodLabel,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: textSecondary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (showIncome)
                Expanded(
                  child: TransactionSummaryAmount(
                    label: isAccountFlow ? 'เงินเข้า' : 'รายรับ',
                    amount: income,
                    color: incomeColor,
                  ),
                ),
              if (showNet) const SizedBox(width: 16),
              if (showExpense)
                Expanded(
                  child: TransactionSummaryAmount(
                    label: isAccountFlow ? 'เงินออก' : 'รายจ่าย',
                    amount: expense,
                    color: expenseColor,
                  ),
                ),
            ],
          ),
          if (showNet) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'สุทธิ',
                  style: TextStyle(color: textSecondary, fontSize: 16),
                ),
                const SizedBox(width: 12),
                Text(
                  '${net < 0 ? '-' : ''}฿ ${formatAmount(net.abs())}',
                  style: TextStyle(
                    color: AppColors.getAmountColor(net, isDarkMode),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class TransactionSummaryAmount extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const TransactionSummaryAmount({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '฿ ${formatAmount(amount)}',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
