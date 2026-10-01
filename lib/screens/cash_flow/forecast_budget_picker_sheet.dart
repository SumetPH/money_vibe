import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/budget.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/app_switch.dart';

/// Sheet เลือกงบ ([BudgetType.expense]) หรือแผนออม ([BudgetType.savings])
/// ที่นำมาคำนวณในงวดนี้หรืองวดถัดไป ([isNextPeriod]) แยกกัน; บันทึกทันทีเมื่อสลับสวิตช์
Future<void> showForecastBudgetPickerSheet(
  BuildContext context,
  BudgetType type, {
  required bool isNextPeriod,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _ForecastBudgetPickerSheet(type: type, isNextPeriod: isNextPeriod),
  );
}

class _ForecastBudgetPickerSheet extends StatelessWidget {
  final BudgetType type;
  final bool isNextPeriod;

  const _ForecastBudgetPickerSheet({
    required this.type,
    required this.isNextPeriod,
  });

  bool get _isSavings => type == BudgetType.savings;

  String get _periodLabel => isNextPeriod ? 'งวดถัดไป' : 'งวดนี้';

  Future<void> _toggle(
    BuildContext context,
    Budget budget,
    bool isIncluded,
  ) async {
    try {
      await context.read<BudgetProvider>().updateBudget(
        isNextPeriod
            ? budget.copyWith(isExcludedFromNextCashForecast: !isIncluded)
            : budget.copyWith(isExcludedFromCashForecast: !isIncluded),
      );
    } catch (e) {
      debugPrint('ForecastBudgetPickerSheet: toggle budget error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกการตั้งค่างบไม่สำเร็จ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final budgets = context
        .watch<BudgetProvider>()
        .budgets
        .where((b) => b.type == type && !b.isHidden)
        .toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppModalBottomSheetHeader(
            title: _isSavings
                ? 'แผนออมที่นำมาคำนวณ$_periodLabel'
                : 'งบที่นำมาคำนวณ$_periodLabel',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              _isSavings
                  ? 'ปิดแผนออมที่ไม่ต้องการกันเงินใน$_periodLabel'
                  : 'ปิดงบที่ไม่ต้องการนับใน$_periodLabel เช่น งบที่ซ้ำกับรายการเงินออกประจำ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryFor(isDarkMode),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                AppInsetCard(
                  children: [
                    for (var i = 0; i < budgets.length; i++) ...[
                      if (i > 0) const AppCardDivider(),
                      _BudgetToggleRow(
                        budget: budgets[i],
                        isIncluded: isNextPeriod
                            ? !budgets[i].isExcludedFromNextCashForecast
                            : !budgets[i].isExcludedFromCashForecast,
                        isDarkMode: isDarkMode,
                        onChanged: (value) =>
                            _toggle(context, budgets[i], value),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetToggleRow extends StatelessWidget {
  final Budget budget;
  final bool isIncluded;
  final bool isDarkMode;
  final ValueChanged<bool> onChanged;

  const _BudgetToggleRow({
    required this.budget,
    required this.isIncluded,
    required this.isDarkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          Icon(budget.icon, size: 22, color: budget.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  budget.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isIncluded
                        ? AppColors.textPrimaryFor(isDarkMode)
                        : textSecondary.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  budget.type == BudgetType.savings
                      ? 'เป้าหมาย ${formatAmount(budget.amount)} บาท'
                      : 'งบ ${formatAmount(budget.amount)} บาท',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          AppSwitch(value: isIncluded, onChanged: onChanged),
        ],
      ),
    );
  }
}
