import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_drawer.dart';
import 'transaction_form_screen.dart';

class TransactionListScreen extends StatefulWidget {
  final String? accountId;
  final List<String>? categoryIds;
  final List<String>? transactionIds;
  final DateTimeRange? fixedDateRange;
  final String? title;

  const TransactionListScreen({
    super.key,
    this.accountId,
    this.categoryIds,
    this.transactionIds,
    this.fixedDateRange,
    this.title,
  });

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  _PeriodFilter _filter = _PeriodFilter.thisYear;

  @override
  Widget build(BuildContext context) {
    return Consumer4<
      AccountProvider,
      TransactionProvider,
      CategoryProvider,
      SettingsProvider
    >(
      builder:
          (
            context,
            accountProvider,
            txProvider,
            catProvider,
            settingsProvider,
            _,
          ) {
            final isDarkMode = settingsProvider.isDarkMode;
            final allTx = _getFilteredTransactions(txProvider);
            final grouped = txProvider.groupByDate(allTx);
            final sortedDates = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            final totalIncome = txProvider.getTotalIncome(allTx);
            final totalExpense = txProvider.getTotalActualExpense(
              allTx,
              accountProvider.accounts,
            );
            final isFromAccount = widget.accountId != null;
            final isFiltered =
                isFromAccount ||
                widget.categoryIds != null ||
                widget.transactionIds != null ||
                widget.fixedDateRange != null;

            return Scaffold(
              drawer: isFiltered
                  ? null
                  : const AppDrawer(currentRoute: '/transactions'),
              appBar: AppBar(
                leading: isFiltered
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      )
                    : Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                title: Text(
                  widget.title != null
                      ? '${widget.title} (${allTx.length})'
                      : '${_filter.label} (${allTx.length})',
                  style: const TextStyle(fontSize: 16),
                ),
                centerTitle: true,
                actions: [
                  if (widget.fixedDateRange == null &&
                      widget.transactionIds == null)
                    IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: () => _showPeriodPicker(isDarkMode),
                    ),
                ],
              ),
              body: allTx.isEmpty
                  ? Center(
                      child: Text(
                        'ยังไม่มีรายการ',
                        style: TextStyle(
                          color: isDarkMode
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: sortedDates.length,
                      itemBuilder: (context, i) {
                        final date = sortedDates[i];
                        final txs = grouped[date]!
                          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
                        final dayIncome = txProvider.getTotalIncome(txs);
                        final dayExpense = txProvider.getTotalActualExpense(
                          txs,
                          accountProvider.accounts,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DateHeader(
                              date: date,
                              income: dayIncome,
                              expense: dayExpense,
                              isDarkMode: isDarkMode,
                            ),
                            ...txs.asMap().entries.map((entry) {
                              final index = entry.key;
                              final tx = entry.value;
                              return Column(
                                children: [
                                  _TransactionItem(
                                    tx: tx,
                                    accountProvider: accountProvider,
                                    catProvider: catProvider,
                                    onTap: () => _openForm(context, tx),
                                    isDarkMode: isDarkMode,
                                  ),
                                  if (index < txs.length - 1)
                                    Divider(
                                      height: 1,
                                      color: isDarkMode
                                          ? AppColors.darkDivider
                                          : AppColors.divider,
                                    ),
                                ],
                              );
                            }),
                          ],
                        );
                      },
                    ),
              bottomNavigationBar: _BottomSummaryBar(
                totalIncome: totalIncome,
                totalExpense: totalExpense,
                onAdd: () => _openForm(context, null),
                isDarkMode: isDarkMode,
              ),
            );
          },
    );
  }

  List<AppTransaction> _getFilteredTransactions(TransactionProvider provider) {
    final now = DateTime.now();
    final accountId = widget.accountId;
    final transactionIds = widget.transactionIds;
    List<AppTransaction> transactions;

    // ถ้ามี transactionIds ให้ใช้รายการทั้งหมดก่อน เพื่อไม่ให้ period filter ตัดรายการทิ้ง
    if (transactionIds != null) {
      transactions = List.of(provider.transactions)
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    } else if (widget.fixedDateRange != null) {
      // ถ้ามี fixedDateRange (เช่น จากงบประมาณ) ใช้ช่วงนั้นโดยตรง
      transactions = provider.getTransactionsForPeriod(
        widget.fixedDateRange!.start,
        widget.fixedDateRange!.end,
      );
    } else {
      switch (_filter) {
        case _PeriodFilter.last30Days:
          final from = now.subtract(const Duration(days: 30));
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
        case _PeriodFilter.last90Days:
          final from = now.subtract(const Duration(days: 90));
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
        case _PeriodFilter.last180Days:
          final from = now.subtract(const Duration(days: 180));
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
        case _PeriodFilter.thisMonth:
          final from = DateTime(now.year, now.month, 1);
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
        case _PeriodFilter.lastMonth:
          final from = DateTime(now.year, now.month - 1, 1);
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
        case _PeriodFilter.thisYear:
          final from = DateTime(now.year, 1, 1);
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
      }
    }

    // กรองตาม accountId
    if (accountId != null) {
      transactions = transactions
          .where(
            (tx) => tx.accountId == accountId || tx.toAccountId == accountId,
          )
          .toList();
    }

    // กรองตาม categoryIds (จากงบประมาณ)
    final categoryIds = widget.categoryIds;
    if (categoryIds != null && categoryIds.isNotEmpty) {
      transactions = transactions
          .where((tx) => categoryIds.contains(tx.categoryId))
          .toList();
    }

    if (transactionIds != null && transactionIds.isNotEmpty) {
      final transactionIdSet = transactionIds.toSet();
      transactions = transactions
          .where((tx) => transactionIdSet.contains(tx.id))
          .toList();
    }

    return transactions;
  }

  void _showPeriodPicker(bool isDarkMode) {
    final handleColor = isDarkMode ? AppColors.darkHeader : AppColors.header;

    showModalBottomSheet(
      context: context,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ..._PeriodFilter.values.map(
              (f) => ListTile(
                title: Text(f.label),
                trailing: _filter == f
                    ? const Icon(Icons.check, color: AppColors.header)
                    : null,
                onTap: () {
                  setState(() => _filter = f);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openForm(BuildContext context, AppTransaction? tx) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TransactionFormScreen(transaction: tx)),
    );
  }
}

enum _PeriodFilter {
  last30Days('30 วันล่าสุด'),
  last90Days('90 วันล่าสุด'),
  last180Days('180 วันล่าสุด'),
  thisMonth('เดือนนี้'),
  lastMonth('เดือนที่แล้ว'),
  thisYear('ปีนี้');

  final String label;
  const _PeriodFilter(this.label);
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final double income;
  final double expense;
  final bool isDarkMode;

  const _DateHeader({
    required this.date,
    required this.income,
    required this.expense,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.background;
    final textColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatDate(date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          if (income > 0) ...[
            Text(
              '+${formatAmount(income)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: incomeColor,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (expense > 0)
            Text(
              '-${formatAmount(expense)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: expenseColor,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const thaiDays = [
      'จันทร์',
      'อังคาร',
      'พุธ',
      'พฤหัสบดี',
      'ศุกร์',
      'เสาร์',
      'อาทิตย์',
    ];
    const thaiMonths = [
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
    final dayOfWeek = thaiDays[date.weekday - 1];
    return '${date.day} ${thaiMonths[date.month - 1]} ${date.year} - $dayOfWeek';
  }
}

class _TransactionItem extends StatelessWidget {
  final AppTransaction tx;
  final AccountProvider accountProvider;
  final CategoryProvider catProvider;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _TransactionItem({
    required this.tx,
    required this.accountProvider,
    required this.catProvider,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final account = accountProvider.findById(tx.accountId);
    final toAccount = tx.toAccountId != null
        ? accountProvider.findById(tx.toAccountId!)
        : null;
    final category = tx.categoryId != null
        ? catProvider.findById(tx.categoryId!)
        : null;

    final typeColor = _typeColor(tx.type, isDarkMode);
    final displayAmount = tx.type.isExpenseLike ? -tx.amount : tx.amount;

    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimaryColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final note = tx.note?.trim();

    return InkWell(
      onTap: onTap,
      child: Container(
        color: surfaceColor,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Type indicator bar
              Container(width: 4, color: typeColor),
              const SizedBox(width: 12),
              // Category/Type icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tx.type == TransactionType.debtTransfer
                      ? Icons.account_tree
                      : tx.type == TransactionType.transfer
                      ? Icons.swap_horiz
                      : tx.type == TransactionType.debtRepay
                      ? Icons.payment
                      : (category?.icon ?? Icons.receipt),
                  color: tx.type == TransactionType.debtTransfer
                      ? typeColor
                      : (category?.color ?? typeColor),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _buildAccountLabel(account, toAccount, tx),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _buildSubLabel(category?.name, note),
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              // Time + Amount
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTime(tx.dateTime),
                      style: TextStyle(fontSize: 13, color: textSecondaryColor),
                    ),
                    Text(
                      tx.type == TransactionType.transfer
                          ? formatAmount(tx.amount)
                          : '${displayAmount > 0 ? '+' : ''}${formatAmount(displayAmount)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tx.type == TransactionType.transfer
                            ? (isDarkMode
                                  ? AppColors.darkTransfer
                                  : AppColors.transfer)
                            : tx.type == TransactionType.debtRepay
                            ? (isDarkMode
                                  ? AppColors.darkExpense
                                  : AppColors.expense)
                            : tx.type == TransactionType.debtTransfer
                            ? (isDarkMode
                                  ? AppColors.darkDebtTransfer
                                  : AppColors.debtTransfer)
                            : AppColors.getAmountColor(
                                displayAmount,
                                isDarkMode,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(TransactionType type, bool isDarkMode) {
    if (isDarkMode) {
      switch (type) {
        case TransactionType.income:
          return AppColors.darkIncome;
        case TransactionType.expense:
          return AppColors.darkExpense;
        case TransactionType.transfer:
          return AppColors.darkTransfer;
        case TransactionType.debtRepay:
          return AppColors.darkDebtRepay;
        case TransactionType.debtTransfer:
          return AppColors.darkDebtTransfer;
      }
    }
    switch (type) {
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.transfer:
        return AppColors.transfer;
      case TransactionType.debtRepay:
        return AppColors.debtRepay;
      case TransactionType.debtTransfer:
        return AppColors.debtTransfer;
    }
  }

  String _buildAccountLabel(
    Account? account,
    Account? toAccount,
    AppTransaction tx,
  ) {
    if (tx.type.usesDestinationAccount) {
      final from = account?.name ?? '-';
      final to = toAccount?.name ?? '-';
      return '$from → $to';
    }
    return account?.name ?? '-';
  }

  String _buildSubLabel(String? categoryName, String? note) {
    final parts = <String>[
      if (categoryName != null && categoryName.isNotEmpty) categoryName,
      if (note != null && note.isNotEmpty) note,
    ];
    return parts.join(' • ');
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _BottomSummaryBar extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final VoidCallback onAdd;
  final bool isDarkMode;

  const _BottomSummaryBar({
    required this.totalIncome,
    required this.totalExpense,
    required this.onAdd,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final headerColor = isDarkMode ? AppColors.darkHeader : AppColors.header;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final fabColor = isDarkMode ? AppColors.darkFabYellow : AppColors.fabYellow;

    return Container(
      color: headerColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'รายรับรวม',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                      Text(
                        '${formatAmount(totalIncome)} บาท',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: incomeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // FAB
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: fabColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'รายจ่ายรวม',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                      Text(
                        '-${formatAmount(totalExpense)} บาท',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
