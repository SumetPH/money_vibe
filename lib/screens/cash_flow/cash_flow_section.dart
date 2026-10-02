import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/fixed_cash_flow_item.dart';
import '../../widgets/app_segmented_tabs.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import 'cash_flow_forecast_scope.dart';
import '../../widgets/app_inset_card.dart';

/// หัวข้อ + การ์ดรายการของหน้า Cash-flow forecast (แสดง [emptyText] เมื่อไม่มีแถว)
List<Widget> cashFlowSection({
  required String title,
  required String emptyText,
  required List<Widget> rows,
  required bool isDarkMode,
}) => [
  AppSectionHeader(title),
  AppInsetCard(
    children: rows.isEmpty
        ? [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                emptyText,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryFor(isDarkMode),
                ),
              ),
            ),
          ]
        : [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const AppCardDivider(),
              rows[i],
            ],
          ],
  ),
];

/// ตัวเลือกงวดของรายการในฟอร์ม (งวดนี้/งวดถัดไป)
Widget buildCashFlowPeriodTabs(
  CashFlowPeriod selected,
  ValueChanged<CashFlowPeriod> onChanged,
) => AppSegmentedTabs(
  segments: [
    for (final period in CashFlowPeriod.values)
      AppSegment(
        label: period.label,
        isSelected: selected == period,
        onTap: () => onChanged(period),
      ),
  ],
);

/// คำอธิบายสั้นใต้การ์ด
Widget cashFlowNote(String text, bool isDarkMode) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
  child: Text(
    text,
    style: TextStyle(
      fontSize: 12,
      color: AppColors.textSecondaryFor(isDarkMode),
    ),
  ),
);

/// แถว label ↔ ยอดพร้อมเครื่องหมายใน hero ของการคาดการณ์
class CashFlowMetricRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isDarkMode;

  const CashFlowMetricRow({
    super.key,
    required this.label,
    required this.amount,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryFor(isDarkMode),
            ),
          ),
        ),
        Text(
          formatAmount(amount, showSign: true),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryFor(isDarkMode),
          ),
        ),
      ],
    ),
  );
}

/// ปุ่มลบท้ายฟอร์มของหน้า Cash-flow forecast
class CashFlowDeleteButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDarkMode;

  const CashFlowDeleteButton({
    super.key,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final expense = AppColors.expenseFor(isDarkMode);
    return Material(
      color: AppColors.surfaceFor(isDarkMode),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        side: BorderSide(color: expense.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline_rounded, color: expense, size: 20),
              const SizedBox(width: 8),
              Text(
                'ลบรายการนี้',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: expense,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// หนึ่งจุดบนเส้นเวลาของงวด
class CashFlowTimelineStep {
  final String label;
  final DateTime date;
  final bool isHighlighted;

  const CashFlowTimelineStep(
    this.label,
    this.date, {
    this.isHighlighted = false,
  });
}

/// เส้นเวลาแนวนอนบอกว่างวดเริ่มนับเมื่อไหร่ วันนี้อยู่ตรงไหน และดูถึงวันไหน
class CashFlowTimeline extends StatelessWidget {
  static const _dotSize = 8.0;

  final List<CashFlowTimelineStep> steps;
  final bool isDarkMode;

  const CashFlowTimeline({
    super.key,
    required this.steps,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final lineColor = AppColors.borderFor(isDarkMode);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: _dotSize,
                      height: _dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: steps[i].isHighlighted
                            ? AppColors.saveButtonFor(isDarkMode)
                            : textSecondary,
                      ),
                    ),
                    if (i < steps.length - 1)
                      Expanded(child: Container(height: 1, color: lineColor)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  formatCashFlowDate(steps[i].date),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryFor(isDarkMode),
                  ),
                ),
                Text(
                  steps[i].label,
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// แถวท้ายการ์ดสำหรับเปิด sheet เลือกรายการที่นำมาคำนวณ เช่น "3 จาก 4"
class CashFlowSelectorRow extends StatelessWidget {
  final String label;
  final int includedCount;
  final int totalCount;
  final VoidCallback onTap;
  final bool isDarkMode;

  const CashFlowSelectorRow({
    super.key,
    required this.label,
    required this.includedCount,
    required this.totalCount,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, size: 20, color: textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryFor(isDarkMode),
                ),
              ),
            ),
            Text(
              '$includedCount จาก $totalCount',
              style: TextStyle(fontSize: 15, color: textSecondary),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
