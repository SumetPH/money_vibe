import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/investment_plan.dart';
import '../../models/stock_holding.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/app_switch.dart';

Future<void> showInvestmentPlanStockSelectionSheet(
  BuildContext context, {
  required List<StockHolding> holdings,
  required bool isDarkMode,
  required PortfolioAllocationTarget? Function(StockHolding holding) targetFor,
  required Future<bool> Function(StockHolding holding, {required bool enabled})
  saveTarget,
  required bool Function() isMounted,
}) async {
  final localEnabled = {
    for (final holding in holdings)
      holding.id: targetFor(holding)?.isEnabled ?? false,
  };
  final textColor = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final secondaryColor = isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;
  final accentColor = isDarkMode ? AppColors.darkIncome : AppColors.income;

  await showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final selectedCount = localEnabled.values
              .where((enabled) => enabled)
              .length;

          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'เลือกหุ้นในแผน',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'เปิดอยู่ $selectedCount จาก ${holdings.length} ตัว',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(sheetContext),
                          borderRadius: BorderRadius.circular(AppRadii.full),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AppCardDivider(),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: holdings.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: AppColors.listDividerFor(isDarkMode),
                      ),
                      itemBuilder: (context, index) {
                        final holding = holdings[index];
                        final enabled = localEnabled[holding.id] ?? false;
                        final target = targetFor(holding);

                        Future<void> toggle(bool value) async {
                          setSheetState(() {
                            localEnabled[holding.id] = value;
                          });
                          final saved = await saveTarget(
                            holding,
                            enabled: value,
                          );
                          if (!saved && isMounted()) {
                            setSheetState(() {
                              localEnabled[holding.id] = !value;
                            });
                          }
                        }

                        return InkWell(
                          onTap: () => toggle(!enabled),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: enabled
                                        ? accentColor.withValues(alpha: 0.12)
                                        : (isDarkMode
                                              ? Colors.white.withValues(
                                                  alpha: 0.05,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.04,
                                                )),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.medium,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    holding.ticker.isNotEmpty
                                        ? holding.ticker[0].toUpperCase()
                                        : 'S',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: enabled ? accentColor : textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        holding.ticker,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        target != null
                                            ? 'เป้า ${target.targetPercent.toStringAsFixed(2)}%'
                                            : 'ยังไม่ได้ตั้งเป้า',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: secondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AppSwitch(value: enabled, onChanged: toggle),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
