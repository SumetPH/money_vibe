import '../../models/account.dart';
import '../../theme/app_colors.dart';
import '../../widgets/calculator_text_field_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_switch.dart';

Widget buildAccountTextFieldRow({
  required TextEditingController controller,
  required String label,
  required String hintText,
  required IconData icon,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: textSecondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: textSecondaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: textSecondaryColor.withValues(alpha: 0.5),
                fontSize: 15,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
              filled: false,
            ),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildAccountPickerRow({
  required String label,
  required String value,
  required IconData icon,
  required VoidCallback onTap,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: textSecondaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right,
            color: textSecondaryColor.withValues(alpha: 0.5),
            size: 18,
          ),
        ],
      ),
    ),
  );
}

Widget buildAccountReadOnlyRow({
  required String label,
  required String value,
  required IconData icon,
  String? badge,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: textSecondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: textSecondaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textPrimaryColor,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textSecondaryColor,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: textSecondaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadii.full),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textSecondaryColor,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget buildAccountSwitchRow({
  required String label,
  String? subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textPrimaryColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ],
          ),
        ),
        AppSwitch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

Widget buildAccountDayPickerRow({
  required IconData icon,
  required String label,
  required String value,
  required VoidCallback onTap,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: textSecondaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right,
            color: textSecondaryColor.withValues(alpha: 0.5),
            size: 18,
          ),
        ],
      ),
    ),
  );
}

Widget buildAccountExchangeRateField({
  required TextEditingController exchangeRateController,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: textSecondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.currency_exchange_rounded,
            color: textSecondaryColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'USD / THB',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textPrimaryColor,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 100,
          child: TextField(
            controller: exchangeRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: '1.0',
              hintStyle: TextStyle(
                color: textSecondaryColor.withValues(alpha: 0.5),
                fontSize: 15,
              ),
              suffixText: ' บาท',
              suffixStyle: TextStyle(color: textSecondaryColor, fontSize: 14),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
              filled: false,
            ),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildAccountHeroBalanceCard({
  required AccountType selectedType,
  required String effectiveSelectedCurrency,
  required TextEditingController initialBalanceController,
  required FocusNode amountFocusNode,
  required bool isDarkMode,
  required Color surfaceColor,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
  required Color dividerColor,
}) {
  final isPortfolio = selectedType.isPortfolio;
  final isDebt = selectedType == AccountType.debt;
  final currencyText = effectiveSelectedCurrency == 'USD' ? 'USD' : 'THB';

  return Container(
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(AppRadii.xLarge),
      border: Border.all(color: dividerColor.withValues(alpha: 0.4), width: 1),
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isPortfolio ? 'เงินสดใน Broker' : 'ยอดเงินเริ่มต้น',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textSecondaryColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              child: Text(
                currencyText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textPrimaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: initialBalanceController,
          focusNode: amountFocusNode,
          readOnly: calculatorTextFieldReadOnly,
          showCursor: true,
          keyboardType: calculatorTextInputType,
          inputFormatters: calculatorTextInputFormatters,
          textAlign: TextAlign.left,
          decoration: InputDecoration(
            hintText: '0.00',
            hintStyle: TextStyle(
              color: textSecondaryColor.withValues(alpha: 0.5),
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
            filled: false,
          ),
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: isDebt
                ? (isDarkMode ? AppColors.darkExpense : AppColors.expense)
                : textPrimaryColor,
          ),
        ),
        if (isDebt) ...[
          const SizedBox(height: 8),
          Text(
            'ระบบจะบันทึกยอดหนี้สินเป็นยอดติดลบในทรัพย์สินสุทธิโดยอัตโนมัติ',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? AppColors.darkExpense : AppColors.expense,
            ),
          ),
        ],
      ],
    ),
  );
}

Widget buildAccountDeleteCard({
  required bool isLoading,
  required VoidCallback onDelete,
  required Color surfaceColor,
  required Color expenseColor,
  required Color dividerColor,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isLoading ? null : onDelete,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xLarge),
            border: Border.all(
              color: expenseColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline_rounded, color: expenseColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'ลบบัญชีนี้',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: expenseColor,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String accountIconMimeTypeForExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    default:
      return 'image/png';
  }
}
