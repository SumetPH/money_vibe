import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_switch.dart';

Future<void> editPortfolioExchangeRate(
  BuildContext context,
  AccountProvider provider,
  Account acc,
) async {
  if (acc.currency != 'USD') return;

  final controller = TextEditingController(
    text: acc.exchangeRate.toStringAsFixed(2),
  );
  final isDarkMode = context.read<SettingsProvider>().isDarkMode;
  final dialogBgColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
  final textColor = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      var autoUpdate = acc.autoUpdateRate;
      return StatefulBuilder(
        // design-check: allow input or multi-choice dialog
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: dialogBgColor,
          title: Text('อัตราแลกเปลี่ยน', style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: !autoUpdate,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'USD/THB',
                  suffixText: 'บาท',
                  labelStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Auto-update จาก API',
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                  ),
                  AppSwitch(
                    value: autoUpdate,
                    onChanged: (v) => setDialogState(() => autoUpdate = v),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('ยกเลิก', style: TextStyle(color: textColor)),
            ),
            TextButton(
              onPressed: () {
                final v = double.tryParse(controller.text.trim());
                if (v != null && v > 0) {
                  provider.updateAccountExchangeRate(
                    acc.id,
                    exchangeRate: v,
                    autoUpdateRate: autoUpdate,
                  );
                }
                Navigator.pop(ctx);
              },
              child: Text('บันทึก', style: TextStyle(color: textColor)),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> editPortfolioCashBalance(
  BuildContext context,
  AccountProvider provider,
  Account acc,
) async {
  final controller = TextEditingController(
    text: acc.cashBalance.toStringAsFixed(2),
  );
  final isDarkMode = context.read<SettingsProvider>().isDarkMode;
  final dialogBgColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
  final textColor = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      var autoUpdate = acc.autoUpdateRate;
      return StatefulBuilder(
        // design-check: allow input or multi-choice dialog
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: dialogBgColor,
          title: Text('ยอดเงินสด', style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: !autoUpdate,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'ยอดเงินสด (${acc.currencyCodeLabel})',
                  suffixText: acc.currencyAmountSuffix,
                  labelStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('ยกเลิก', style: TextStyle(color: textColor)),
            ),
            TextButton(
              onPressed: () {
                final v = double.tryParse(controller.text.trim());
                if (v != null) {
                  provider.updateAccountCashBalance(acc.id, v);
                }
                Navigator.pop(ctx);
              },
              child: Text('บันทึก', style: TextStyle(color: textColor)),
            ),
          ],
        ),
      );
    },
  );
}

void showPortfolioGroupReorderDialog(
  BuildContext context,
  List<String> currentGroups,
  bool isDarkMode, {
  required ValueChanged<List<String>> onSave,
}) {
  final dialogGroups = List<String>.from(currentGroups);
  final bgColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
  final textColor = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          // design-check: allow input or multi-choice dialog
          return AlertDialog(
            backgroundColor: bgColor,
            title: Text(
              'จัดลำดับกลุ่มพอร์ต',
              style: TextStyle(color: textColor, fontSize: 18),
            ),
            contentPadding: const EdgeInsets.only(top: 16, bottom: 8),
            content: Column(
              children: [
                Divider(height: 1, color: dividerColor),
                SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: dialogGroups.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setStateDialog(() {
                        final item = dialogGroups.removeAt(oldIndex);
                        dialogGroups.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final g = dialogGroups[index];
                      return ListTile(
                        key: ValueKey(g),
                        title: Text(g, style: TextStyle(color: textColor)),
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: Icon(Icons.drag_handle, color: dividerColor),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('ยกเลิก', style: TextStyle(color: textColor)),
              ),
              TextButton(
                onPressed: () {
                  onSave(dialogGroups);
                  Navigator.pop(ctx);
                },
                child: Text(
                  'บันทึก',
                  style: TextStyle(
                    color: isDarkMode ? AppColors.darkIncome : AppColors.income,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
