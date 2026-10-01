import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/budget.dart';
import '../../models/planned_purchase.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../services/cash_flow_forecast_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/app_inset_card.dart';
import 'cash_flow_forecast_scope.dart';
import 'cash_flow_section.dart';
import 'forecast_budget_picker_sheet.dart';
import 'planned_purchase_form_screen.dart';

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
        _metric('งบรายจ่าย', -forecast.budgetTotal),
        _metric('แผนออม', -forecast.savingsTotal),
        _metric('อยากซื้อ', -forecast.purchaseTotal),
      ],
    );
  }

  Widget _metric(String label, double amount) =>
      CashFlowMetricRow(label: label, amount: amount, isDarkMode: isDarkMode);
}

/// รายละเอียดของงวดถัดไปต่อจากเงินเข้าออก: บัตรเครดิต, งบที่เหลือ, แผนออม และอยากซื้อ
/// (เรียงตาม metric ใน [NextPeriodHero])
List<Widget> nextPeriodDetailSections(
  NextPeriodForecast forecast,
  bool isDarkMode,
) => [
  ...forecastPurchaseSections(
    forecast.purchases,
    forecast.purchaseTotal,
    isDarkMode,
    note:
        'ติ๊กเพื่อกันเงินซื้อในงวดถัดไป แยกจากงวดนี้ ถ้าติ๊กทั้งสองงวดจะกันเงินทั้งสองครั้ง',
  ),

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
    forecast.budgetTotal,
    forecast.savingsTotal,
    isDarkMode,
    isNextPeriod: true,
  ),
];

List<Widget> forecastPurchaseSections(
  List<PlannedPurchase> purchases,
  double purchaseTotal,
  bool isDarkMode, {
  required String note,
  bool isCurrent = false,
  bool isManage = false,
}) => [
  ...cashFlowSection(
    title: isManage
        ? 'รายการอยากซื้อทั้งหมด'
        : 'อยากซื้อ · ${formatAmount(-purchaseTotal, showSign: true)} บาท',
    emptyText: 'ยังไม่มีรายการอยากซื้อ เพิ่มได้ที่แท็บจัดการ',
    rows: [
      for (final purchase in purchases)
        _PurchaseRow(
          purchase: purchase,
          isDarkMode: isDarkMode,
          isCurrent: isCurrent,
          isManage: isManage,
        ),
      if (isManage) _AddPurchaseRow(isDarkMode: isDarkMode),
    ],
    isDarkMode: isDarkMode,
  ),
  cashFlowNote(note, isDarkMode),
];

List<Widget> forecastBudgetSections(
  List<BudgetRemainingLine> budgetLines,
  List<BudgetRemainingLine> savingsPlans,
  double budgetTotal,
  double savingsTotal,
  bool isDarkMode, {
  bool isNextPeriod = false,
}) => [
  ...cashFlowSection(
    title: 'งบรายจ่าย · ${formatAmount(-budgetTotal, showSign: true)} บาท',
    emptyText: 'ยังไม่มีงบรายจ่าย',
    rows: [
      for (final line in budgetLines.where((l) => l.isIncluded))
        _BudgetRow(line: line, isDarkMode: isDarkMode),
      if (budgetLines.isNotEmpty)
        _BudgetSelectorRow(
          type: BudgetType.expense,
          isNextPeriod: isNextPeriod,
          includedCount: budgetLines
              .where((l) => l.isIncluded)
              .map((l) => l.budget.id)
              .toSet()
              .length,
          totalCount: budgetLines.map((l) => l.budget.id).toSet().length,
          isDarkMode: isDarkMode,
        ),
    ],
    isDarkMode: isDarkMode,
  ),
  cashFlowNote(
    'ถือว่างบที่เหลือจะถูกใช้จนหมด ถ้างบไหนซ้ำกับรายการเงินออกประจำ '
    'ให้ปิดงบนั้นจากการคำนวณ เลือกงบแยกกันในแต่ละงวด',
    isDarkMode,
  ),

  ...cashFlowSection(
    title: 'แผนออม · ${formatAmount(-savingsTotal, showSign: true)} บาท',
    emptyText: 'ยังไม่มีแผนออมในงบประมาณ',
    rows: [
      for (final plan in savingsPlans.where((p) => p.isIncluded))
        _BudgetRow(line: plan, isDarkMode: isDarkMode),
      if (savingsPlans.isNotEmpty)
        _BudgetSelectorRow(
          type: BudgetType.savings,
          isNextPeriod: isNextPeriod,
          includedCount: savingsPlans
              .where((p) => p.isIncluded)
              .map((p) => p.budget.id)
              .toSet()
              .length,
          totalCount: savingsPlans.map((p) => p.budget.id).toSet().length,
          isDarkMode: isDarkMode,
        ),
    ],
    isDarkMode: isDarkMode,
  ),
  cashFlowNote(
    'กันออมเต็มเป้าหมายตามรอบที่แสดง เพราะยังไม่มีการติดตามยอดออมแล้ว',
    isDarkMode,
  ),
];

