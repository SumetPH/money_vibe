import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/bottom_summary_bar.dart';
import '../../widgets/group_header.dart';
import 'transaction_form_screen.dart';

class TransactionListScreen extends StatefulWidget {
  final String? accountId;
  final List<String>? categoryIds;
  final List<String>? transactionIds;
  final DateTimeRange? fixedDateRange;
  final DateTime? creditCardPaymentStartDate;
  final String? title;

  const TransactionListScreen({
    super.key,
    this.accountId,
    this.categoryIds,
    this.transactionIds,
    this.fixedDateRange,
    this.creditCardPaymentStartDate,
    this.title,
  });

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  _PeriodFilter _filter = _PeriodFilter.thisYear;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SyncProvider>().checkAndSync();
      }
    });
  }

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
            final listData = _buildTransactionListData(allTx, accountProvider);
            final isFromAccount = widget.accountId != null;
            final isFiltered =
                isFromAccount ||
                widget.categoryIds != null ||
                widget.transactionIds != null ||
                widget.fixedDateRange != null;

            final isLargeScreen = MediaQuery.of(context).size.width >= 800;

            return Scaffold(
              drawer: (isLargeScreen || isFiltered)
                  ? null
                  : const AppDrawer(currentRoute: '/transactions'),
              appBar: AppBar(
                leading: isFiltered
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      )
                    : (isLargeScreen
                          ? null
                          : Builder(
                              builder: (ctx) => IconButton(
                                icon: const Icon(Icons.menu),
                                onPressed: () => Scaffold.of(ctx).openDrawer(),
                              ),
                            )),
                title: Text(
                  widget.title != null
                      ? '${widget.title} (${NumberFormat('#,###').format(listData.transactions.length)})'
                      : '${_filter.label} (${NumberFormat('#,###').format(listData.transactions.length)})',
                  style: const TextStyle(fontSize: 16),
                ),
                actions: [
                  if (widget.fixedDateRange == null &&
                      widget.transactionIds == null)
                    IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: () => _showPeriodPicker(isDarkMode),
                    ),
                ],
              ),
              body: listData.transactions.isEmpty
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
                      itemCount: listData.groups.length,
                      itemBuilder: (context, i) {
                        final group = listData.groups[i];
                        final txs = group.transactions;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GroupHeader(
                              title: _formatDate(group.date),
                              isDarkMode: isDarkMode,
                              trailing: [
                                if (group.income > 0) ...[
                                  Text(
                                    '+${formatAmount(group.income)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? AppColors.darkIncome
                                          : AppColors.income,
                                    ),
                                  ),
                                ],
                                if (group.income > 0 && group.expense > 0)
                                  const SizedBox(width: 8),
                                if (group.expense > 0) ...[
                                  Text(
                                    '-${formatAmount(group.expense)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? AppColors.darkExpense
                                          : AppColors.expense,
                                    ),
                                  ),
                                ],
                              ],
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
                                    viewingAccountId: widget.accountId,
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
              bottomNavigationBar: BottomSummaryBar(
                left: BottomSummaryValue(
                  label: 'รายรับรวม',
                  value: formatAmount(listData.totalIncome),
                  color: isDarkMode ? AppColors.darkIncome : AppColors.income,
                ),
                right: BottomSummaryValue(
                  label: 'รายจ่ายรวม',
                  value: '-${formatAmount(listData.totalExpense)}',
                  color: AppColors.expense,
                ),
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
        case _PeriodFilter.all:
          transactions = List.of(provider.transactions)
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
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

    if (transactionIds != null) {
      final transactionIdSet = transactionIds.toSet();
      transactions = transactions
          .where((tx) => transactionIdSet.contains(tx.id))
          .toList();
    }

    final paymentStartDate = widget.creditCardPaymentStartDate;
    if (paymentStartDate != null && accountId != null) {
      transactions = transactions.where((tx) {
        final isPayment =
            ((tx.type == TransactionType.transfer ||
                    tx.type == TransactionType.debtRepay) &&
                tx.toAccountId == accountId) ||
            (tx.type == TransactionType.income && tx.accountId == accountId);

        if (isPayment) {
          final txDay = DateTime(
            tx.dateTime.year,
            tx.dateTime.month,
            tx.dateTime.day,
          );
          if (txDay.isBefore(paymentStartDate)) {
            return false;
          }
        }
        return true;
      }).toList();
    }

    return transactions;
  }

  _TransactionListData _buildTransactionListData(
    List<AppTransaction> txs,
    AccountProvider accountProvider,
  ) {
    final accounts = accountProvider.accounts;
    final accountsById = {for (final account in accounts) account.id: account};
    final accountTypesById = {
      for (final account in accounts) account.id: account.type,
    };
    final grouped = <DateTime, _MutableTransactionDateGroup>{};
    var totalIncome = 0.0;
    var totalExpense = 0.0;

    for (final tx in txs) {
      final date = DateTime(
        tx.dateTime.year,
        tx.dateTime.month,
        tx.dateTime.day,
      );
      final group = grouped.putIfAbsent(
        date,
        () => _MutableTransactionDateGroup(date),
      );
      group.transactions.add(tx);

      final summaryAmount = _getSummaryAmountInThb(
        tx,
        accountsById,
        accountTypesById,
      );
      if (summaryAmount > 0) {
        totalIncome += summaryAmount;
        group.income += summaryAmount;
      } else if (summaryAmount < 0) {
        final expense = summaryAmount.abs();
        totalExpense += expense;
        group.expense += expense;
      }
    }

    final groups = grouped.values.map((group) {
      group.transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return _TransactionDateGroup(
        date: group.date,
        transactions: group.transactions,
        income: group.income,
        expense: group.expense,
      );
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    return _TransactionListData(
      transactions: txs,
      groups: groups,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
    );
  }

  double _getSummaryAmountInThb(
    AppTransaction tx,
    Map<String, Account> accountsById,
    Map<String, AccountType> accountTypesById,
  ) {
    final account = accountsById[tx.accountId];
    final rate = _effectiveRate(account);

    if (widget.accountId == null) {
      if (tx.type == TransactionType.income ||
          tx.type == TransactionType.increaseBalance) {
        return tx.amount * rate;
      }
      if (_isActualExpense(tx, accountTypesById) ||
          tx.type == TransactionType.decreaseBalance) {
        return -tx.amount * rate;
      }
      return 0.0;
    }

    final toAccount = tx.toAccountId != null
        ? accountsById[tx.toAccountId!]
        : null;
    final toRate = _effectiveRate(toAccount);

    var displayAmount = tx.type.isExpenseLike || tx.type.isDecreaseBalance
        ? -tx.amount
        : tx.amount;
    var amountInThb = tx.amount * rate;

    if ((tx.type == TransactionType.debtRepay ||
            tx.type == TransactionType.debtTransfer) &&
        tx.toAccountId == widget.accountId) {
      displayAmount = tx.amount;
      amountInThb = tx.amount * toRate;
    } else if (tx.type == TransactionType.transfer) {
      if (tx.accountId == widget.accountId) {
        displayAmount = -tx.amount;
        amountInThb = -tx.amount * rate;
      } else if (tx.toAccountId == widget.accountId) {
        displayAmount = tx.toAmount ?? tx.amount;
        amountInThb = displayAmount * toRate;
      }
    }

    if (displayAmount > 0) return amountInThb;
    if (displayAmount < 0) return -amountInThb.abs();
    return 0.0;
  }

  double _effectiveRate(Account? account) =>
      (account?.exchangeRate ?? 0) > 0 ? account!.exchangeRate : 1.0;

  bool _isActualExpense(
    AppTransaction tx,
    Map<String, AccountType> accountTypesById,
  ) {
    if (tx.type == TransactionType.expense) return true;
    if (tx.type == TransactionType.debtTransfer) return true;
    if (tx.type == TransactionType.debtRepay) {
      return accountTypesById[tx.toAccountId] != AccountType.creditCard;
    }
    return false;
  }

  void _showPeriodPicker(bool isDarkMode) {
    final handleColor = isDarkMode ? AppColors.darkHeader : AppColors.header;
    final bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final checkColor = isDarkMode ? AppColors.darkHeader : AppColors.header;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: _PeriodFilter.values
                      .map(
                        (f) => ListTile(
                          title: Text(
                            f.label,
                            style: TextStyle(color: textColor),
                          ),
                          trailing: _filter == f
                              ? Icon(Icons.check, color: checkColor)
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
            ],
          ),
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

class _TransactionListData {
  final List<AppTransaction> transactions;
  final List<_TransactionDateGroup> groups;
  final double totalIncome;
  final double totalExpense;

  const _TransactionListData({
    required this.transactions,
    required this.groups,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class _TransactionDateGroup {
  final DateTime date;
  final List<AppTransaction> transactions;
  final double income;
  final double expense;

  const _TransactionDateGroup({
    required this.date,
    required this.transactions,
    required this.income,
    required this.expense,
  });
}

class _MutableTransactionDateGroup {
  final DateTime date;
  final List<AppTransaction> transactions = [];
  double income = 0;
  double expense = 0;

  _MutableTransactionDateGroup(this.date);
}

enum _PeriodFilter {
  all('ทั้งหมด'),
  last30Days('30 วันล่าสุด'),
  last90Days('90 วันล่าสุด'),
  last180Days('180 วันล่าสุด'),
  thisMonth('เดือนนี้'),
  lastMonth('เดือนที่แล้ว'),
  thisYear('ปีนี้');

  final String label;
  const _PeriodFilter(this.label);
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

class _TransactionItem extends StatelessWidget {
  final AppTransaction tx;
  final AccountProvider accountProvider;
  final CategoryProvider catProvider;
  final VoidCallback onTap;
  final bool isDarkMode;
  final String? viewingAccountId;

  const _TransactionItem({
    required this.tx,
    required this.accountProvider,
    required this.catProvider,
    required this.onTap,
    required this.isDarkMode,
    this.viewingAccountId,
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
    double displayAmount = tx.type.isExpenseLike || tx.type.isDecreaseBalance
        ? -tx.amount
        : tx.amount;

    if (viewingAccountId != null) {
      if ((tx.type == TransactionType.debtRepay ||
              tx.type == TransactionType.debtTransfer) &&
          tx.toAccountId == viewingAccountId) {
        displayAmount = tx.amount;
      } else if (tx.type == TransactionType.transfer) {
        if (tx.accountId == viewingAccountId) {
          displayAmount = -tx.amount;
        } else if (tx.toAccountId == viewingAccountId) {
          displayAmount = tx.toAmount ?? tx.amount;
        }
      }
    }

    final currency = viewingAccountId != null
        ? (viewingAccountId == tx.toAccountId
              ? toAccount?.currency
              : account?.currency)
        : account?.currency;

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
                      _buildAccountWidget(
                        account,
                        toAccount,
                        tx,
                        textPrimaryColor,
                        isDarkMode,
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
                      (tx.type == TransactionType.transfer &&
                              viewingAccountId == null)
                          ? '${formatAmount(tx.amount)}${account?.currency == 'THB' ? '' : ' ${account?.currency ?? ''}'}'
                          : '${displayAmount > 0 ? '+' : ''}${formatAmount(displayAmount)}${currency == 'THB' ? '' : ' ${currency ?? ''}'}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color:
                            (tx.type == TransactionType.transfer &&
                                viewingAccountId == null)
                            ? (isDarkMode
                                  ? AppColors.darkTransfer
                                  : AppColors.transfer)
                            : (tx.type == TransactionType.debtRepay &&
                                  viewingAccountId == null)
                            ? (isDarkMode
                                  ? AppColors.darkExpense
                                  : AppColors.expense)
                            : (tx.type == TransactionType.debtTransfer &&
                                  viewingAccountId == null)
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
        case TransactionType.increaseBalance:
          return AppColors.darkIncome;
        case TransactionType.decreaseBalance:
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
        return AppColors.debtRepay;
      case TransactionType.debtTransfer:
        return AppColors.debtTransfer;
      case TransactionType.increaseBalance:
        return AppColors.income;
      case TransactionType.decreaseBalance:
        return AppColors.expense;
    }
  }

  Widget _buildAccountWidget(
    Account? account,
    Account? toAccount,
    AppTransaction tx,
    Color textPrimaryColor,
    bool isDarkMode,
  ) {
    final style = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: textPrimaryColor,
    );

    if (tx.type.usesDestinationAccount) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (account != null) ...[
            AccountIconWidget(
              account: account,
              size: 16,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              account?.name ?? '-',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('→', style: style),
          ),
          if (toAccount != null) ...[
            AccountIconWidget(
              account: toAccount,
              size: 16,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              toAccount?.name ?? '-',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    String prefix = '';
    if (tx.type.isIncreaseBalance || tx.type.isDecreaseBalance) {
      prefix = tx.type == TransactionType.increaseBalance
          ? 'ปรับเพิ่ม '
          : 'ปรับลด ';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefix.isNotEmpty) Text(prefix, style: style),
        if (account != null) ...[
          AccountIconWidget(account: account, size: 16, isDarkMode: isDarkMode),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            account?.name ?? '-',
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
