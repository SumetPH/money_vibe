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
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  _PeriodFilter _filter = _PeriodFilter.last30Days;

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
            final totalExpense = txProvider.getTotalExpense(allTx);

            return Scaffold(
              drawer: const AppDrawer(currentRoute: '/'),
              appBar: AppBar(
                leading: Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                title: GestureDetector(
                  onTap: _showPeriodPicker,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_filter.label} (${allTx.length})',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.tune), onPressed: () {}),
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
                        final dayExpense = txProvider.getTotalExpense(txs);

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
                                      indent: 52,
                                      endIndent: 12,
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
    switch (_filter) {
      case _PeriodFilter.last30Days:
        return provider.getLast30Days();
      case _PeriodFilter.thisMonth:
        final from = DateTime(now.year, now.month, 1);
        return provider.getTransactionsForPeriod(from, now);
      case _PeriodFilter.lastMonth:
        final from = DateTime(now.year, now.month - 1, 1);
        final to = DateTime(now.year, now.month, 0);
        return provider.getTransactionsForPeriod(from, to);
      case _PeriodFilter.thisYear:
        final from = DateTime(now.year, 1, 1);
        return provider.getTransactionsForPeriod(from, now);
    }
  }

  void _showPeriodPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _PeriodFilter.values
              .map(
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
              )
              .toList(),
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
    return '${date.day} ${thaiMonths[date.month - 1]} ${date.year + 543} - $dayOfWeek';
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
    final displayAmount =
        (tx.type == TransactionType.expense ||
            tx.type == TransactionType.debtRepay)
        ? -tx.amount
        : tx.amount;

    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimaryColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: surfaceColor,
        child: Row(
          children: [
            // Type indicator bar
            Container(width: 4, height: 60, color: typeColor),
            const SizedBox(width: 12),
            // Category/Type icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (category?.color ?? typeColor).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                tx.type == TransactionType.transfer
                    ? Icons.swap_horiz
                    : tx.type == TransactionType.debtRepay
                    ? Icons.payment
                    : (category?.icon ?? Icons.receipt),
                color: category?.color ?? typeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account info
                  Text(
                    _buildAccountLabel(account, toAccount, tx),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Category / Payee
                  Text(
                    _buildSubLabel(category?.name),
                    style: TextStyle(fontSize: 14, color: textSecondaryColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Time + Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
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
                        : AppColors.getAmountColor(displayAmount, isDarkMode),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
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
          return AppColors.darkExpense;
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
        return AppColors.expense;
    }
  }

  String _buildAccountLabel(
    Account? account,
    Account? toAccount,
    AppTransaction tx,
  ) {
    if (tx.type == TransactionType.transfer ||
        tx.type == TransactionType.debtRepay) {
      final from = account?.name ?? '-';
      final to = toAccount?.name ?? '-';
      return '$from → $to';
    }
    return account?.name ?? '-';
  }

  String _buildSubLabel(String? categoryName) {
    if (categoryName != null) {
      return categoryName;
    }
    return categoryName ?? '';
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
