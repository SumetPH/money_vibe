import '../../widgets/app_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../screens/transaction/transaction_form_screen.dart';
import 'recurring_form_screen.dart';
import 'recurring_section.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_segmented_tabs.dart';
import 'recurring_occurrence_item.dart';
import 'recurring_detail_widgets.dart';
import 'recurring_remaining_summary.dart';

class RecurringDetailScreen extends StatefulWidget {
  final RecurringTransaction recurring;

  const RecurringDetailScreen({super.key, required this.recurring});

  @override
  State<RecurringDetailScreen> createState() => _RecurringDetailScreenState();
}

class _RecurringDetailScreenState extends State<RecurringDetailScreen> {
  late RecurringTransaction _recurring;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _recurring = widget.recurring;
  }

  static const _thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];
  static const _thaiMonthsShort = [
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
  static const _thaiDays = [
    '',
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์',
  ];

  String _formatDateLong(DateTime d) =>
      '${d.day} ${_thaiMonths[d.month - 1]} ${d.year} (${_thaiDays[d.weekday]})';

  String _formatDateShort(DateTime d) =>
      '${d.day} ${_thaiMonthsShort[d.month - 1]} ${d.year}';

  String _formatMonthYear(DateTime d) =>
      '${_thaiMonths[d.month - 1]} ${d.year + 543}';

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  void _openForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecurringFormScreen(recurring: _recurring),
      ),
    ).then((_) {
      if (!mounted) return;
      // Refresh if recurring was updated (provider will notify)
      final provider = context.read<RecurringTransactionProvider>();
      final updated = provider.allRecurring.where((r) => r.id == _recurring.id);
      if (updated.isNotEmpty) {
        setState(() => _recurring = updated.first);
      }
    });
  }

  void _editTransaction(
    BuildContext context,
    AppTransaction tx,
    DateTime dueDate,
  ) {
    final txProvider = context.read<TransactionProvider>();
    final recurProvider = context.read<RecurringTransactionProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TransactionFormScreen(transaction: tx)),
    ).then((_) {
      if (!mounted) return;
      // If user deleted the transaction, undo the occurrence automatically
      final stillExists = txProvider.transactions.any((t) => t.id == tx.id);
      if (!stillExists) {
        recurProvider.undoOccurrence(_recurring.id, dueDate);
      }
    });
  }

  void _createTransaction(BuildContext context, DateTime dueDate, bool isDark) {
    final now = DateTime.now();
    final templateTx = AppTransaction(
      id: '', // will be replaced
      type: _recurring.transactionType,
      amount: _recurring.amount,
      accountId: _recurring.accountId,
      categoryId: _recurring.categoryId,
      toAccountId: _recurring.toAccountId,
      dateTime: now,
      note: _recurring.note,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          initialValues: templateTx,
          onSaved: (txId) {
            context.read<RecurringTransactionProvider>().markOccurrenceDone(
              _recurring.id,
              dueDate,
              txId,
            );
          },
        ),
      ),
    );
  }

  void _skipOccurrence(BuildContext context, DateTime dueDate, bool isDark) {
    showAppConfirmDialog(
      context: context,
      title: 'ข้ามรายการนี้?',
      message:
          'ต้องการข้ามรายการวันที่ ${_formatDateShort(dueDate)} ใช่หรือไม่?',
      confirmLabel: 'ข้าม',
      isDestructive: true,
    ).then((confirmed) {
      if (!confirmed || !context.mounted) return;
      context.read<RecurringTransactionProvider>().markOccurrenceSkipped(
        _recurring.id,
        dueDate,
      );
    });
  }

  void _undoOccurrence(BuildContext context, DateTime dueDate, bool isDark) {
    final recurProvider = context.read<RecurringTransactionProvider>();
    final txProvider = context.read<TransactionProvider>();
    final transactionsById = {
      for (final transaction in txProvider.transactions)
        transaction.id: transaction,
    };

    final occ = recurProvider.findOccurrence(_recurring.id, dueDate);
    final linkedTx = occ?.transactionId != null
        ? transactionsById[occ!.transactionId]
        : null;

    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    showAppConfirmDialog(
      context: context,
      title: 'ยกเลิกรายการนี้?',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ต้องการยกเลิกสถานะรายการวันที่ ${_formatDateShort(dueDate)} ใช่หรือไม่?',
            style: TextStyle(color: textColor),
          ),
          if (linkedTx != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkExpense.withValues(alpha: 0.2)
                    : AppColors.expense.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ จะมีการลบธุรกรรมที่สร้างไว้ด้วย',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkExpense : AppColors.expense,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'จำนวน: ${formatAmount(linkedTx.amount)} บาท',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      confirmLabel: 'ยืนยัน',
      isDestructive: true,
    ).then((confirmed) {
      if (!confirmed || !context.mounted) return;
      // Delete linked transaction if exists
      if (linkedTx != null) {
        txProvider.deleteTransaction(linkedTx.id);
      }
      // Undo the occurrence
      recurProvider.undoOccurrence(_recurring.id, dueDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<
      RecurringTransactionProvider,
      TransactionProvider,
      AccountProvider,
      SettingsProvider
    >(
      builder: (context, recurProvider, txProvider, accProvider, sp, _) {
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

        // Re-fetch recurring in case it was edited
        final latest = recurProvider.recurring
            .where((r) => r.id == _recurring.id)
            .toList();
        final recurring = latest.isNotEmpty ? latest.first : _recurring;

        final account = accProvider.findById(recurring.accountId);
        final catProvider = context.read<CategoryProvider>();
        final category = recurring.categoryId != null
            ? catProvider.findById(recurring.categoryId!)
            : null;
        final toAccount = recurring.toAccountId != null
            ? accProvider.findById(recurring.toAccountId!)
            : null;

        final typeColor = _typeColor(recurring.transactionType, isDark);
        final occurrenceDates = _getOccurrenceDatesFrom(recurring);
        final occurrencesByDay = {
          for (final occurrence in recurProvider.occurrencesFor(recurring.id))
            _dayKey(occurrence.dueDate): occurrence,
        };
        final transactionsById = {
          for (final transaction in txProvider.transactions)
            transaction.id: transaction,
        };

        final now = DateTime.now();
        final firstDayOfCurrentMonth = DateTime(now.year, now.month);

        // Keep the whole current month actionable; older months are history.
        final upcoming = occurrenceDates
            .where((d) => !d.isBefore(firstDayOfCurrentMonth))
            .toList();
        final past = occurrenceDates
            .where((d) => d.isBefore(firstDayOfCurrentMonth))
            .toList()
            .reversed
            .toList();

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            foregroundColor: textPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leadingWidth: 64,
            leading: const AppBackButton(),
            title: Text(
              recurring.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            actions: [
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
                      Icons.edit_outlined,
                      size: 20,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                    onPressed: _openForm,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ── Header card ──────────────────────────────────────────────
                  RecurringSection(
                    title: 'สรุปรายการประจำ',
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: recurring.color.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  recurring.icon,
                                  color: recurring.color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recurring.name,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        AppStatusChip(
                                          label:
                                              recurring.transactionType.label,
                                          color: typeColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          formatAmount(recurring.amount),
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: typeColor,
                                          ),
                                        ),
                                        Text(
                                          ' บาท',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const AppCardDivider(),
                          const SizedBox(height: 12),
                          // Details grid
                          RecurringDetailRow(
                            label: 'บัญชี',
                            value: account?.name ?? '-',
                            icon: account?.icon ?? Icons.account_balance_wallet,
                            iconColor: account?.color ?? textSecondary,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          if (toAccount != null) ...[
                            const SizedBox(height: 6),
                            RecurringDetailRow(
                              label: 'บัญชีปลายทาง',
                              value: toAccount.name,
                              icon: toAccount.icon,
                              iconColor: toAccount.color,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ],
                          if (category != null) ...[
                            const SizedBox(height: 6),
                            RecurringDetailRow(
                              label: 'หมวดหมู่',
                              value: category.name,
                              icon: category.icon,
                              iconColor: category.color,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'ทุกวันที่ ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                              Text(
                                recurring.dayOfMonth == 0
                                    ? 'สิ้นเดือน'
                                    : '${recurring.dayOfMonth} ของเดือน',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'เริ่ม ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                              Text(
                                _formatMonthYear(recurring.startDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              if (recurring.endDate != null) ...[
                                Text(
                                  '  ถึง  ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textSecondary,
                                  ),
                                ),
                                Text(
                                  _formatMonthYear(recurring.endDate!),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                              ] else
                                Text(
                                  '  (ต่อเนื่อง)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          if (recurring.note != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              recurring.note!,
                              style: TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                            ),
                          ],
                          // ── Summary ───────────────────────────────────────────
                          const SizedBox(height: 12),
                          const AppCardDivider(),
                          const SizedBox(height: 12),
                          RecurringRemainingSummary(
                            upcoming: upcoming,
                            past: past,
                            recurring: recurring,
                            occurrencesByDay: occurrencesByDay,
                            transactionsById: transactionsById,
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            typeColor: typeColor,
                            hasEndDate: recurring.endDate != null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Tab bar ──────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppSegmentedTabs(
                      segments: [
                        AppSegment(
                          label: 'รายการที่จะเกิดขึ้น (${upcoming.length})',
                          isSelected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                        AppSegment(
                          label: 'รายการที่ผ่านมา (${past.length})',
                          isSelected: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final isUpcomingTab = _selectedTab == 0;
                      final dates = isUpcomingTab ? upcoming : past;
                      if (dates.isEmpty) {
                        return RecurringDetailEmptyState(
                          message: isUpcomingTab
                              ? 'ไม่มีรายการที่จะเกิดขึ้น'
                              : 'ไม่มีรายการที่ผ่านมา',
                          isDark: isDark,
                        );
                      }

                      Widget buildOccurrence(DateTime date) {
                        final occ = occurrencesByDay[_dayKey(date)];
                        final linkedTx = occ?.transactionId != null
                            ? transactionsById[occ!.transactionId]
                            : null;
                        return RecurringOccurrenceItem(
                          date: date,
                          occurrence: occ,
                          linkedTransaction: linkedTx,
                          recurring: recurring,
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          dividerColor: dividerColor,
                          typeColor: typeColor,
                          formatDate: _formatDateLong,
                          onCreateTap: () =>
                              _createTransaction(context, date, isDark),
                          onSkipTap: () =>
                              _skipOccurrence(context, date, isDark),
                          onUndoTap: () =>
                              _undoOccurrence(context, date, isDark),
                          onEditTap: linkedTx != null
                              ? () => _editTransaction(context, linkedTx, date)
                              : null,
                        );
                      }

                      return Column(
                        children: [
                          for (final date in dates) buildOccurrence(date),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<DateTime> _getOccurrenceDatesFrom(RecurringTransaction r) {
    final now = DateTime.now();
    final upTo = r.endDate ?? DateTime(now.year, now.month + 2, now.day);
    return r.generateOccurrenceDates(upTo: upTo);
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
}
