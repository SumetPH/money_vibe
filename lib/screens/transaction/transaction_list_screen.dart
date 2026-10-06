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
import '../../widgets/monthly_cycle_selector.dart';
import '../../utils/monthly_cycle.dart';
import 'transaction_form_screen.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_segmented_tabs.dart';
import '../../widgets/app_date_picker_sheet.dart';
import 'transaction_list_models.dart';
import 'transaction_cash_flow_summary.dart';
import 'transaction_list_item.dart';
import 'transaction_period_picker_sheet.dart';

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
  TransactionPeriodFilter _filter = TransactionPeriodFilter.all;
  TransactionTypeFilter _typeFilter = TransactionTypeFilter.all;
  String _searchQuery = '';
  DateTime? _selectedCycleMonth;
  DateTimeRange? _customRange;

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
                leading: isFiltered ? const AppBackButton() : null,
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
                  TransactionListHeaderAction(
                    icon: Icons.add,
                    onTap: _openAddTransactionForm,
                    isDarkMode: isDarkMode,
                  ),
                  TransactionListHeaderAction(
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
                      child: TransactionCashFlowSummary(
                        income: summaryData.totalIncome,
                        expense: summaryData.totalExpense,
                        periodLabel: _periodShortLabel(),
                        isDarkMode: isDarkMode,
                        hidePeriodSelector: _selectedCycleMonth != null,
                        onSelectPeriod:
                            widget.fixedDateRange == null &&
                                widget.transactionIds == null
                            ? () => showTransactionPeriodPicker(
                                this.context,
                                isDarkMode,
                                selected: _filter,
                                customRange: _customRange,
                                onPickCustomRange: _pickCustomRange,
                                onSelected: (f) => setState(() => _filter = f),
                              )
                            : null,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverToBoxAdapter(
                      child: AppSegmentedTabs(
                        segments: [
                          for (final value in TransactionTypeFilter.values)
                            AppSegment(
                              label: value.label,
                              isSelected: _typeFilter == value,
                              onTap: () => setState(() => _typeFilter = value),
                            ),
                        ],
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
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
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
                                          formatTransactionDate(group.date),
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
                                            TransactionListItem(
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
      TransactionTypeFilter.all => true,
      TransactionTypeFilter.income =>
        tx.type == TransactionType.income || tx.type.isIncreaseBalance,
      TransactionTypeFilter.expense =>
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
      TransactionPeriodFilter.thisMonth => formatTransactionMonthYear(now),
      TransactionPeriodFilter.lastMonth => formatTransactionMonthYear(
        DateTime(now.year, now.month - 1),
      ),
      TransactionPeriodFilter.thisYear => 'ปี ${now.year}',
      TransactionPeriodFilter.custom when _customRange != null =>
        formatTransactionRange(_customRange!, withYear: true),
      _ => _filter.label,
    };
  }

  String _periodShortLabel() {
    final now = DateTime.now();
    return switch (_filter) {
      TransactionPeriodFilter.thisMonth => formatTransactionMonthShort(now),
      TransactionPeriodFilter.lastMonth => formatTransactionMonthShort(
        DateTime(now.year, now.month - 1),
      ),
      TransactionPeriodFilter.custom when _customRange != null =>
        formatTransactionRange(_customRange!, withYear: false),
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
        case TransactionPeriodFilter.all:
          transactions = List.of(provider.transactions)
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
        case TransactionPeriodFilter.last30Days:
          final from = now.subtract(const Duration(days: 30));
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
        case TransactionPeriodFilter.last90Days:
          final from = now.subtract(const Duration(days: 90));
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
        case TransactionPeriodFilter.last180Days:
          final from = now.subtract(const Duration(days: 180));
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
        case TransactionPeriodFilter.thisMonth:
          final from = DateTime(now.year, now.month, 1);
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
        case TransactionPeriodFilter.lastMonth:
          final from = DateTime(now.year, now.month - 1, 1);
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
        case TransactionPeriodFilter.thisYear:
          final from = DateTime(now.year, 1, 1);
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
        case TransactionPeriodFilter.oneYear:
          final from = DateTime(now.year - 1, now.month, now.day);
          transactions = provider.getTransactionsForPeriod(
            from,
            DateTime(9999),
          );
        case TransactionPeriodFilter.custom:
          final range = _customRange;
          transactions = range == null
              ? (List.of(provider.transactions)
                  ..sort((a, b) => b.dateTime.compareTo(a.dateTime)))
              : provider.getTransactionsForPeriod(range.start, range.end);
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

  TransactionListData _buildTransactionListData(
    List<AppTransaction> txs,
    AccountProvider accountProvider,
  ) {
    final accounts = accountProvider.accounts;
    final accountsById = {for (final account in accounts) account.id: account};
    final grouped = <DateTime, TransactionMutableTransactionDateGroup>{};
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
        () => TransactionMutableTransactionDateGroup(date),
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
      return TransactionDateGroup(
        date: group.date,
        transactions: group.transactions,
        income: group.income,
        expense: group.expense,
      );
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    return TransactionListData(
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

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showAppDateRangePicker(
      context: context,
      initialRange:
          _customRange ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: today),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _filter = TransactionPeriodFilter.custom;
      _customRange = picked;
    });
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
