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
/// ที่นำมาคำนวณในทั้งสองงวด; บันทึกทันทีเมื่อสลับสวิตช์
Future<void> showForecastBudgetPickerSheet(
  BuildContext context,
  BudgetType type,
) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ForecastBudgetPickerSheet(type: type),
  );
}

class _ForecastBudgetPickerSheet extends StatelessWidget {
  final BudgetType type;

  const _ForecastBudgetPickerSheet({required this.type});

  bool get _isSavings => type == BudgetType.savings;

  Future<void> _toggle(
    BuildContext context,
    Budget budget,
    bool isIncluded,
  ) async {
    try {
      await context.read<BudgetProvider>().updateBudget(
        budget.copyWith(isExcludedFromCashForecast: !isIncluded),
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
            title: _isSavings ? 'แผนออมที่นำมาคำนวณ' : 'งบที่นำมาคำนวณ',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              _isSavings
                  ? 'ปิดแผนออมที่ไม่ต้องการกันเงินในทั้งสองงวด'
                  : 'ปิดงบที่ไม่ต้องการนับ เช่น งบที่ซ้ำกับรายการเงินออกประจำ',
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
  final bool isDarkMode;
  final ValueChanged<bool> onChanged;

  const _BudgetToggleRow({
    required this.budget,
    required this.isDarkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final isIncluded = !budget.isExcludedFromCashForecast;
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
