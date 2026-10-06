import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_amount_hero_card.dart';
import '../../widgets/app_form_row.dart';
import '../../widgets/app_segmented_tabs.dart';
import '../../widgets/app_switch.dart';

// ── Reusable widgets ──────────────────────────────────────────────────────────

class RecurringTypeSegmentedControl extends StatelessWidget {
  final TransactionType selectedType;
  final ValueChanged<TransactionType> onChanged;
  final VoidCallback onShowMore;

  const RecurringTypeSegmentedControl({
    super.key,
    required this.selectedType,
    required this.onChanged,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary =
        selectedType == TransactionType.expense ||
        selectedType == TransactionType.income ||
        selectedType == TransactionType.transfer;
    final otherLabel = switch (selectedType) {
      TransactionType.debtRepay => 'ชำระหนี้ ▾',
      TransactionType.debtTransfer => 'โอนหนี้ ▾',
      TransactionType.increaseBalance => 'ปรับเพิ่ม ▾',
      TransactionType.decreaseBalance => 'ปรับลด ▾',
      _ => 'อื่นๆ ▾',
    };

    AppSegment tab(String label, TransactionType type) => AppSegment(
      label: label,
      isSelected: selectedType == type,
      onTap: () => onChanged(type),
    );

    return AppSegmentedTabs(
      segments: [
        tab('รายจ่าย', TransactionType.expense),
        tab('รายรับ', TransactionType.income),
        tab('โอน', TransactionType.transfer),
        AppSegment(
          label: otherLabel,
          isSelected: !isPrimary,
          onTap: onShowMore,
        ),
      ],
    );
  }
}

class RecurringAmountHeroCard extends StatelessWidget {
  final TransactionType type;
  final TextEditingController amountController;
  final FocusNode amountFocusNode;
  final Account? selectedAccount;
  final bool isDarkMode;

  const RecurringAmountHeroCard({
    super.key,
    required this.type,
    required this.amountController,
    required this.amountFocusNode,
    required this.selectedAccount,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (type) {
      TransactionType.income || TransactionType.increaseBalance =>
        isDarkMode ? AppColors.darkIncome : AppColors.income,
      TransactionType.expense || TransactionType.decreaseBalance =>
        isDarkMode ? AppColors.darkExpense : AppColors.expense,
      TransactionType.transfer || TransactionType.debtRepay =>
        isDarkMode ? AppColors.darkTransfer : AppColors.transfer,
      TransactionType.debtTransfer =>
        isDarkMode ? AppColors.darkDebtTransfer : AppColors.debtTransfer,
    };

    return AppAmountHeroCard(
      controller: amountController,
      focusNode: amountFocusNode,
      accentColor: typeColor,
      currencyCode: selectedAccount?.currency == 'USD' ? 'USD' : 'THB',
    );
  }
}

class RecurringToggleRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget title;
  final Widget subtitle;
  final Color color;

  const RecurringToggleRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 2), subtitle],
            ),
          ),
          const SizedBox(width: 12),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class RecurringRowTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const RecurringRowTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (label) {
      'บัญชี' => Icons.account_balance_wallet_outlined,
      'บัญชีปลายทาง' => Icons.input_rounded,
      'บัญชีหนี้สิน' => Icons.credit_card_rounded,
      'หมวดหมู่' => Icons.category_outlined,
      'วันที่ในเดือน' => Icons.calendar_today_rounded,
      'เวลาแจ้งเตือน' => Icons.notifications_outlined,
      _ => Icons.tune_rounded,
    };

    return AppFormRow(icon: icon, label: label, value: value, onTap: onTap);
  }
}

/// แถวเลือกเดือนเริ่มต้น/สิ้นสุดของรายการประจำ
class RecurringMonthRangeRows extends StatelessWidget {
  final String startLabel;
  final String? endLabel;
  final Color surfaceColor;
  final Color dividerColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onClearEnd;

  const RecurringMonthRangeRows({
    super.key,
    required this.startLabel,
    required this.endLabel,
    required this.surfaceColor,
    required this.dividerColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClearEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onPickStart,
          child: Container(
            color: surfaceColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  'เดือนเริ่มต้น',
                  style: TextStyle(fontSize: 16, color: textSecondary),
                ),
                const Spacer(),
                Text(
                  startLabel,
                  style: TextStyle(fontSize: 15, color: textPrimary),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: textSecondary, size: 18),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: dividerColor),

        // ── Month end (optional) ───────────────────────────────────────
        InkWell(
          onTap: onPickEnd,
          child: Container(
            color: surfaceColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  'เดือนสิ้นสุด',
                  style: TextStyle(fontSize: 16, color: textSecondary),
                ),
                const Spacer(),
                if (endLabel != null) ...[
                  Text(
                    endLabel!,
                    style: TextStyle(fontSize: 15, color: textPrimary),
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: Colors.transparent,
                    child: InkResponse(
                      onTap: onClearEnd,
                      radius: 16,
                      child: Icon(Icons.close, size: 16, color: textSecondary),
                    ),
                  ),
                ] else
                  Text(
                    'ไม่ได้เลือก',
                    style: TextStyle(
                      fontSize: 15,
                      color: textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: textSecondary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RecurringDeleteButton extends StatelessWidget {
  final bool isDark;
  final Color surfaceColor;
  final VoidCallback onDelete;

  const RecurringDeleteButton({
    super.key,
    required this.isDark,
    required this.surfaceColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(color: AppColors.borderFor(isDark), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDelete,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: isDark ? AppColors.darkExpense : AppColors.expense,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'ลบรายการประจำนี้',
                style: TextStyle(
                  color: isDark ? AppColors.darkExpense : AppColors.expense,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
