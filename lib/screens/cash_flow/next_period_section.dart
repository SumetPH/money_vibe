import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/budget.dart';
import '../../services/cash_flow_forecast_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_status_chip.dart';
import 'cash_flow_forecast_scope.dart';
import 'cash_flow_section.dart';
import 'budget_what_if_dialog.dart';
import 'forecast_budget_picker_sheet.dart';

/// สรุปยอดคาดการณ์งวดถัดไป
class NextPeriodHero extends StatelessWidget {
  final NextPeriodForecast forecast;
  final bool isDarkMode;

  const NextPeriodHero({
    super.key,
    required this.forecast,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final leftover = forecast.projectedLeftover;
    return AppInsetCard(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'งวดถัดไป · หลังเคลียร์ยอด ${formatCashFlowDate(forecast.windowEnd)} จะเหลือ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondaryFor(isDarkMode),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatAmount(leftover, showSign: true)} บาท',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.amountColor(leftover, isDarkMode: isDarkMode),
          ),
        ),
        const SizedBox(height: 12),
        CashFlowTimeline(
          steps: [
            CashFlowTimelineStep('เริ่มงวด', forecast.windowStart),
            CashFlowTimelineStep('วันเคลียร์', forecast.windowEnd),
          ],
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 14),
        _metric('ยกมาจากงวดนี้', forecast.startingLeftover),
        _metric('เงินเข้าที่ยังไม่ติ๊ก', forecast.incomingTotal),
        _metric('เงินออกที่ยังไม่ติ๊ก', -forecast.outgoingTotal),
        _metric('ยอดบัตรที่ต้องชำระ', -forecast.cardTotal),
        _metric('งบประมาณ', -(forecast.budgetTotal + forecast.savingsTotal)),
        _metric('อยากซื้อ', -forecast.purchaseTotal),
      ],
    );
  }

  Widget _metric(String label, double amount) =>
      CashFlowMetricRow(label: label, amount: amount, isDarkMode: isDarkMode);
}

/// รายละเอียดของงวดถัดไปต่อจากลิสต์จำลอง: บัตรเครดิต และงบประมาณ (งบที่เหลือ + แผนออม)
List<Widget> nextPeriodDetailSections(
  NextPeriodForecast forecast,
  bool isDarkMode,
) => [
  ...cashFlowSection(
    title:
        'บัตรเครดิต · ${formatAmount(-forecast.cardTotal, showSign: true)} บาท',
    emptyText: 'ไม่มียอดบัตรที่ต้องชำระเพิ่ม',
    rows: [
      for (final line in forecast.cardLines)
        _NextCardRow(line: line, isDarkMode: isDarkMode),
    ],
    isDarkMode: isDarkMode,
  ),
  cashFlowNote(
    'ยอดที่รูดไปแล้วของบิลที่จะสรุปหลังวันเคลียร์ยอดของงวดนี้ '
    'ยอดที่จะรูดเพิ่มนับอยู่ในงบที่เหลือ',
    isDarkMode,
  ),

  ...forecastBudgetSections(
    forecast.budgetLines,
    forecast.savingsPlans,
    forecast.budgetTotal + forecast.savingsTotal,
    isDarkMode,
    periodEnd: forecast.windowEnd,
    periodLabel: 'งวดถัดไป',
  ),
];

