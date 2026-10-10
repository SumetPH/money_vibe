import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_reorder_mode.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_drawer_button.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import 'recurring_form_screen.dart';
import 'recurring_section.dart';
import '../../widgets/app_switch.dart';
import 'recurring_list_item.dart';

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
    return Consumer3<
      RecurringTransactionProvider,
      SettingsProvider,
      TransactionProvider
    >(
      builder: (context, provider, sp, transactionProvider, _) {
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
        final grouped = <TransactionType, List<RecurringTransaction>>{};
        for (final item in list) {
          (grouped[item.transactionType] ??= []).add(item);
        }
        final transactionsById = {
          for (final transaction in transactionProvider.transactions)
            transaction.id: transaction,
        };

        final isLargeScreen = MediaQuery.of(context).size.width >= 800;

        return Scaffold(
          backgroundColor: bgColor,
          drawer: isLargeScreen
              ? null
              : const AppDrawer(currentRoute: '/recurring'),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 100,
            backgroundColor: bgColor,
            foregroundColor: textPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleSpacing: isLargeScreen ? 24 : 16,
            leading: isLargeScreen ? null : const AppDrawerButton(),
            leadingWidth: 64,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'การวางแผนการเงิน',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'รายการประจำ',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: [
              if (_isReorderMode)
                AppReorderDoneButton(
                  onPressed: () => setState(() => _isReorderMode = false),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: surfaceColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      side: BorderSide(
                        color: AppColors.borderFor(isDark),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        size: 20,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                      onPressed: () => _showMenuBottomSheet(context, isDark),
                    ),
                  ),
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
                    buildDefaultDragHandles: false,
                    header: _isReorderMode
                        ? const AppReorderBanner(
                            message:
                                'แตะค้างที่ไอคอนลากเพื่อจัดเรียงลำดับรายการประจำ',
                          )
                        : null,
                    onReorderItem: _isReorderMode
                        ? provider.reorderRecurringGroups
                        : (_, _) {},
                    itemCount: grouped.length,
                    itemBuilder: (_, groupIndex) {
                      final entry = grouped.entries.elementAt(groupIndex);
                      return Column(
                        key: ValueKey('recurring_group_${entry.key.name}'),
                        children: [
                          RecurringSection(
                            title: entry.key.label,
                            trailing: _isReorderMode
                                ? [
                                    ReorderableDragStartListener(
                                      index: groupIndex,
                                      child: Icon(
                                        Icons.drag_indicator,
                                        color: dividerColor,
                                        size: 20,
                                      ),
                                    ),
                                  ]
                                : const [],
                            child: ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              onReorderItem: _isReorderMode
                                  ? (oldIndex, newIndex) =>
                                        provider.reorderRecurring(
                                          entry.key,
                                          oldIndex,
                                          newIndex,
                                        )
                                  : (_, _) {},
                              itemCount: entry.value.length,
                              itemBuilder: (_, index) => _buildRecurringItem(
                                context: context,
                                provider: provider,
                                recurring: entry.value[index],
                                transactionsById: transactionsById,
                                index: index,
                                isDark: isDark,
                                surfaceColor: surfaceColor,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                dividerColor: dividerColor,
                                showDivider: index != entry.value.length - 1,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildRecurringItem({
    required BuildContext context,
    required RecurringTransactionProvider provider,
    required RecurringTransaction recurring,
    required Map<String, AppTransaction> transactionsById,
    required int index,
    required bool isDark,
    required Color surfaceColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color dividerColor,
    required bool showDivider,
  }) {
    var next = recurring.nextOccurrence;
    final typeColor = _typeColor(recurring.transactionType, isDark);
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final monthDates = recurring
        .generateOccurrenceDates(upTo: lastDayOfMonth)
        .where(
          (date) =>
              !date.isBefore(firstDayOfMonth) && !date.isAfter(lastDayOfMonth),
        )
        .toList();

    String? statusLabel;
    Color? statusColor;
    var displayAmount = recurring.amount;

    if (monthDates.isNotEmpty) {
      final currentMonthDate = monthDates.first;
      final occurrence = provider.findOccurrence(
        recurring.id,
        currentMonthDate,
      );
      final linkedTransaction = occurrence?.transactionId != null
          ? transactionsById[occurrence!.transactionId]
          : null;
      displayAmount = linkedTransaction?.amount ?? recurring.amount;
      final status = occurrence?.status ?? OccurrenceStatus.pending;
      next = status == OccurrenceStatus.pending ? currentMonthDate : null;
      switch (status) {
        case OccurrenceStatus.done:
          statusLabel = 'เสร็จแล้ว';
          statusColor = isDark ? AppColors.darkIncome : AppColors.income;
        case OccurrenceStatus.pending:
          statusLabel = 'รอดำเนินการ';
          statusColor = Colors.blueGrey;
        case OccurrenceStatus.skipped:
          statusLabel = 'ข้ามแล้ว';
          statusColor = Colors.orange;
      }
    }

    return Opacity(
      key: ValueKey(recurring.id),
      opacity: recurring.isHidden ? 0.45 : 1.0,
      child: RecurringListItem(
        recurring: recurring,
        displayAmount: displayAmount,
        nextOccurrence: next,
        statusLabel: statusLabel,
        statusColor: statusColor,
        typeColor: typeColor,
        isReorderMode: _isReorderMode,
        reorderIndex: _isReorderMode ? index : null,
        isDarkMode: isDark,
        surfaceColor: surfaceColor,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        dividerColor: dividerColor,
        formatDate: _formatDate,
        onTap: () => _openDetail(context, recurring),
        onTapEdit: () => _openForm(context, recurring),
        showDivider: showDivider,
      ),
    );
  }

  void _showMenuBottomSheet(
    BuildContext context,
    bool isDark,
    // RecurringTransactionProvider provider,
  ) {
    showAppModalBottomSheet(
      context: context,
      builder: (_) => Consumer2<SettingsProvider, RecurringTransactionProvider>(
        builder: (context, sp, rtp, _) {
          final isDk = sp.isDarkMode;
          final textColor = isDk
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final textSecondary = isDk
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          final dividerColor = isDk ? AppColors.darkDivider : AppColors.divider;
          final incomeColor = isDk ? AppColors.darkIncome : AppColors.income;
          final yellowColor = isDk
              ? AppColors.darkFabYellow
              : AppColors.fabYellow;

          return StatefulBuilder(
            builder: (context, setStateModal) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppModalBottomSheetHeader(
                        title: 'ตัวเลือกรายการประจำ',
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: isDk
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
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: yellowColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  color: yellowColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'เพิ่มรายการประจำ',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'สร้างรายการรับ จ่าย หรือโอนเงินอัตโนมัติ',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _openForm(context, null);
                              },
                            ),
                            const AppCardDivider(),
                            ListTile(
                              leading: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: incomeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                ),
                                child: Icon(
                                  Icons.reorder_rounded,
                                  color: incomeColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'จัดเรียงลำดับ',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'เปิดโหมดลากสลับตำแหน่งรายการประจำ',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: AppSwitch(
                                value: _isReorderMode,
                                onChanged: (v) {
                                  setState(() => _isReorderMode = v);
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                            const AppCardDivider(),
                            ListTile(
                              leading: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: textColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                ),
                                child: Icon(
                                  Icons.visibility_outlined,
                                  color: textColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'แสดงรายการที่ซ่อน',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'แสดงรายการประจำที่ถูกตั้งค่าซ่อนไว้',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: AppSwitch(
                                value: rtp.showHiddenRecurring,
                                onChanged: (_) {
                                  rtp.toggleShowHiddenRecurring();
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
      case TransactionType.increaseBalance:
        return isDark ? AppColors.darkIncome : AppColors.income;
      case TransactionType.decreaseBalance:
        return isDark ? AppColors.darkExpense : AppColors.expense;
    }
  }

  void _openForm(BuildContext context, RecurringTransaction? r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecurringFormScreen(recurring: r)),
    );
  }

  void _openDetail(BuildContext context, RecurringTransaction r) {
    context.push('/recurring/${r.id}');
  }
}
