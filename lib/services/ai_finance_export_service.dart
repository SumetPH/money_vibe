import 'package:intl/intl.dart';

import '../models/account.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../providers/account_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';

enum AiFinanceExportScope {
  overview('ภาพรวมทั้งหมด'),
  accounts('บัญชีและเงินสด'),
  monthlyCashflow('รายรับรายจ่าย/งบเดือนนี้');

  final String label;
  const AiFinanceExportScope(this.label);
}

class AiFinanceExportService {
  AiFinanceExportService._();

  static final AiFinanceExportService instance = AiFinanceExportService._();

  static final _amountFormatter = NumberFormat('#,##0.00', 'en_US');
  static final _dateFormatter = DateFormat('yyyy-MM-dd');
  static final _monthFormatter = DateFormat('yyyy-MM');

  String buildMarkdown({
    required AiFinanceExportScope scope,
    required AccountProvider accountProvider,
    required TransactionProvider transactionProvider,
    required CategoryProvider categoryProvider,
    required BudgetProvider budgetProvider,
    DateTime? now,
  }) {
    final generatedAt = now ?? DateTime.now();
    final accounts = accountProvider.visibleAccounts;
    final transactions = transactionProvider.transactions;
    final monthStart = DateTime(generatedAt.year, generatedAt.month);
    final nextMonth = DateTime(generatedAt.year, generatedAt.month + 1);
    final monthTransactions = transactions
        .where(
          (tx) =>
              !tx.dateTime.isBefore(monthStart) &&
              tx.dateTime.isBefore(nextMonth),
        )
        .toList();

    final lines = <String>[
      '# Money Vibe Finance Snapshot',
      '',
      '- Generated at: ${_dateFormatter.format(generatedAt)}',
      '- Scope: ${scope.label}',
      '- Period: ${_monthFormatter.format(monthStart)}',
      '- Privacy: transaction notes and raw IDs are excluded',
      '',
    ];

    switch (scope) {
      case AiFinanceExportScope.overview:
        _appendNetWorth(lines, accountProvider, transactions, accounts);
        _appendAccounts(lines, accountProvider, transactions, accounts);
        _appendMonthlyCashflow(
          lines,
          accountProvider,
          transactionProvider,
          categoryProvider,
          monthTransactions,
        );
        _appendBudgets(
          lines,
          budgetProvider,
          categoryProvider,
          monthTransactions,
        );
        _appendPortfolio(lines, accountProvider, accounts);
      case AiFinanceExportScope.accounts:
        _appendNetWorth(lines, accountProvider, transactions, accounts);
        _appendAccounts(lines, accountProvider, transactions, accounts);
        _appendPortfolio(lines, accountProvider, accounts);
      case AiFinanceExportScope.monthlyCashflow:
        _appendMonthlyCashflow(
          lines,
          accountProvider,
          transactionProvider,
          categoryProvider,
          monthTransactions,
        );
        _appendBudgets(
          lines,
          budgetProvider,
          categoryProvider,
          monthTransactions,
        );
    }

    return lines.join('\n').trimRight();
  }

  void _appendNetWorth(
    List<String> lines,
    AccountProvider accountProvider,
    List<AppTransaction> transactions,
    List<Account> accounts,
  ) {
    final assets = accounts.where((account) => account.type.group.isAsset).fold(
      0.0,
      (sum, account) {
        if (account.excludeFromNetWorth) return sum;
        return sum + accountProvider.getBalanceInThb(account.id, transactions);
      },
    );
    final liabilities = accounts
        .where((account) => !account.type.group.isAsset)
        .fold(0.0, (sum, account) {
          if (account.excludeFromNetWorth) return sum;
          return sum +
              accountProvider.getBalanceInThb(account.id, transactions);
        });
    final netWorth = assets + liabilities;

    lines
      ..add('## Net Worth')
      ..add('')
      ..add('- Total net worth: ${_money(netWorth, 'THB')}')
      ..add('- Assets: ${_money(assets, 'THB')}')
      ..add('- Liabilities: ${_money(liabilities, 'THB')}')
      ..add('');
  }

  void _appendAccounts(
    List<String> lines,
    AccountProvider accountProvider,
    List<AppTransaction> transactions,
    List<Account> accounts,
  ) {
    lines
      ..add('## Accounts')
      ..add('')
      ..add('| Group | Account | Currency | Balance | THB Value | Flags |')
      ..add('| --- | --- | --- | ---: | ---: | --- |');

    for (final account in accounts) {
      final balance = accountProvider.getBalance(account.id, transactions);
      final thbValue = accountProvider.getBalanceInThb(
        account.id,
        transactions,
      );
      final flags = <String>[
        if (account.excludeFromNetWorth) 'excluded from net worth',
        if (account.isHidden) 'hidden',
      ].join(', ');

      lines.add(
        '| ${account.type.group.label} | ${_cell(account.name)} | '
        '${account.currency} | ${_money(balance, account.currency)} | '
        '${_money(thbValue, 'THB')} | ${flags.isEmpty ? '-' : flags} |',
      );
    }

    lines.add('');
  }

