import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import 'calculator_text_field_config.dart';

/// การ์ดกรอกจำนวนเงินหลักของฟอร์ม: สัญลักษณ์สกุลเงินใช้สีตามประเภทรายการ
class AppAmountHeroCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accentColor;
  final String currencyCode;
  final String label;

  const AppAmountHeroCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.accentColor,
    this.currencyCode = 'THB',
    this.label = 'จำนวนเงิน',
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);

    return Material(
      color: AppColors.surfaceFor(isDarkMode),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        side: BorderSide(color: AppColors.borderFor(isDarkMode), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => focusNode.requestFocus(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.selectedSegmentFor(isDarkMode),
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Text(
                      currencyCode,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    currencyCode == 'USD' ? '\$ ' : '฿ ',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  Expanded(child: _field(isDarkMode)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(bool isDarkMode) => TextField(
    controller: controller,
    focusNode: focusNode,
    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    readOnly: calculatorTextFieldReadOnly,
    showCursor: true,
    keyboardType: calculatorTextInputType,
    inputFormatters: calculatorTextInputFormatters,
    style: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryFor(isDarkMode),
      letterSpacing: -0.5,
    ),
    decoration: InputDecoration(
      hintText: '0.00',
      hintStyle: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: AppColors.switchInactiveFor(isDarkMode),
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    ),
  );
}