/// งบรายจ่ายและแผนออมรวมอยู่ใน section งบประมาณเดียวกัน
List<Widget> forecastBudgetSections(
  List<BudgetRemainingLine> budgetLines,
  List<BudgetRemainingLine> savingsPlans,
  double total,
  bool isDarkMode, {
  required DateTime periodEnd,
  required String periodLabel,
  String emptyText = 'ยังไม่มีงบประมาณ',
}) {
  final allLines = [...budgetLines, ...savingsPlans];
  Set<String> idsOf(Iterable<BudgetRemainingLine> lines) =>
      lines.map((l) => l.budget.id).toSet();
  return [
    ...cashFlowSection(
      title: 'งบประมาณ · ${formatAmount(-total, showSign: true)} บาท',
      emptyText: emptyText,
      rows: [
        for (final line in allLines.where((l) => l.isIncluded))
          _BudgetRow(
            line: line,
            periodEnd: periodEnd,
            periodLabel: periodLabel,
            isDarkMode: isDarkMode,
          ),
        if (allLines.isNotEmpty)
          _BudgetSelectorRow(
            periodEnd: periodEnd,
            periodLabel: periodLabel,
            includedCount: idsOf(allLines.where((l) => l.isIncluded)).length,
            totalCount: idsOf(allLines).length,
            isDarkMode: isDarkMode,
          ),
      ],
      isDarkMode: isDarkMode,
    ),
    cashFlowNote(
      'ถือว่างบที่เหลือจะถูกใช้จนหมด และกันแผนออมเต็มเป้าหมายตามรอบที่แสดง '
      'แตะงบเพื่อลองเปลี่ยนยอดเฉพาะ$periodLabel (ไม่เปลี่ยนงบจริง) '
      'ถ้างบไหนซ้ำกับรายการเงินออกประจำ ให้ปิดงบนั้นจากการคำนวณ',
      isDarkMode,
    ),
  ];
}

class _NextCardRow extends StatelessWidget {
  final NextCardLine line;
  final bool isDarkMode;

  const _NextCardRow({required this.line, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final parts = [
      'ยังไม่สรุป · สรุปยอด ${formatCashFlowDate(line.statementDate)}',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          AccountIconWidget(
            account: line.account,
            size: 32,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.account.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryFor(isDarkMode),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  parts.join(' · '),
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          Text(
            formatAmount(-line.total, showSign: true),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.amountColor(-line.total, isDarkMode: isDarkMode),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final BudgetRemainingLine line;
  final DateTime periodEnd;
  final String periodLabel;
  final bool isDarkMode;

  const _BudgetRow({
    required this.line,
    required this.periodEnd,
    required this.periodLabel,
    required this.isDarkMode,
  });

  String get _detail {
    final amount = formatAmount(line.amount);
    final usage = line.budget.type == BudgetType.savings
        ? 'เป้าหมาย $amount'
        : 'ใช้ไป ${formatAmount(line.spent)} จาก $amount';
    return line.hasWhatIf
        ? '$usage (จริง ${formatAmount(line.budget.amount)})'
        : usage;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = line.remaining;
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    return InkWell(
      onTap: () => showBudgetWhatIfDialog(
        context,
        line: line,
        periodEnd: periodEnd,
        periodLabel: periodLabel,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(line.budget.icon, size: 22, color: line.budget.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        line.budget.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryFor(isDarkMode),
                        ),
                      ),
                      if (line.hasWhatIf)
                        AppStatusChip(
                          // รอบงบเริ่มแล้วแต่งบจริงยังไม่ตรงกับยอดสมมติ
                          label: line.cycleStart.isAfter(DateTime.now())
                              ? 'ยอดสมมติ'
                              : 'รอบเริ่มแล้ว · ยังไม่ใช้เป็นงบจริง',
                          color: AppColors.saveButtonFor(isDarkMode),
                        ),
                    ],
                  ),
                  Text(
                    '${formatCashFlowDate(line.cycleStart)} – ${formatCashFlowDate(line.cycleEnd)} ${line.cycleEnd.year}\n'
                    '$_detail',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              formatAmount(-remaining, showSign: true),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.amountColor(
                  -remaining,
                  isDarkMode: isDarkMode,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetSelectorRow extends StatelessWidget {
  final DateTime periodEnd;
  final String periodLabel;
  final int includedCount;
  final int totalCount;
  final bool isDarkMode;

  const _BudgetSelectorRow({
    required this.periodEnd,
    required this.periodLabel,
    required this.includedCount,
    required this.totalCount,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) => CashFlowSelectorRow(
    label: 'เลือกงบที่นำมาคำนวณ',
    includedCount: includedCount,
    totalCount: totalCount,
    onTap: () => showForecastBudgetPickerSheet(
      context,
      periodEnd: periodEnd,
      periodLabel: periodLabel,
    ),
    isDarkMode: isDarkMode,
  );
}
