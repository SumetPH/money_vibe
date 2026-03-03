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
import '../../main.dart';
import '../../screens/transaction/transaction_form_screen.dart';
import 'recurring_form_screen.dart';

class RecurringDetailScreen extends StatefulWidget {
  final RecurringTransaction recurring;

  const RecurringDetailScreen({super.key, required this.recurring});

  @override
  State<RecurringDetailScreen> createState() => _RecurringDetailScreenState();
}

class _RecurringDetailScreenState extends State<RecurringDetailScreen> {
  late RecurringTransaction _recurring;

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
      final updated = provider.recurring.where((r) => r.id == _recurring.id);
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
    final templateTx = AppTransaction(
      id: '', // will be replaced
      type: _recurring.transactionType,
      amount: _recurring.amount,
      accountId: _recurring.accountId,
      categoryId: _recurring.categoryId,
      toAccountId: _recurring.toAccountId,
      dateTime: DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        DateTime.now().hour,
        DateTime.now().minute,
      ),
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
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgColor,
        title: Text('ข้ามรายการนี้?', style: TextStyle(color: textColor)),
        content: Text(
          'ต้องการข้ามรายการวันที่ ${_formatDateShort(dueDate)} ใช่หรือไม่?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก', style: TextStyle(color: textColor)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.darkExpense
                  : AppColors.expense,
            ),
            onPressed: () {
              context
                  .read<RecurringTransactionProvider>()
                  .markOccurrenceSkipped(_recurring.id, dueDate);
              Navigator.pop(context);
            },
            child: const Text('ข้าม'),
          ),
        ],
      ),
    );
  }

  void _undoOccurrence(BuildContext context, DateTime dueDate, bool isDark) {
    final recurProvider = context.read<RecurringTransactionProvider>();
    final txProvider = context.read<TransactionProvider>();

    final occ = recurProvider.findOccurrence(_recurring.id, dueDate);
    final linkedTx = occ?.transactionId != null
        ? txProvider.transactions
              .where((t) => t.id == occ!.transactionId)
              .firstOrNull
        : null;

    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgColor,
        title: Text('ยกเลิกรายการนี้?', style: TextStyle(color: textColor)),
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
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ จะมีการลบธุรกรรมที่สร้างไว้ด้วย',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkExpense
                            : Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'จำนวน: ${formatAmount(linkedTx.amount)} บาท',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก', style: TextStyle(color: textColor)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.darkExpense
                  : AppColors.expense,
            ),
            onPressed: () {
              // Delete linked transaction if exists
              if (linkedTx != null) {
                txProvider.deleteTransaction(linkedTx.id);
              }
              // Undo the occurrence
              recurProvider.undoOccurrence(_recurring.id, dueDate);
              Navigator.pop(context);
            },
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
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

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Separate upcoming (today or future) and past
        final upcoming = occurrenceDates
            .where((d) => !d.isBefore(today))
            .toList();
        final past = occurrenceDates
            .where((d) => d.isBefore(today))
            .toList()
            .reversed
            .toList();

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(recurring.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: _openForm,
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              // ── Header card ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: surfaceColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: recurring.color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              recurring.icon,
                              color: recurring.color,
                              size: 26,
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    _TypeBadge(
                                      label: recurring.transactionType.label,
                                      color: typeColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      formatAmount(recurring.amount),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: typeColor,
                                      ),
                                    ),
                                    Text(
                                      ' บาท',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textSecondary,
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
                      Divider(height: 1, color: dividerColor),
                      const SizedBox(height: 12),
                      // Details grid
                      _DetailRow(
                        label: 'บัญชี',
                        value: account?.name ?? '-',
                        icon: account?.icon ?? Icons.account_balance_wallet,
                        iconColor: account?.color ?? textSecondary,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      if (toAccount != null) ...[
                        const SizedBox(height: 6),
                        _DetailRow(
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
                        _DetailRow(
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
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                          Text(
                            recurring.dayOfMonth == 0
                                ? 'สิ้นเดือน'
                                : '${recurring.dayOfMonth} ของเดือน',
                            style: TextStyle(
                              fontSize: 13,
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
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                          Text(
                            _formatMonthYear(recurring.startDate),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          if (recurring.endDate != null) ...[
                            Text(
                              '  ถึง  ',
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                            Text(
                              _formatMonthYear(recurring.endDate!),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ] else
                            Text(
                              '  (ต่อเนื่อง)',
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                        ],
                      ),
                      if (recurring.note != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          recurring.note!,
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Upcoming section ─────────────────────────────────────────
              if (upcoming.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'รายการที่จะเกิดขึ้น',
                    bgColor: bgColor,
                    textSecondary: textSecondary,
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final date = upcoming[i];
                    final occ = recurProvider.findOccurrence(
                      recurring.id,
                      date,
                    );
                    final linkedTx = occ?.transactionId != null
                        ? txProvider.transactions
                              .where((t) => t.id == occ!.transactionId)
                              .firstOrNull
                        : null;
                    return _OccurrenceItem(
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
                      onSkipTap: () => _skipOccurrence(context, date, isDark),
                      onUndoTap: () => _undoOccurrence(context, date, isDark),
                      onEditTap: linkedTx != null
                          ? () => _editTransaction(context, linkedTx, date)
                          : null,
                    );
                  }, childCount: upcoming.length),
                ),
              ],

              // ── Past section ─────────────────────────────────────────────
              if (past.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'รายการที่ผ่านมา',
                    bgColor: bgColor,
                    textSecondary: textSecondary,
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final date = past[i];
                    final occ = recurProvider.findOccurrence(
                      recurring.id,
                      date,
                    );
                    final linkedTx = occ?.transactionId != null
                        ? txProvider.transactions
                              .where((t) => t.id == occ!.transactionId)
                              .firstOrNull
                        : null;
                    return _OccurrenceItem(
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
                      onSkipTap: () => _skipOccurrence(context, date, isDark),
                      onUndoTap: () => _undoOccurrence(context, date, isDark),
                      onEditTap: linkedTx != null
                          ? () => _editTransaction(context, linkedTx, date)
                          : null,
                    );
                  }, childCount: past.length),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
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
    }
  }
}

// ── Occurrence list item ──────────────────────────────────────────────────────

class _OccurrenceItem extends StatelessWidget {
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

  const _OccurrenceItem({
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
    return Column(
      children: [
        Container(
          color: surfaceColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        _StatusBadge(status: _status, isDark: isDark),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (onEditTap != null)
                            _ActionButton(
                              label: 'แก้ไข',
                              icon: Icons.edit_outlined,
                              color: isDark
                                  ? AppColors.darkTransfer
                                  : AppColors.transfer,
                              onTap: onEditTap!,
                            ),
                        ],
                      ),
                    ],
                    // Actions
                    if (_status == OccurrenceStatus.pending) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _ActionButton(
                            label: 'สร้างรายการ',
                            icon: Icons.add_circle_outline,
                            color: isDark
                                ? AppColors.darkIncome
                                : AppColors.income,
                            onTap: onCreateTap,
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            label: 'ข้าม',
                            icon: Icons.skip_next_outlined,
                            color: Colors.orange,
                            onTap: onSkipTap,
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onUndoTap,
                        child: Text(
                          'ยกเลิก',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, indent: 34, color: dividerColor),
      ],
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

class _StatusBadge extends StatelessWidget {
  final OccurrenceStatus status;
  final bool isDark;

  const _StatusBadge({required this.status, required this.isDark});

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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
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
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color bgColor;
  final Color textSecondary;

  const _SectionHeader({
    required this.title,
    required this.bgColor,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color textPrimary;
  final Color textSecondary;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 13, color: iconColor),
        ),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
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
