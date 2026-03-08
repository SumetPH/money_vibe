import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';
import '../../widgets/app_drawer.dart';
import 'recurring_form_screen.dart';
import 'recurring_detail_screen.dart';

class RecurringListScreen extends StatefulWidget {
  const RecurringListScreen({super.key});

  @override
  State<RecurringListScreen> createState() => _RecurringListScreenState();
}

class _RecurringListScreenState extends State<RecurringListScreen> {
  bool _isReorderMode = false;

  static const _thaiMonths = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  String _formatDate(DateTime d) =>
      '${d.day} ${_thaiMonths[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    return Consumer2<RecurringTransactionProvider, SettingsProvider>(
      builder: (context, provider, sp, _) {
        final isDark = sp.isDarkMode;
        final bgColor = isDark
            ? AppColors.darkBackground
            : AppColors.background;
        final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
        final textPrimary = isDark
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondary = isDark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;

        final list = provider.recurring;

        return Scaffold(
          backgroundColor: bgColor,
          drawer: const AppDrawer(currentRoute: '/recurring'),
          appBar: AppBar(
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: const Text('รายการประจำ'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () =>
                    _showMenuBottomSheet(context, isDark, provider),
              ),
            ],
          ),
          body: SafeArea(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.repeat,
                          size: 64,
                          color: textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ยังไม่มีรายการประจำ',
                          style: TextStyle(color: textSecondary, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _openForm(context, null),
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่มรายการประจำ'),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: _isReorderMode,
                    onReorder: _isReorderMode
                        ? (oldIndex, newIndex) =>
                              provider.reorderRecurring(oldIndex, newIndex)
                        : (oldIdx, newIdx) {},
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final animValue = Curves.easeInOut.transform(
                            animation.value,
                          );
                          final elevation = 1 + animValue * 8;
                          final scale = 1 + animValue * 0.02;
                          return Transform.scale(
                            scale: scale,
                            child: Material(
                              elevation: elevation,
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final r = list[i];
                      final next = r.nextOccurrence;
                      final typeColor = _typeColor(r.transactionType, isDark);

                      // Get occurrence status for current month only
                      final now = DateTime.now();
                      final firstDayOfMonth = DateTime(now.year, now.month, 1);
                      final lastDayOfMonth = DateTime(
                        now.year,
                        now.month + 1,
                        0,
                      );

                      // Generate dates for current month
                      final monthDates = r
                          .generateOccurrenceDates(upTo: lastDayOfMonth)
                          .where(
                            (d) =>
                                !d.isBefore(firstDayOfMonth) &&
                                !d.isAfter(lastDayOfMonth),
                          )
                          .toList();

                      // Determine current month status
                      String? statusLabel;
                      Color? statusColor;

                      if (monthDates.isNotEmpty) {
                        final occ = provider.findOccurrence(
                          r.id,
                          monthDates.first,
                        );
                        final status = occ?.status ?? OccurrenceStatus.pending;
                        switch (status) {
                          case OccurrenceStatus.done:
                            statusLabel = 'เสร็จแล้ว';
                            statusColor = isDark
                                ? AppColors.darkIncome
                                : AppColors.income;
                          case OccurrenceStatus.pending:
                            statusLabel = 'รอดำเนินการ';
                            statusColor = Colors.grey;
                          case OccurrenceStatus.skipped:
                            statusLabel = 'ข้ามแล้ว';
                            statusColor = Colors.orange;
                        }
                      }

                      return Column(
                        key: ValueKey(r.id),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: _isReorderMode
                                ? null
                                : () => _openDetail(context, r),
                            onLongPress: _isReorderMode
                                ? null
                                : () => _openForm(context, r),
                            child: Container(
                              color: surfaceColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  if (_isReorderMode) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(
                                        Icons.drag_indicator,
                                        color: dividerColor,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                  // Icon
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: r.color.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      r.icon,
                                      color: r.color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            _TypeBadge(
                                              label: r.transactionType.label,
                                              color: typeColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'ทุกวันที่ ${r.dayOfMonth == 0 ? 'สิ้นเดือน' : r.dayOfMonth}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (next != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'ครั้งถัดไป: ${_formatDate(next)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                        // Status row (current month only)
                                        if (statusLabel != null &&
                                            statusColor != null) ...[
                                          const SizedBox(height: 4),
                                          _StatusChip(
                                            label: statusLabel,
                                            color: statusColor,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Amount + chevron
                                  if (!_isReorderMode)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          formatAmount(r.amount),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: typeColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Icon(
                                          Icons.chevron_right,
                                          color: textSecondary,
                                          size: 18,
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      formatAmount(r.amount),
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
                          Divider(height: 1, color: dividerColor),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  void _showMenuBottomSheet(
    BuildContext context,
    bool isDark,
    RecurringTransactionProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, sp, _) {
          final isDk = sp.isDarkMode;
          final bgColor = isDk ? AppColors.darkSurface : Colors.white;
          final handleColor = isDk
              ? AppColors.darkDivider
              : Colors.grey.shade300;
          final textColor = isDk
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final dividerColor = isDk ? AppColors.darkDivider : AppColors.divider;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  tileColor: bgColor,
                  leading: Icon(Icons.add, color: textColor),
                  title: Text(
                    'เพิ่มรายการประจำ',
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openForm(context, null);
                  },
                ),
                Divider(height: 1, color: dividerColor),
                ListTile(
                  tileColor: bgColor,
                  leading: Icon(Icons.reorder, color: textColor),
                  title: Text(
                    'จัดเรียงลำดับ',
                    style: TextStyle(color: textColor),
                  ),
                  trailing: Switch(
                    value: _isReorderMode,
                    onChanged: (v) {
                      setState(() => _isReorderMode = v);
                      Navigator.pop(context);
                    },
                  ),
                  onTap: () {
                    setState(() => _isReorderMode = !_isReorderMode);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _typeColor(TransactionType type, bool isDark) {
    switch (type) {
      case TransactionType.income:
        return isDark ? AppColors.darkIncome : AppColors.income;
      case TransactionType.expense:
        return isDark ? AppColors.darkExpense : AppColors.expense;
      case TransactionType.transfer:
      case TransactionType.debtRepay:
        return isDark ? AppColors.darkTransfer : AppColors.transfer;
      case TransactionType.debtTransfer:
        return isDark ? AppColors.darkDebtTransfer : AppColors.debtTransfer;
    }
  }

  void _openForm(BuildContext context, RecurringTransaction? r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecurringFormScreen(recurring: r)),
    );
  }

  void _openDetail(BuildContext context, RecurringTransaction r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecurringDetailScreen(recurring: r)),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
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

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
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
