import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/budget.dart';
import '../../providers/budget_provider.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/cash_flow_forecast_service.dart';
import '../../theme/app_colors.dart';

enum _WhatIfAction {
  /// เก็บเป็นยอดสมมติของงวด
  save,

  /// ลบยอดสมมติ กลับไปใช้ยอดงบจริง
  reset,

  /// แก้งบจริงเป็นยอดนี้ แล้วลบยอดสมมติของงวด
  applyToBudget,
}

typedef _WhatIfResult = ({_WhatIfAction action, double? amount});

/// Dialog ลองเปลี่ยนยอดงบ ([line]) เฉพาะงวดที่เคลียร์ยอดวัน [periodEnd]
/// ยอดสมมติใช้ในการคาดการณ์เท่านั้น จนกว่าผู้ใช้จะกด "ใช้เป็นงบจริง"
Future<void> showBudgetWhatIfDialog(
  BuildContext context, {
  required BudgetRemainingLine line,
  required DateTime periodEnd,
  required String periodLabel,
}) async {
  final result = await showDialog<_WhatIfResult>(
    context: context,
    builder: (_) => _BudgetWhatIfDialog(line: line, periodLabel: periodLabel),
  );
  if (result == null || !context.mounted) return;

  final provider = context.read<CashFlowForecastProvider>();
  final budgetProvider = context.read<BudgetProvider>();
  final current = provider.budgetSettingFor(line.budget.id, periodEnd);
  final amount = result.amount;
  try {
    switch (result.action) {
      case _WhatIfAction.save:
        await provider.saveBudgetSetting(current.copyWith(amount: amount));
      case _WhatIfAction.reset:
        await provider.saveBudgetSetting(current.copyWith(clearAmount: true));
      case _WhatIfAction.applyToBudget:
        await budgetProvider.updateBudget(line.budget.copyWith(amount: amount));
        await provider.saveBudgetSetting(current.copyWith(clearAmount: true));
    }
  } catch (e) {
    debugPrint('BudgetWhatIfDialog: save error: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกยอดไม่สำเร็จ')));
    }
  }
}

class _BudgetWhatIfDialog extends StatefulWidget {
  final BudgetRemainingLine line;
  final String periodLabel;

  const _BudgetWhatIfDialog({required this.line, required this.periodLabel});

  @override
  State<_BudgetWhatIfDialog> createState() => _BudgetWhatIfDialogState();
}

class _BudgetWhatIfDialogState extends State<_BudgetWhatIfDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.line.amount.toStringAsFixed(2),
  );
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(_WhatIfAction action) {
    final value = double.tryParse(_controller.text.trim().replaceAll(',', ''));
    if (value == null || value < 0) {
      setState(() => _errorText = 'กรอกจำนวนเงินตั้งแต่ 0 ขึ้นไป');
      return;
    }
    Navigator.pop<_WhatIfResult>(context, (action: action, amount: value));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final isDarkMode = settings.isDarkMode;
    final textColor = AppColors.textPrimaryFor(isDarkMode);
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final budget = widget.line.budget;
    final isSavings = budget.type == BudgetType.savings;

    // design-check: allow input or multi-choice dialog
    return AlertDialog(
      backgroundColor: AppColors.surfaceFor(isDarkMode),
      title: Text(
        'ลองเปลี่ยนยอด ${budget.name}',
        style: TextStyle(color: textColor),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: textColor),
            onSubmitted: (_) => _submit(_WhatIfAction.save),
            decoration: InputDecoration(
              labelText: isSavings ? 'เป้าหมายที่ลองใช้' : 'งบที่ลองใช้',
              suffixText: 'บาท',
              errorText: _errorText,
              labelStyle: TextStyle(color: textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ใช้คำนวณเฉพาะ${widget.periodLabel} ไม่เปลี่ยนงบจริง '
            '(${isSavings ? 'เป้าหมาย' : 'งบ'}จริง ${formatAmount(budget.amount)} บาท)',
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
        ],
      ),
      actions: [
        if (widget.line.hasWhatIf)
          TextButton(
            onPressed: () => Navigator.pop<_WhatIfResult>(context, (
              action: _WhatIfAction.reset,
              amount: null,
            )),
            child: Text('ใช้ยอดจริง', style: TextStyle(color: textColor)),
          ),
        TextButton(
          onPressed: () => _submit(_WhatIfAction.applyToBudget),
          child: Text('ใช้เป็นงบจริง', style: TextStyle(color: textColor)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ยกเลิก', style: TextStyle(color: textColor)),
        ),
        TextButton(
          onPressed: () => _submit(_WhatIfAction.save),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentFor(
              isDarkMode,
              settings.themeColor,
            ),
          ),
          child: const Text('บันทึกยอดสมมติ'),
        ),
      ],
    );
  }
}
