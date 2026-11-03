import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../utils/currency_utils.dart';
import '../../utils/exchange_rate_utils.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/calculator_text_field_config.dart';

/// ช่องยอดอีกสกุล + rate ใต้ยอดหลักใน amount hero card
/// ใช้ร่วมกันระหว่างรายการแลกเงินและรายจ่าย/รายรับสกุลต่างประเทศ
class TransactionConversionFields extends StatelessWidget {
  final String label;
  final String currency;
  final TextEditingController amountController;
  final FocusNode amountFocusNode;
  final TextEditingController rateController;
  final FocusNode rateFocusNode;
  final ExchangeQuote quote;
  final Color accentColor;
  final bool isDarkMode;
  final VoidCallback? onTapCurrency;

  const TransactionConversionFields({
    super.key,
    required this.label,
    required this.currency,
    required this.amountController,
    required this.amountFocusNode,
    required this.rateController,
    required this.rateFocusNode,
    required this.quote,
    required this.accentColor,
    required this.isDarkMode,
    this.onTapCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryFor(isDarkMode);
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final quoteUnit = CurrencyUtils.isBase(quote.quoteCurrency)
        ? CurrencyUtils.getCurrencySymbol(quote.quoteCurrency)
        : quote.quoteCurrency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: AppCardDivider(),
        ),
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_downward_rounded,
                size: 14,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _CurrencyBadge(
              currency: currency,
              isDarkMode: isDarkMode,
              onTap: onTapCurrency,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '${CurrencyUtils.getCurrencySymbol(currency)} ',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
            Expanded(
              child: _calculatorField(
                controller: amountController,
                focusNode: amountFocusNode,
                fontSize: 30,
                textColor: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.insetFillFor(isDarkMode),
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
          child: Row(
            children: [
              Icon(
                Icons.currency_exchange_rounded,
                size: 16,
                color: textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                '1 ${quote.baseCurrency} =',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _calculatorField(
                  controller: rateController,
                  focusNode: rateFocusNode,
                  fontSize: 15,
                  textColor: textPrimary,
                ),
              ),
              Text(
                quoteUnit,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _calculatorField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required double fontSize,
    required Color textColor,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: calculatorTextFieldReadOnly,
      showCursor: true,
      keyboardType: calculatorTextInputType,
      inputFormatters: calculatorTextInputFormatters,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: fontSize > 20 ? -0.5 : 0,
      ),
      decoration: InputDecoration(
        hintText: fontSize > 20 ? '0.00' : 'อัตรา',
        hintStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: isDarkMode ? AppColors.darkDivider : AppColors.divider,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  final String currency;
  final bool isDarkMode;
  final VoidCallback? onTap;

  const _CurrencyBadge({
    required this.currency,
    required this.isDarkMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    return Material(
      color: isDarkMode
          ? AppColors.darkSurfaceVariant
          : AppColors.sectionHeader,
      borderRadius: BorderRadius.circular(AppRadii.small),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currency,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onTap != null)
                Icon(Icons.arrow_drop_down, size: 16, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// สวิตช์ "ชำระเป็นสกุลต่างประเทศ" ของรายรับ/รายจ่าย
class TransactionForeignToggleRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDarkMode;

  const TransactionForeignToggleRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    return Row(
      children: [
        Icon(Icons.public_rounded, size: 16, color: textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'ชำระเป็นสกุลต่างประเทศ',
            style: TextStyle(
              color: textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        AppSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}