  void _appendMonthlyCashflow(
    List<String> lines,
    AccountProvider accountProvider,
    TransactionProvider transactionProvider,
    CategoryProvider categoryProvider,
    List<AppTransaction> monthTransactions,
  ) {
    final accounts = accountProvider.accounts;
    final income = transactionProvider.getTotalIncome(monthTransactions);
    final expense = transactionProvider.getTotalActualExpense(
      monthTransactions,
      accounts,
    );
    final net = income - expense;

    lines
      ..add('## Monthly Cashflow')
      ..add('')
      ..add('- Income: ${_money(income, 'THB')}')
      ..add('- Actual expense: ${_money(expense, 'THB')}')
      ..add('- Net cashflow: ${_money(net, 'THB')}')
      ..add('- Transaction count: ${monthTransactions.length}')
      ..add('');

    final categoryTotals = <String, double>{};
    for (final tx in monthTransactions) {
      if (!TransactionProvider.isActualExpense(tx, accounts)) continue;
      final categoryName = tx.categoryId == null
          ? 'ไม่ระบุหมวดหมู่'
          : categoryProvider.findById(tx.categoryId!)?.name ??
                'ไม่ระบุหมวดหมู่';
      categoryTotals[categoryName] =
          (categoryTotals[categoryName] ?? 0) + tx.amount;
    }

    if (categoryTotals.isEmpty) {
      lines
        ..add('### Top Expense Categories')
        ..add('')
        ..add('- No expense data this month.')
        ..add('');
      return;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    lines
      ..add('### Top Expense Categories')
      ..add('')
      ..add('| Category | Amount | Share |')
      ..add('| --- | ---: | ---: |');

    for (final entry in sortedCategories.take(8)) {
      final share = expense == 0 ? 0 : entry.value / expense * 100;
      lines.add(
        '| ${_cell(entry.key)} | ${_money(entry.value, 'THB')} | '
        '${share.toStringAsFixed(1)}% |',
      );
    }

    lines.add('');
  }

  void _appendBudgets(
    List<String> lines,
    BudgetProvider budgetProvider,
    CategoryProvider categoryProvider,
    List<AppTransaction> monthTransactions,
  ) {
    final budgets = budgetProvider.budgets;

    lines
      ..add('## Budgets')
      ..add('');

    if (budgets.isEmpty) {
      lines
        ..add('- No budgets configured.')
        ..add('');
      return;
    }

    lines
      ..add('| Budget | Type | Limit | Used | Remaining | Categories |')
      ..add('| --- | --- | ---: | ---: | ---: | --- |');

    for (final budget in budgets) {
      final used = _budgetUsed(budget, monthTransactions);
      final remaining = budget.amount - used;
      final categories = budget.categoryIds
          .map((id) => categoryProvider.findById(id)?.name)
          .whereType<String>()
          .join(', ');

      lines.add(
        '| ${_cell(budget.name)} | ${budget.type.label} | '
        '${_money(budget.amount, 'THB')} | ${_money(used, 'THB')} | '
        '${_money(remaining, 'THB')} | '
        '${categories.isEmpty ? '-' : _cell(categories)} |',
      );
    }

    lines.add('');
  }

  void _appendPortfolio(
    List<String> lines,
    AccountProvider accountProvider,
    List<Account> accounts,
  ) {
    final portfolios = accounts
        .where((account) => account.type == AccountType.portfolio)
        .toList();

    if (portfolios.isEmpty) return;

    lines
      ..add('## Portfolios')
      ..add('')
      ..add(
        '| Portfolio | Cash USD | Holdings USD | Unrealized P/L USD | Top Holdings |',
      )
      ..add('| --- | ---: | ---: | ---: | --- |');

    for (final portfolio in portfolios) {
      final holdings = accountProvider.getHoldings(portfolio.id);
      final holdingsValue = holdings.fold(
        0.0,
        (sum, holding) => sum + holding.valueUsd,
      );
      final unrealizedPnl = holdings.fold(
        0.0,
        (sum, holding) => sum + holding.unrealizedPnlUsd,
      );
      final topHoldings = holdings.toList()
        ..sort((a, b) => b.valueUsd.compareTo(a.valueUsd));
      final topHoldingText = topHoldings
          .take(5)
          .map(
            (holding) => '${holding.ticker} ${_money(holding.valueUsd, 'USD')}',
          )
          .join(', ');

      lines.add(
        '| ${_cell(portfolio.name)} | ${_money(portfolio.cashBalance, 'USD')} | '
        '${_money(holdingsValue, 'USD')} | ${_money(unrealizedPnl, 'USD')} | '
        '${topHoldingText.isEmpty ? '-' : _cell(topHoldingText)} |',
      );
    }

    lines.add('');
  }

  double _budgetUsed(Budget budget, List<AppTransaction> monthTransactions) {
    if (budget.categoryIds.isEmpty) return 0;
    final categoryIds = budget.categoryIds.toSet();

    return monthTransactions
        .where((tx) {
          if (tx.categoryId == null || !categoryIds.contains(tx.categoryId)) {
            return false;
          }
          if (budget.type == BudgetType.expense) {
            return tx.type.isExpenseLike;
          }
          return tx.type == TransactionType.income ||
              tx.type == TransactionType.increaseBalance;
        })
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  String _money(double amount, String currency) {
    final cleanAmount = amount.abs() < 0.005 ? 0.0 : amount;
    return '${_amountFormatter.format(cleanAmount)} $currency';
  }

  String _cell(String value) {
    return value
        .replaceAll('|', '/')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .trim();
  }
}
