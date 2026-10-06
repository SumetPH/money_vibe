import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/budget.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/app_modal_bottom_sheet.dart';

// ── Budget Item Card (For flat list without groups) ──────────────────────────

class BudgetItemCard extends StatelessWidget {
  final Budget budget;
  final double spent;
  final bool isReorderMode;
  final int? reorderIndex;
  final bool isFirst;
  final bool isLast;
  final bool showDivider;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;
  final VoidCallback onTap;
  final VoidCallback onTapEdit;

  const BudgetItemCard({
    super.key,
    required this.budget,
    required this.spent,
    required this.isReorderMode,
    this.reorderIndex,
    required this.isFirst,
    required this.isLast,
    required this.showDivider,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
    required this.onTap,
    required this.onTapEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: BudgetItemRow(
        budget: budget,
        spent: spent,
        isReorderMode: isReorderMode,
        reorderIndex: reorderIndex,
        showDivider: false,
        isDarkMode: isDarkMode,
        surfaceColor: surfaceColor,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        dividerColor: dividerColor,
        onTap: onTap,
        onTapEdit: onTapEdit,
      ),
    );
  }
}

// ── Budget Item Row (Shared between grouped and flat lists) ───────────────────

class BudgetItemRow extends StatelessWidget {
  final Budget budget;
  final double spent;
  final bool isReorderMode;
  final int? reorderIndex;
  final bool showDivider;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;
  final VoidCallback onTap;
  final VoidCallback onTapEdit;

  const BudgetItemRow({
    super.key,
    required this.budget,
    required this.spent,
    required this.isReorderMode,
    this.reorderIndex,
    required this.showDivider,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
    required this.onTap,
    required this.onTapEdit,
  });

  double get _progress => budget.amount > 0 ? (spent / budget.amount) : 0.0;
  double get _remaining => budget.amount - spent;
  bool get _isRemainingNeutral => _remaining.abs() <= 0.001;

  Color get _progressColor {
    if (_progress >= 1.0) {
      return isDarkMode ? AppColors.darkExpense : AppColors.expense;
    }
    if (_progress >= 0.8) return Colors.orange;
    return isDarkMode ? AppColors.darkIncome : AppColors.income;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: isReorderMode || budget.type == BudgetType.savings
              ? null
              : onTap,
          onLongPress: isReorderMode ? null : () => _showBudgetMenu(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Reorder Handle if active
                if (reorderIndex != null) ...[
                  ReorderableDragStartListener(
                    index: reorderIndex!,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: dividerColor,
                        size: 20,
                      ),
                    ),
                  ),
                ],

                // Squircle Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: budget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.large),
                  ),
                  child: Icon(budget.icon, color: budget.color, size: 22),
                ),
                const SizedBox(width: 12),

                // Title & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              budget.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (budget.isHidden) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.small,
                                ),
                              ),
                              child: Text(
                                'ซ่อน',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        budget.type == BudgetType.savings
                            ? 'เป้าหมาย: ${formatAmount(budget.amount)}'
                            : 'งบ ${formatAmount(budget.amount)} · ใช้ ${formatAmount(spent)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Right side: Savings capsule OR Expense metrics
                if (budget.type == BudgetType.savings) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isDarkMode ? AppColors.darkIncome : AppColors.income)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                    child: Text(
                      'แผนออม',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode
                            ? AppColors.darkIncome
                            : AppColors.income,
                      ),
                    ),
                  ),
                ] else ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(_progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _progressColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 80,
                            child: BudgetProgressBar(
                              progress: _progress,
                              color: _progressColor,
                              backgroundColor: isDarkMode
                                  ? AppColors.darkDivider
                                  : AppColors.divider,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_remaining >= -0.001 ? 'เหลือ' : 'เกิน'} ${formatAmount(_remaining.abs())}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isRemainingNeutral
                              ? textPrimary
                              : _remaining > 0
                              ? (isDarkMode
                                    ? AppColors.darkIncome
                                    : AppColors.income)
                              : (isDarkMode
                                    ? AppColors.darkExpense
                                    : AppColors.expense),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: AppColors.listDividerFor(isDarkMode)),
      ],
    );
  }

  void _showBudgetMenu(BuildContext context) {
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
                  AppModalBottomSheetHeader(title: budget.name),
                  const SizedBox(height: 8),
                  Material(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.surface,
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
                        'แก้ไขงบประมาณ',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'เปลี่ยนยอด จำนวนเงิน หรือการตั้งค่าของงบประมาณ',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: textSecondary.withValues(alpha: 0.5),
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

class BudgetProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final Color backgroundColor;

  const BudgetProgressBar({
    super.key,
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress.isFinite ? progress : 0.0;
    final baseProgress = normalizedProgress.clamp(0.0, 1.0);
    final overflowProgress = (normalizedProgress - 1.0).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: backgroundColor),
            if (baseProgress > 0)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: baseProgress,
                child: ColoredBox(color: color),
              ),
            if (overflowProgress > 0)
              FractionallySizedBox(
                alignment: Alignment.centerRight,
                widthFactor: overflowProgress,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.25),
                        color.withValues(alpha: 0.7),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