void _openPurchaseForm(BuildContext context, [PlannedPurchase? purchase]) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PlannedPurchaseFormScreen(purchase: purchase),
    ),
  );
}

class _PurchaseRow extends StatelessWidget {
  final PlannedPurchase purchase;
  final bool isDarkMode;
  final bool isCurrent;
  final bool isManage;

  const _PurchaseRow({
    required this.purchase,
    required this.isDarkMode,
    required this.isCurrent,
    required this.isManage,
  });

  Future<void> _toggle(BuildContext context, bool isIncluded) async {
    try {
      await context.read<CashFlowForecastProvider>().updatePlannedPurchase(
        isCurrent
            ? purchase.copyWith(isIncludedCurrent: isIncluded)
            : purchase.copyWith(isIncluded: isIncluded),
      );
    } catch (e) {
      debugPrint('NextPeriodSection: toggle purchase error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกสถานะไม่สำเร็จ')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final isIncluded =
        isManage ||
        (isCurrent ? purchase.isIncludedCurrent : purchase.isIncluded);
    return InkWell(
      onTap: () => isManage
          ? _openPurchaseForm(context, purchase)
          : _toggle(context, !isIncluded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
        child: Row(
          children: [
            // ติ๊กแบบเดียวกับแถวเงินเข้าออก: ติ๊ก = นับในการคาดการณ์
            if (isManage)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.shopping_bag_outlined, color: textSecondary),
              )
            else
              IconButton(
                tooltip: isIncluded ? 'ไม่นับรายการนี้' : 'นับรายการนี้',
                onPressed: () => _toggle(context, !isIncluded),
                icon: Icon(
                  isIncluded
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isIncluded
                      ? AppColors.incomeFor(isDarkMode)
                      : textSecondary.withValues(alpha: 0.6),
                ),
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                purchase.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isIncluded
                      ? AppColors.textPrimaryFor(isDarkMode)
                      : textSecondary,
                ),
              ),
            ),
            Text(
              formatAmount(-purchase.amount, showSign: true),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isIncluded
                    ? AppColors.expenseFor(isDarkMode)
                    : textSecondary.withValues(alpha: 0.6),
                decoration: isIncluded ? null : TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPurchaseRow extends StatelessWidget {
  final bool isDarkMode;

  const _AddPurchaseRow({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    return InkWell(
      onTap: () => _openPurchaseForm(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.add_rounded, size: 20, color: textSecondary),
            const SizedBox(width: 12),
            Text(
              'เพิ่มรายการอยากซื้อ',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryFor(isDarkMode),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  final bool isDarkMode;

  const _BudgetRow({required this.line, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final remaining = line.remaining;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(line.budget.icon, size: 22, color: line.budget.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.budget.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryFor(isDarkMode),
                  ),
                ),
                Text(
                  '${formatCashFlowDate(line.cycleStart)} – ${formatCashFlowDate(line.cycleEnd)} ${line.cycleEnd.year}\n'
                  '${line.budget.type == BudgetType.savings ? 'เป้าหมาย ${formatAmount(line.budget.amount)}' : 'ใช้ไป ${formatAmount(line.spent)} จาก ${formatAmount(line.budget.amount)}'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryFor(isDarkMode),
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatAmount(-remaining, showSign: true),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.amountColor(-remaining, isDarkMode: isDarkMode),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetSelectorRow extends StatelessWidget {
  final BudgetType type;
  final bool isNextPeriod;
  final int includedCount;
  final int totalCount;
  final bool isDarkMode;

  const _BudgetSelectorRow({
    required this.type,
    required this.isNextPeriod,
    required this.includedCount,
    required this.totalCount,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) => CashFlowSelectorRow(
    label: type == BudgetType.savings
        ? 'เลือกแผนออมที่นำมาคำนวณ'
        : 'เลือกงบที่นำมาคำนวณ',
    includedCount: includedCount,
    totalCount: totalCount,
    onTap: () => showForecastBudgetPickerSheet(
      context,
      type,
      isNextPeriod: isNextPeriod,
    ),
    isDarkMode: isDarkMode,
  );
}
