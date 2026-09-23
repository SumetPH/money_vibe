import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/monthly_cycle_selector.dart';
import '../../utils/monthly_cycle.dart';
import 'transaction_form_screen.dart';

class TransactionListScreen extends StatefulWidget {
  final bool showPrimaryNavigation;
  final String? accountId;
  final List<String>? categoryIds;
  final List<String>? transactionIds;
  final DateTimeRange? fixedDateRange;
  final DateTime? monthlyCycleMonth;
  final DateTime? creditCardPaymentStartDate;
  final String? title;

  const TransactionListScreen({
    super.key,
    this.showPrimaryNavigation = true,
    this.accountId,
    this.categoryIds,
    this.transactionIds,
    this.fixedDateRange,
    this.monthlyCycleMonth,
    this.creditCardPaymentStartDate,
    this.title,
  });

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  _PeriodFilter _filter = _PeriodFilter.all;
  _TransactionTypeFilter _typeFilter = _TransactionTypeFilter.all;
  String _searchQuery = '';
  DateTime? _selectedCycleMonth;

  @override
  void initState() {
    super.initState();
    _selectedCycleMonth = widget.monthlyCycleMonth;
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
            final allTx = _getFilteredTransactions(
              txProvider,
              settingsProvider.monthlyCycleStartDay,
            );
            final summaryData = _buildTransactionListData(
              allTx,
              accountProvider,
            );
            final visibleTx = allTx
                .where(_matchesTypeFilter)
                .where((tx) => _matchesSearch(tx, accountProvider, catProvider))
                .toList();
            final listData = _buildTransactionListData(
              visibleTx,
              accountProvider,
            );
            final isFromAccount = widget.accountId != null;
            final isFiltered =
                isFromAccount ||
                widget.categoryIds != null ||
                widget.transactionIds != null ||
                widget.fixedDateRange != null;

            final isLargeScreen = MediaQuery.of(context).size.width >= 800;

            return Scaffold(
              drawer:
                  (isLargeScreen || !widget.showPrimaryNavigation || isFiltered)
                  ? null
                  : AppDrawer(
                      currentRoute: isFromAccount
                          ? '/accounts'
                          : '/transactions',
                    ),
              appBar: AppBar(
                automaticallyImplyLeading: false,
                toolbarHeight: 100,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: isDarkMode
                    ? AppColors.darkBackground
                    : AppColors.background,
                foregroundColor: isDarkMode
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
                centerTitle: false,
                titleSpacing: isFiltered ? 0 : (isLargeScreen ? 24 : 16),
                leading: isFiltered
                    ? IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDarkMode
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title ?? _periodTitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDarkMode
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'ธุรกรรม',
                      style: TextStyle(
                        color: isDarkMode
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                actions: [
                  _HeaderAction(
                    icon: Icons.add,
                    onTap: _openAddTransactionForm,
                    isDarkMode: isDarkMode,
                  ),
                  _HeaderAction(
                    icon: Icons.search,
                    onTap: _showSearchSheet,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              body: CustomScrollView(
                slivers: [
                  if (_selectedCycleMonth != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverToBoxAdapter(
                        child: MonthlyCycleSelector(
                          selectedMonth: _selectedCycleMonth!,
                          onPrevMonth: () => setState(
                            () => _selectedCycleMonth = DateTime(
                              _selectedCycleMonth!.year,
                              _selectedCycleMonth!.month - 1,
                            ),
                          ),
                          onNextMonth: () => setState(
                            () => _selectedCycleMonth = DateTime(
                              _selectedCycleMonth!.year,
                              _selectedCycleMonth!.month + 1,
                            ),
                          ),
                          surfaceColor: isDarkMode
                              ? AppColors.darkSurface
                              : AppColors.surface,
                          textPrimary: isDarkMode
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                          textSecondary: isDarkMode
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                          dividerColor: AppColors.listDividerFor(isDarkMode),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverToBoxAdapter(
                      child: _CashFlowSummary(
                        income: summaryData.totalIncome,
                        expense: summaryData.totalExpense,
                        periodLabel: _periodShortLabel(),
                        isDarkMode: isDarkMode,
                        hidePeriodSelector: _selectedCycleMonth != null,
                        onSelectPeriod:
                            widget.fixedDateRange == null &&
                                widget.transactionIds == null
                            ? () => _showPeriodPicker(isDarkMode)
                            : null,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverToBoxAdapter(
                      child: _TransactionTypeTabs(
                        selected: _typeFilter,
                        isDarkMode: isDarkMode,
                        onChanged: (value) =>
                            setState(() => _typeFilter = value),
                      ),
                    ),
                  ),
                  if (listData.transactions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'ยังไม่มีรายการ'
                              : 'ไม่พบรายการที่ค้นหา',
                          style: TextStyle(
                            color: isDarkMode
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: listData.groups.length,
                        itemBuilder: (context, i) {
                          final group = listData.groups[i];
                          final txs = group.transactions;
                          final dailyNet = group.income - group.expense;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _formatDate(group.date),
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? AppColors.darkTextSecondary
                                                : AppColors.textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (dailyNet != 0)
                                        Text(
                                          '${dailyNet > 0 ? '+' : '-'}฿ ${formatAmount(dailyNet.abs())}',
                                          style: TextStyle(
                                            color: AppColors.getAmountColor(
                                              dailyNet,
                                              isDarkMode,
                                            ),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? AppColors.darkSurface
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.xLarge,
                                    ),
                                    border: Border.all(
                                      color: isDarkMode
                                          ? AppColors.darkDivider.withValues(
                                              alpha: 0.4,
                                            )
                                          : AppColors.divider.withValues(
                                              alpha: 0.4,
                                            ),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.xLarge,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      children: txs.asMap().entries.map((
                                        entry,
                                      ) {
                                        final tx = entry.value;
                                        return Column(
                                          children: [
                                            _TransactionItem(
                                              tx: tx,
                                              accountProvider: accountProvider,
                                              catProvider: catProvider,
                                              onTap: () =>
                                                  _openForm(context, tx),
                                              isDarkMode: isDarkMode,
                                              viewingAccountId:
                                                  widget.accountId,
                                            ),
                                            if (entry.key < txs.length - 1)
                                              Divider(
                                                height: 1,
                                                color: AppColors.listDividerFor(
                                                  isDarkMode,
                                                ),
                                              ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
    );
  }

  bool _matchesTypeFilter(AppTransaction tx) {
    return switch (_typeFilter) {
      _TransactionTypeFilter.all => true,
      _TransactionTypeFilter.income =>
        tx.type == TransactionType.income || tx.type.isIncreaseBalance,
      _TransactionTypeFilter.expense =>
        tx.type.isExpenseLike || tx.type.isDecreaseBalance,
    };
  }

  bool _matchesSearch(
    AppTransaction tx,
    AccountProvider accountProvider,
    CategoryProvider categoryProvider,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final values = [
      accountProvider.findById(tx.accountId)?.name,
      if (tx.toAccountId != null)
        accountProvider.findById(tx.toAccountId!)?.name,
      if (tx.categoryId != null)
        categoryProvider.findById(tx.categoryId!)?.name,
      tx.note,
      tx.type.label,
    ];
    return values.any((value) => value?.toLowerCase().contains(query) ?? false);
  }

  String _periodTitle() {
    final now = DateTime.now();
    return switch (_filter) {
      _PeriodFilter.thisMonth => _formatMonthYear(now),
      _PeriodFilter.lastMonth => _formatMonthYear(
        DateTime(now.year, now.month - 1),
      ),
      _PeriodFilter.thisYear => 'ปี ${now.year}',
      _ => _filter.label,
    };
  }

  String _periodShortLabel() {
    final now = DateTime.now();
    return switch (_filter) {
      _PeriodFilter.thisMonth => _formatMonthShort(now),
      _PeriodFilter.lastMonth => _formatMonthShort(
        DateTime(now.year, now.month - 1),
      ),
      _ => _filter.shortLabel,
    };
  }

  void _openAddTransactionForm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
    );
  }

  void _showSearchSheet() {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppModalBottomSheetHeader(title: 'ค้นหาธุรกรรม'),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: CupertinoSearchTextField(
                  controller: TextEditingController(text: _searchQuery)
                    ..selection = TextSelection.collapsed(
                      offset: _searchQuery.length,
                    ),
                  autofocus: true,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  onSubmitted: (_) => Navigator.pop(sheetContext),
                  onSuffixTap: () {
                    setState(() => _searchQuery = '');
                    Navigator.pop(sheetContext);
                  },
                  placeholder: 'ค้นหาบัญชี หมวดหมู่ หรือโน้ต...',
                  placeholderStyle: TextStyle(
                    fontSize: 14,
                    color: textSecondary.withValues(alpha: 0.55),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                  backgroundColor: isDarkMode
                      ? AppColors.darkSurfaceVariant
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 0,
                  ),
                  prefixInsets: const EdgeInsetsDirectional.fromSTEB(
                    10,
                    0,
                    6,
                    0,
                  ),
                  suffixInsets: const EdgeInsetsDirectional.fromSTEB(
                    0,
                    0,
                    8,
                    0,
                  ),
                  itemColor: textSecondary.withValues(alpha: 0.6),
                  itemSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AppTransaction> _getFilteredTransactions(
    TransactionProvider provider,
    int monthlyCycleStartDay,
  ) {
    final now = DateTime.now();
    final accountId = widget.accountId;
    final transactionIds = widget.transactionIds;
    List<AppTransaction> transactions;

    // ถ้ามี transactionIds ให้ใช้รายการทั้งหมดก่อน เพื่อไม่ให้ period filter ตัดรายการทิ้ง
    if (transactionIds != null) {
      transactions = List.of(provider.transactions)
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    } else if (_selectedCycleMonth != null) {
      final period = monthlyCyclePeriod(
        _selectedCycleMonth!,
        monthlyCycleStartDay,
      );
      transactions = provider.getTransactionsForPeriod(
        period.start,
        period.endExclusive.subtract(const Duration(microseconds: 1)),
      );
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
        case _PeriodFilter.oneYear:
          final from = DateTime(now.year - 1, now.month, now.day);
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

      final summaryAmount = _getSummaryAmountInThb(tx, accountsById, accounts);
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
    List<Account> accounts,
  ) {
    final account = accountsById[tx.accountId];
    final rate = _effectiveRate(account);

    if (widget.accountId == null) {
      if (tx.type == TransactionType.income ||
          tx.type == TransactionType.increaseBalance) {
        return tx.amount * rate;
      }
      if (TransactionProvider.isActualExpense(tx, accounts) ||
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

  void _showPeriodPicker(bool isDarkMode) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final checkColor = isDarkMode ? AppColors.darkIncome : AppColors.income;

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppModalBottomSheetHeader(title: 'เลือกช่วงเวลา'),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: _PeriodFilter.values
                      .map(
                        (f) => ListTile(
                          title: Text(
                            f.label,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: _filter == f
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: _filter == f
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: checkColor,
                                  size: 22,
                                )
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
    final initialTx = (tx == null && widget.accountId != null)
        ? AppTransaction(
            id: '',
            type: TransactionType.expense,
            amount: 0,
            accountId: widget.accountId!,
          )
        : null;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TransactionFormScreen(transaction: tx, initialValues: initialTx),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _HeaderAction({
    required this.icon,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          side: BorderSide(
            color: isDarkMode
                ? AppColors.darkDivider.withValues(alpha: 0.4)
                : AppColors.divider.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            color: isDarkMode
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CashFlowSummary extends StatelessWidget {
  final double income;
  final double expense;
  final String periodLabel;
  final bool isDarkMode;
  final bool hidePeriodSelector;
  final VoidCallback? onSelectPeriod;

  const _CashFlowSummary({
    required this.income,
    required this.expense,
    required this.periodLabel,
    required this.isDarkMode,
    required this.hidePeriodSelector,
    required this.onSelectPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final surface = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;
    final net = income - expense;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: isDarkMode
              ? AppColors.darkDivider.withValues(alpha: 0.4)
              : AppColors.divider.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'กระแสเงินสด',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!hidePeriodSelector)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: onSelectPeriod,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  label: Text(periodLabel),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryAmount(
                  label: 'รายรับ',
                  amount: income,
                  color: incomeColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryAmount(
                  label: 'รายจ่าย',
                  amount: expense,
                  color: expenseColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'สุทธิ',
                style: TextStyle(color: textSecondary, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Text(
                '${net < 0 ? '-' : ''}฿ ${formatAmount(net.abs())}',
                style: TextStyle(
                  color: AppColors.getAmountColor(net, isDarkMode),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryAmount extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryAmount({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '฿ ${formatAmount(amount)}',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionTypeTabs extends StatelessWidget {
  final _TransactionTypeFilter selected;
  final bool isDarkMode;
  final ValueChanged<_TransactionTypeFilter> onChanged;

  const _TransactionTypeTabs({
    required this.selected,
    required this.isDarkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final selectedSurface = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.sectionHeader;
    final primary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        side: BorderSide(
          color: isDarkMode
              ? AppColors.darkDivider.withValues(alpha: 0.4)
              : AppColors.divider.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: _TransactionTypeFilter.values.map((value) {
            final isSelected = selected == value;
            return Expanded(
              child: Material(
                color: isSelected ? selectedSurface : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.large),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      value.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? primary : secondary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
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
  thisYear('ปีนี้'),
  oneYear('1 ปี');

  final String label;
  const _PeriodFilter(this.label);

  String get shortLabel => switch (this) {
    _PeriodFilter.all => 'ทั้งหมด',
    _PeriodFilter.last30Days => '30 วัน',
    _PeriodFilter.last90Days => '90 วัน',
    _PeriodFilter.last180Days => '180 วัน',
    _PeriodFilter.thisMonth => 'เดือนนี้',
    _PeriodFilter.lastMonth => 'เดือนก่อน',
    _PeriodFilter.thisYear => 'ปีนี้',
    _PeriodFilter.oneYear => '1 ปี',
  };
}

enum _TransactionTypeFilter {
  all('ทั้งหมด'),
  income('รายรับ'),
  expense('รายจ่าย');

  final String label;
  const _TransactionTypeFilter(this.label);
}

String _formatMonthYear(DateTime date) {
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
  return '${thaiMonths[date.month - 1]} ${date.year}';
}

String _formatMonthShort(DateTime date) {
  const thaiMonths = [
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
  return thaiMonths[date.month - 1];
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
  final dayOfWeek = thaiDays[date.weekday - 1];
  return '${date.day} ${thaiMonths[date.month - 1]} ${date.year} · $dayOfWeek';
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
    final subLabel = _buildSubLabel(category?.name, note);
    final amountColor =
        (tx.type == TransactionType.transfer && viewingAccountId == null)
        ? (isDarkMode ? AppColors.darkTransfer : AppColors.transfer)
        : (tx.type == TransactionType.debtRepay && viewingAccountId == null)
        ? (isDarkMode ? AppColors.darkExpense : AppColors.expense)
        : (tx.type == TransactionType.debtTransfer && viewingAccountId == null)
        ? (isDarkMode ? AppColors.darkDebtTransfer : AppColors.debtTransfer)
        : AppColors.getAmountColor(displayAmount, isDarkMode);
    final amountText =
        (tx.type == TransactionType.transfer && viewingAccountId == null)
        ? '฿ ${formatAmount(tx.amount)}${account?.currency == 'THB' ? '' : ' ${account?.currency ?? ''}'}'
        : '${displayAmount < 0
              ? '-'
              : displayAmount > 0
              ? '+'
              : ''}฿ ${formatAmount(displayAmount.abs())}${currency == 'THB' ? '' : ' ${currency ?? ''}'}';

    return InkWell(
      onTap: onTap,
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (category?.color ?? typeColor).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              child: Icon(
                tx.type == TransactionType.debtTransfer
                    ? Icons.account_tree
                    : tx.type == TransactionType.transfer
                    ? Icons.swap_horiz
                    : tx.type == TransactionType.debtRepay
                    ? Icons.payment
                    : (category?.icon ?? Icons.receipt),
                color: category?.color ?? typeColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAccountWidget(
                    account,
                    toAccount,
                    tx,
                    textPrimaryColor,
                    isDarkMode,
                  ),
                  if (subLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subLabel,
                      style: TextStyle(fontSize: 13, color: textSecondaryColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(tx.dateTime),
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
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
