import 'package:flutter/material.dart';
import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';

// ── Occurrence list item ──────────────────────────────────────────────────────

class RecurringOccurrenceItem extends StatelessWidget {
  final DateTime date;
  final RecurringOccurrence? occurrence;
  final AppTransaction? linkedTransaction;
  final RecurringTransaction recurring;
  final bool isDark;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;
  final Color typeColor;
  final String Function(DateTime) formatDate;
  final VoidCallback onCreateTap;
  final VoidCallback onSkipTap;
  final VoidCallback onUndoTap;
  final VoidCallback? onEditTap;

  const RecurringOccurrenceItem({
    super.key,
    required this.date,
    required this.occurrence,
    required this.linkedTransaction,
    required this.recurring,
    required this.isDark,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
    required this.typeColor,
    required this.formatDate,
    required this.onCreateTap,
    required this.onSkipTap,
    required this.onUndoTap,
    this.onEditTap,
  });

  OccurrenceStatus get _status =>
      occurrence?.status ?? OccurrenceStatus.pending;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xLarge),
          side: BorderSide(color: dividerColor.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          color: surfaceColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status dot
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusDotColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date + status badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            formatDate(date),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        RecurringOccurrenceStatusBadge(
                          status: _status,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    // Linked transaction info + edit button
                    if (_status == OccurrenceStatus.done &&
                        linkedTransaction != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            formatAmount(linkedTransaction!.amount),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Actions
                    if (_status == OccurrenceStatus.pending) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          RecurringOccurrenceActionButton(
                            label: 'สร้างรายการ',
                            icon: Icons.add_circle_outline,
                            color: isDark
                                ? AppColors.darkIncome
                                : AppColors.income,
                            onTap: onCreateTap,
                          ),
                          const SizedBox(width: 8),
                          RecurringOccurrenceActionButton(
                            label: 'ข้าม',
                            icon: Icons.skip_next_outlined,
                            color: Colors.orange,
                            onTap: onSkipTap,
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (onEditTap != null)
                            RecurringOccurrenceActionButton(
                              label: 'แก้ไข',
                              icon: Icons.edit_outlined,
                              color: isDark
                                  ? AppColors.darkTransfer
                                  : AppColors.transfer,
                              onTap: onEditTap!,
                            ),
                          const SizedBox(width: 8),
                          RecurringOccurrenceActionButton(
                            label: 'ยกเลิก',
                            icon: Icons.cancel_outlined,
                            color: isDark
                                ? AppColors.darkExpense
                                : AppColors.expense,
                            onTap: onUndoTap,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _statusDotColor {
    switch (_status) {
      case OccurrenceStatus.pending:
        return Colors.grey.shade400;
      case OccurrenceStatus.done:
        return isDark ? AppColors.darkIncome : AppColors.income;
      case OccurrenceStatus.skipped:
        return Colors.orange;
    }
  }
}

class RecurringOccurrenceStatusBadge extends StatelessWidget {
  final OccurrenceStatus status;
  final bool isDark;

  const RecurringOccurrenceStatusBadge({
    super.key,
    required this.status,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OccurrenceStatus.pending => ('รอดำเนินการ', Colors.grey.shade500),
      OccurrenceStatus.done => (
        'เสร็จสิ้น',
        isDark ? AppColors.darkIncome : AppColors.income,
      ),
      OccurrenceStatus.skipped => ('ข้ามแล้ว', Colors.orange),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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

class RecurringOccurrenceActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const RecurringOccurrenceActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
