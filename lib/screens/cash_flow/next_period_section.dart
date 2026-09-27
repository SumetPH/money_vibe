import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/planned_purchase.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../services/cash_flow_forecast_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_switch.dart';
import 'cash_flow_forecast_scope.dart';
import 'cash_flow_section.dart';
import 'planned_purchase_form_screen.dart';

const _iconRowDivider = AppCardDivider(indent: 60, endIndent: 16);

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
          'งวดถัดไป · จะเหลือถึง ${formatCashFlowDate(forecast.windowEnd)}',
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
            CashFlowTimelineStep('เงินเข้า', forecast.windowStart),
            CashFlowTimelineStep('วันสุดท้าย', forecast.windowEnd),
          ],
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 14),
        _metric('ยกมาจากงวดนี้', forecast.startingLeftover),
        _metric('เงินเข้าที่ยังไม่ติ๊ก', forecast.incomingTotal),
        _metric('เงินออกที่ยังไม่ติ๊ก', -forecast.outgoingTotal),
        _metric('ยอดบัตรที่ต้องชำระ', -forecast.cardTotal),
        _metric('งบที่เหลือรอบนี้', -forecast.budgetTotal),
        _metric('อยากซื้อ', -forecast.purchaseTotal),
      ],
    );
  }

  Widget _metric(String label, double amount) =>
      CashFlowMetricRow(label: label, amount: amount, isDarkMode: isDarkMode);
}

/// รายละเอียดของงวดถัดไปต่อจากเงินเข้าออก: บัตรเครดิต, งบที่เหลือ และอยากซื้อ
/// (เรียงตาม metric ใน [NextPeriodHero])
List<Widget> nextPeriodDetailSections(
  NextPeriodForecast forecast,
  bool isDarkMode,
) => [
  ...cashFlowSection(
    title: 'บัตรเครดิต · -${formatAmount(forecast.cardTotal)} บาท',
    emptyText: 'ไม่มียอดบัตรที่ครบกำหนดในงวดถัดไป',
    divider: _iconRowDivider,
    rows: [
      for (final line in forecast.cardLines)
        _NextCardRow(line: line, isDarkMode: isDarkMode),
    ],
    isDarkMode: isDarkMode,
  ),
  cashFlowNote(
    'รวมยอดที่รูดไปแล้วแต่ยังไม่สรุป ณ วันนี้ ยอดที่จะรูดเพิ่มนับอยู่ในงบที่เหลือ',
    isDarkMode,
  ),

  ...cashFlowSection(
    title: 'อยากซื้อ · -${formatAmount(forecast.purchaseTotal)} บาท',
    emptyText: '',
    divider: const AppCardDivider(),
    rows: [
      for (final purchase in forecast.purchases)
        _PurchaseRow(purchase: purchase, isDarkMode: isDarkMode),
      _AddPurchaseRow(isDarkMode: isDarkMode),
    ],
    isDarkMode: isDarkMode,
  ),
  cashFlowNote(
    'เปิด/ปิดแต่ละรายการเพื่อดูว่าถ้าซื้อแล้วเงินงวดถัดไปจะเหลือเท่าไหร่',
    isDarkMode,
  ),

  ...cashFlowSection(
    title: 'งบที่เหลือรอบนี้ · -${formatAmount(forecast.budgetTotal)} บาท',
    emptyText: 'ยังไม่มีงบรายจ่าย',
    divider: const AppCardDivider(),
    rows: [
      for (final line in forecast.budgetLines)
        _BudgetRow(line: line, isDarkMode: isDarkMode),
    ],
    isDarkMode: isDarkMode,
  ),
  cashFlowNote(
    'ถือว่างบที่เหลือจะถูกใช้จนหมด ถ้ารายการเงินออกประจำซ้ำกับหมวดในงบ '
    'ให้เอาออกจากฝั่งใดฝั่งหนึ่ง',
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

  const _PurchaseRow({required this.purchase, required this.isDarkMode});

  Future<void> _toggle(BuildContext context, bool isIncluded) async {
    try {
      await context.read<CashFlowForecastProvider>().updatePlannedPurchase(
        purchase.copyWith(isIncluded: isIncluded),
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
    final isIncluded = purchase.isIncluded;
    return InkWell(
      onTap: () => _openPurchaseForm(context, purchase),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: [
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
            const SizedBox(width: 8),
            AppSwitch(
              value: isIncluded,
              onChanged: (value) => _toggle(context, value),
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
      'ครบกำหนด ${formatCashFlowDate(line.dueDate)}',
      if (line.statementAmount > 0)
        'สรุปแล้ว ${formatAmount(line.statementAmount)}',
      if (line.unbilledAmount > 0)
        'ยังไม่สรุป ${formatAmount(line.unbilledAmount)}',
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
                  'ใช้ไป ${formatAmount(line.spent)} จาก '
                  '${formatAmount(line.budget.amount)}',
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
