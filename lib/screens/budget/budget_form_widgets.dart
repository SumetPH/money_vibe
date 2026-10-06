import 'package:flutter/material.dart';
import '../../models/budget.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_switch.dart';

Widget buildBudgetInputFieldRow({
  required IconData icon,
  required String label,
  required String hintText,
  required TextEditingController controller,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
  required ValueChanged<String> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: textSecondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Icon(icon, color: textSecondaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
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
            onChanged: onChanged,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: textSecondaryColor.withValues(alpha: 0.55),
                fontSize: 14,
              ),
              hintTextDirection: TextDirection.rtl,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
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

Widget buildBudgetPickerRow({
  required IconData icon,
  required String label,
  required String value,
  required VoidCallback onTap,
  required Color surfaceColor,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.medium),
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
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: textSecondaryColor.withValues(alpha: 0.5),
          ),
        ],
      ),
    ),
  );
}

Widget buildBudgetSwitchRow({
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required bool isDark,
  required Color textColor,
  required Color textSecondary,
  required ValueChanged<bool> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: textSecondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Icon(icon, color: textSecondary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
        ),
        AppSwitch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

Widget buildBudgetLivePreviewCard({
  required String name,
  required String group,
  required String amountText,
  required BudgetType selectedType,
  required Color selectedColor,
  required IconData selectedIcon,
  required Color surfaceColor,
  required Color dividerColor,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
  required bool isDark,
}) {
  final displayName = name.isEmpty ? 'ตัวอย่างชื่องบประมาณ' : name;
  final isExpense = selectedType == BudgetType.expense;
  final typeBadgeColor = isExpense
      ? (isDark ? AppColors.darkExpense : AppColors.expense)
      : (isDark ? AppColors.darkIncome : AppColors.income);

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(AppRadii.xLarge),
      border: Border.all(color: dividerColor.withValues(alpha: 0.4), width: 1),
    ),
    child: Row(
      children: [
        // Icon Box
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selectedColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Icon(selectedIcon, color: selectedColor, size: 26),
        ),
        const SizedBox(width: 14),

        // Name and Group
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: name.isEmpty
                      ? textSecondaryColor.withValues(alpha: 0.6)
                      : textPrimaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                group.isNotEmpty ? 'กลุ่ม: $group' : 'ไม่มีกลุ่ม',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ),
        ),

        // Amount & Type Capsule
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: typeBadgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              child: Text(
                isExpense ? 'รายจ่าย' : 'เงินออม',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: typeBadgeColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amountText.isNotEmpty ? '฿$amountText' : '฿0.00',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPrimaryColor,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget buildBudgetDeleteRow({
  required VoidCallback onDelete,
  required bool isDarkMode,
  required Color surfaceColor,
}) {
  final deleteColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

  return InkWell(
    onTap: onDelete,
    borderRadius: BorderRadius.circular(AppRadii.xLarge),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline_rounded, color: deleteColor, size: 18),
          const SizedBox(width: 12),
          Text(
            'ลบงบประมาณนี้',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: deleteColor,
            ),
          ),
        ],
      ),
    ),
  );
}
