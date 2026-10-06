import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import 'statistics_models.dart';

List<StatisticsNetWorthData> calculateNetWorthData(
  List<AppTransaction> transactions,
  List<Account> accounts,
  AccountProvider accountProvider, {
  bool includeExcluded = false,
}) {
  final effectiveAccounts = includeExcluded
      ? accounts
      : accounts.where((a) => !a.excludeFromNetWorth).toList();
  if (effectiveAccounts.isEmpty) return [];

  DateTime monthStart(DateTime dt) => DateTime(dt.year, dt.month);
  final effectiveAccountsById = {
    for (final account in effectiveAccounts) account.id: account,
  };
  final effectiveAccountIds = effectiveAccounts.map((a) => a.id).toSet();
  final relevantTransactions = transactions.where((tx) {
    final fromIncluded = effectiveAccountIds.contains(tx.accountId);
    final toIncluded =
        tx.toAccountId != null && effectiveAccountIds.contains(tx.toAccountId);
    return fromIncluded || toIncluded;
  }).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  final monthKeys = <DateTime>{
    for (final account in effectiveAccounts) monthStart(account.startDate),
    for (final tx in relevantTransactions) monthStart(tx.dateTime),
  };
  if (monthKeys.isEmpty) return [];

  final sortedMonthKeys = monthKeys.toList()..sort((a, b) => a.compareTo(b));
  final firstMonth = sortedMonthKeys.first;
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month);
  final allAccountsById = {for (final account in accounts) account.id: account};
  final balancesByAccountId = <String, double>{};
  for (final account in effectiveAccounts) {
    balancesByAccountId[account.id] = account.isPortfolio
        ? _portfolioOpeningBalance(
            account,
            accountProvider,
            relevantTransactions,
            allAccountsById,
            now,
          )
        : account.initialBalance;
  }

  final result = <StatisticsNetWorthData>[];
  var txIndex = 0;
  for (
    var month = firstMonth;
    !month.isAfter(currentMonth);
    month = DateTime(month.year, month.month + 1)
  ) {
    final isCurrentMonth =
        month.year == currentMonth.year && month.month == currentMonth.month;
    final snapshotDate = isCurrentMonth
        ? now
        : DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
    while (txIndex < relevantTransactions.length &&
        !relevantTransactions[txIndex].dateTime.isAfter(snapshotDate)) {
      _applyBalanceDelta(
        relevantTransactions[txIndex],
        effectiveAccountsById,
        allAccountsById,
        balancesByAccountId,
      );
      txIndex++;
    }

    var netWorth = 0.0;
    for (final account in effectiveAccounts) {
      if (account.startDate.isAfter(snapshotDate)) continue;
      final balance = balancesByAccountId[account.id] ?? 0.0;
      netWorth += account.currency == 'USD'
          ? balance * account.exchangeRate
          : balance;
    }

    result.add(StatisticsNetWorthData(date: snapshotDate, netWorth: netWorth));
  }

  return result;
}

/// Portfolio has no transaction history of its value, so back-calculate the
/// opening balance from the current value minus net flows up to now. This
/// keeps transfers in/out of a portfolio net-zero on the chart.
double _portfolioOpeningBalance(
  Account portfolio,
  AccountProvider accountProvider,
  List<AppTransaction> transactions,
  Map<String, Account> allAccountsById,
  DateTime now,
) {
  final currentValue = accountProvider.getBalance(
    portfolio.id,
    const <AppTransaction>[],
  );
  final netFlow = transactions
      .where((tx) => !tx.dateTime.isAfter(now))
      .fold(
        0.0,
        (sum, tx) => sum + _accountDelta(tx, portfolio.id, allAccountsById),
      );
  return currentValue - netFlow;
}

void _applyBalanceDelta(
  AppTransaction tx,
  Map<String, Account> effectiveAccountsById,
  Map<String, Account> allAccountsById,
  Map<String, double> balancesByAccountId,
) {
  final touchedIds = {tx.accountId, ?tx.toAccountId};
  for (final accountId in touchedIds) {
    if (!effectiveAccountsById.containsKey(accountId)) continue;
    balancesByAccountId[accountId] =
        (balancesByAccountId[accountId] ?? 0.0) +
        _accountDelta(tx, accountId, allAccountsById);
  }
}

/// Balance change of [accountId] caused by [tx], in the account's currency.
double _accountDelta(
  AppTransaction tx,
  String accountId,
  Map<String, Account> allAccountsById,
) {
  var delta = 0.0;
  if (tx.accountId == accountId) {
    final isIncreasing =
        tx.type == TransactionType.income ||
        tx.type == TransactionType.increaseBalance;
    delta += isIncreasing ? tx.amount : -tx.amount;
  }
  if (tx.toAccountId == accountId && tx.type.usesDestinationAccount) {
    delta += _destinationAmount(tx, allAccountsById);
  }
  return delta;
}

double _destinationAmount(
  AppTransaction tx,
  Map<String, Account> allAccountsById,
) {
  final toAmount = tx.toAmount;
  if (toAmount != null) return toAmount;

  // Legacy cross-currency rows have no toAmount. Regular accounts keep the
  // raw amount (same as getBalance); portfolios convert so the
  // back-calculated history is not inflated by the wrong currency.
  final from = allAccountsById[tx.accountId];
  final to = allAccountsById[tx.toAccountId];
  if (from == null || to == null || !to.isPortfolio) return tx.amount;
  if (from.currency == to.currency) return tx.amount;

  final amountInThb = from.currency == 'USD'
      ? tx.amount * from.exchangeRate
      : tx.amount;
  return to.currency == 'USD' ? amountInThb / to.exchangeRate : amountInThb;
}

List<StatisticsNetWorthData> filterNetWorthData(
  List<StatisticsNetWorthData> data,
  StatisticsNetWorthPeriodFilter filter,
) {
  if (data.isEmpty || filter == StatisticsNetWorthPeriodFilter.all) {
    return data;
  }

  final now = DateTime.now();
  DateTime cutoff;

  switch (filter) {
    case StatisticsNetWorthPeriodFilter.threeMonths:
      cutoff = DateTime(now.year, now.month - 2, 1);
      break;
    case StatisticsNetWorthPeriodFilter.sixMonths:
      cutoff = DateTime(now.year, now.month - 5, 1);
      break;
    case StatisticsNetWorthPeriodFilter.oneYear:
      cutoff = DateTime(now.year, now.month - 11, 1);
      break;
    case StatisticsNetWorthPeriodFilter.thisYear:
      cutoff = DateTime(now.year, 1, 1);
      break;
    case StatisticsNetWorthPeriodFilter.all:
      return data;
  }

  return data
      .where((d) => d.date.isAfter(cutoff) || d.date.isAtSameMomentAs(cutoff))
      .toList();
}
