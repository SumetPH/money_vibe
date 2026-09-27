import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/cash_flow_forecast_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/app_switch.dart';
import 'cash_flow_forecast_scope.dart';

/// Sheet เลือก Liquid account ที่นำมาคำนวณ; บันทึกทันทีเมื่อสลับสวิตช์
Future<void> showLiquidAccountPickerSheet(BuildContext context) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _LiquidAccountPickerSheet(),
  );
}

class _LiquidAccountPickerSheet extends StatelessWidget {
  const _LiquidAccountPickerSheet();

  Future<void> _toggle(
    BuildContext context,
    LiquidBalanceLine line,
    bool isIncluded,
  ) async {
    try {
      await context.read<AccountProvider>().updateAccount(
        line.account.copyWith(isExcludedFromCashForecast: !isIncluded),
      );
    } catch (e) {
      debugPrint('LiquidAccountPickerSheet: toggle account error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกการตั้งค่าบัญชีไม่สำเร็จ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final lines = watchCashFlowForecast(context)?.liquidLines ?? const [];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppModalBottomSheetHeader(title: 'บัญชีที่นำมาคำนวณ'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'ปิดบัญชีที่ไม่ต้องการใช้จ่าย เช่น เงินสำรองฉุกเฉิน',
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
                    for (var i = 0; i < lines.length; i++) ...[
                      if (i > 0)
                        const AppCardDivider(indent: 60, endIndent: 16),
                      LiquidAccountRow(
                        line: lines[i],
                        isDarkMode: isDarkMode,
                        trailing: AppSwitch(
                          value: lines[i].isIncluded,
                          onChanged: (value) =>
                              _toggle(context, lines[i], value),
                        ),
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

/// แถวบัญชี: ไอคอน, ชื่อ, ยอด THB และ control ทางขวา
class LiquidAccountRow extends StatelessWidget {
  final LiquidBalanceLine line;
  final bool isDarkMode;
  final Widget? trailing;

  const LiquidAccountRow({
    super.key,
    required this.line,
    required this.isDarkMode,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
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
                    color: line.isIncluded
                        ? AppColors.textPrimaryFor(isDarkMode)
                        : textSecondary.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '${formatAmount(line.balance)} บาท',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
