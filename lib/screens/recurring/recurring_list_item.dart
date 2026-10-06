import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/recurring_transaction.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/app_modal_bottom_sheet.dart';

class RecurringListItem extends StatelessWidget {
  final RecurringTransaction recurring;
  final double displayAmount;
  final DateTime? nextOccurrence;
  final String? statusLabel;
  final Color? statusColor;
  final Color typeColor;
  final bool isReorderMode;
  final int? reorderIndex;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;
  final VoidCallback onTapEdit;
  final bool showDivider;

  const RecurringListItem({
    super.key,
    required this.recurring,
    required this.displayAmount,
    required this.nextOccurrence,
    required this.statusLabel,
    required this.statusColor,
    required this.typeColor,
    required this.isReorderMode,
    this.reorderIndex,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
    required this.formatDate,
    required this.onTap,
    required this.onTapEdit,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: isReorderMode ? null : onTap,
          onLongPress: isReorderMode ? null : () => _showRecurringMenu(context),
          child: Container(
            color: surfaceColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (reorderIndex != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ReorderableDragStartListener(
                      index: reorderIndex!,
                      child: Icon(
                        Icons.drag_indicator,
                        color: dividerColor,
                        size: 20,
                      ),
                    ),
                  ),
                ],
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: recurring.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Icon(recurring.icon, color: recurring.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recurring.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          RecurringListTypeBadge(
                            label: recurring.transactionType.label,
                            color: typeColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ทุกวันที่ ${recurring.dayOfMonth == 0 ? 'สิ้นเดือน' : recurring.dayOfMonth}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (nextOccurrence != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'ครั้งถัดไป: ${formatDate(nextOccurrence!)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (!isReorderMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (statusLabel != null && statusColor != null) ...[
                            RecurringListStatusChip(
                              label: statusLabel!,
                              color: statusColor!,
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            formatAmount(displayAmount),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Text(
                    formatAmount(displayAmount),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: typeColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: AppColors.listDividerFor(isDarkMode)),
      ],
    );
  }

  void _showRecurringMenu(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDark = settingsProvider.isDarkMode;
          final textColor = isDark
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final textSecondary = isDark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          final dividerColor = isDark
              ? AppColors.darkDivider
              : AppColors.divider;
          final incomeColor = isDark ? AppColors.darkIncome : AppColors.income;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppModalBottomSheetHeader(title: recurring.name),
                  const SizedBox(height: 8),
                  Material(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.xLarge),
                      side: BorderSide(
                        color: dividerColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: incomeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: incomeColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'แก้ไขรายการประจำ',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'เปลี่ยนยอด วันที่ หรือเงื่อนไขของรายการ',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: textSecondary.withValues(alpha: 0.6),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        onTapEdit();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class RecurringListTypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const RecurringListTypeBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class RecurringListStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const RecurringListStatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
