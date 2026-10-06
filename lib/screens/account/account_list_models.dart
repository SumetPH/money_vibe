import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../providers/account_provider.dart';

AccountTotals buildAccountTotals({
  required AccountProvider accountProvider,
  required List<Account> allAccounts,
  required List<Account> visibleAccounts,
  required List<AppTransaction> transactions,
  Set<String>? filterIds,
}) {
  final accountsById = {for (final account in allAccounts) account.id: account};
  final balancesByAccountId = <String, double>{};

  for (final account in allAccounts) {
    balancesByAccountId[account.id] = account.isPortfolio
        ? accountProvider.getBalance(account.id, const [])
        : account.initialBalance;
  }

  for (final tx in transactions) {
    final fromAccount = accountsById[tx.accountId];
    if (fromAccount != null && !fromAccount.isPortfolio) {
      final current = balancesByAccountId[tx.accountId] ?? 0;
      final delta =
          tx.type == TransactionType.income ||
              tx.type == TransactionType.increaseBalance
          ? tx.amount
          : -tx.amount;
      balancesByAccountId[tx.accountId] = current + delta;
    }

    final toAccountId = tx.toAccountId;
    if (toAccountId != null && tx.type.usesDestinationAccount) {
      final toAccount = accountsById[toAccountId];
      if (toAccount != null && !toAccount.isPortfolio) {
        balancesByAccountId[toAccountId] =
            (balancesByAccountId[toAccountId] ?? 0) +
            (tx.toAmount ?? tx.amount);
      }
    }
  }

  double toThb(Account account) {
    final balance = balancesByAccountId[account.id] ?? 0;
    return account.currency == 'USD' ? balance * account.exchangeRate : balance;
  }

  final groupTotals = <String, double>{};
  for (final account in visibleAccounts) {
    final group = accountTypeDisplayGroup(account.type);
    groupTotals[group] = (groupTotals[group] ?? 0) + toThb(account);
  }

  var netWorth = 0.0;
  for (final account in allAccounts) {
    if (account.excludeFromNetWorth) continue;
    if (filterIds != null && !filterIds.contains(account.id)) continue;
    netWorth += toThb(account);
  }

  return AccountTotals(
    balancesByAccountId: balancesByAccountId,
    groupTotals: groupTotals,
    netWorth: netWorth,
  );
}

class AccountTotals {
  final Map<String, double> balancesByAccountId;
  final Map<String, double> groupTotals;
  final double netWorth;

  const AccountTotals({
    required this.balancesByAccountId,
    required this.groupTotals,
    required this.netWorth,
  });
}
