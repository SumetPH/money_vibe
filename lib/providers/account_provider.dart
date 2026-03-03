import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/stock_holding.dart';
import '../models/transaction.dart';

class AccountProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final _db = DatabaseHelper.instance;

  final List<Account> _accounts = [];
  final Map<String, List<StockHolding>> _holdings =
      {}; // portfolioId → holdings

  bool _showHiddenAccounts = false;

  bool get showHiddenAccounts => _showHiddenAccounts;

  void toggleShowHiddenAccounts() {
    _showHiddenAccounts = !_showHiddenAccounts;
    notifyListeners();
  }

  // ── Seed data (used only on first launch) ─────────────────────────────────

  // static List<Account> get _seedAccounts => [
  //   Account(
  //     id: 'acc_cash',
  //     name: 'เงินสด',
  //     type: AccountType.cash,
  //     initialBalance: 970,
  //     icon: Icons.account_balance_wallet,
  //     color: const Color(0xFF8D6E63),
  //   ),
  //   Account(
  //     id: 'acc_kbank_main',
  //     name: 'KBank Main',
  //     type: AccountType.bankAccount,
  //     initialBalance: 500,
  //     icon: Icons.account_balance,
  //     color: const Color(0xFF4CAF50),
  //   ),
  //   Account(
  //     id: 'acc_ktb_main',
  //     name: 'KTB Main',
  //     type: AccountType.bankAccount,
  //     initialBalance: 883.64,
  //     icon: Icons.account_balance,
  //     color: const Color(0xFF2196F3),
  //   ),
  //   Account(
  //     id: 'acc_ktb_saving',
  //     name: 'KTB Saving',
  //     type: AccountType.bankAccount,
  //     initialBalance: 19000,
  //     icon: Icons.savings,
  //     color: const Color(0xFF03A9F4),
  //   ),
  //   Account(
  //     id: 'acc_ktc_mc',
  //     name: 'KTC Mastercard',
  //     type: AccountType.creditCard,
  //     initialBalance: -1356.75,
  //     icon: Icons.credit_card,
  //     color: const Color(0xFFFF5722),
  //   ),
  //   Account(
  //     id: 'acc_kbank_visa',
  //     name: 'KBank Visa',
  //     type: AccountType.creditCard,
  //     initialBalance: -738.41,
  //     icon: Icons.credit_card,
  //     color: const Color(0xFF1565C0),
  //   ),
  //   Account(
  //     id: 'acc_car',
  //     name: 'รถยนต์',
  //     type: AccountType.debt,
  //     initialBalance: -146036,
  //     icon: Icons.directions_car,
  //     color: const Color(0xFF607D8B),
  //   ),
  //   Account(
  //     id: 'acc_car_ins',
  //     name: 'ประกันรถยนต์ 2569',
  //     type: AccountType.debt,
  //     initialBalance: -5498.42,
  //     icon: Icons.shield,
  //     color: const Color(0xFF78909C),
  //   ),
  //   Account(
  //     id: 'acc_chair',
  //     name: 'เก้าอี้',
  //     type: AccountType.debt,
  //     initialBalance: -1824,
  //     icon: Icons.weekend,
  //     color: const Color(0xFF795548),
  //   ),
  //   Account(
  //     id: 'acc_iphone',
  //     name: 'iPhone 16',
  //     type: AccountType.debt,
  //     initialBalance: -19728,
  //     icon: Icons.phone_iphone,
  //     color: const Color(0xFF9E9E9E),
  //   ),
  //   Account(
  //     id: 'acc_invest',
  //     name: 'กองทุนรวม',
  //     type: AccountType.investment,
  //     initialBalance: 100000,
  //     icon: Icons.show_chart,
  //     color: const Color(0xFF009688),
  //   ),
  //   Account(
  //     id: 'acc_ibkr',
  //     name: 'IBKR Portfolio',
  //     type: AccountType.portfolio,
  //     cashBalance: 5000,
  //     exchangeRate: 35.0,
  //     icon: Icons.candlestick_chart,
  //     color: const Color(0xFF1565C0),
  //   ),
  // ];

  // static List<StockHolding> get _seedHoldings => [
  //   StockHolding(
  //     id: 'h_aapl',
  //     portfolioId: 'acc_ibkr',
  //     ticker: 'AAPL',
  //     name: 'Apple Inc.',
  //     shares: 10,
  //     priceUsd: 185.0,
  //     costBasisUsd: 170.0,
  //     sortOrder: 0,
  //   ),
  //   StockHolding(
  //     id: 'h_msft',
  //     portfolioId: 'acc_ibkr',
  //     ticker: 'MSFT',
  //     name: 'Microsoft Corp.',
  //     shares: 5,
  //     priceUsd: 415.0,
  //     costBasisUsd: 390.0,
  //     sortOrder: 1,
  //   ),
  // ];

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final rows = await _db.getAccounts();
    if (rows.isEmpty) {
      // final seeds = _seedAccounts;
      // for (final acc in seeds) {
      //   await _db.insertAccount(acc.toMap());
      // }
      // _accounts.addAll(seeds);

      // // Seed holdings
      // for (final h in _seedHoldings) {
      //   await _db.insertHolding(h.toMap());
      //   _holdings.putIfAbsent(h.portfolioId, () => []).add(h);
      // }
    } else {
      _accounts.addAll(rows.map(Account.fromMap));

      final holdingRows = await _db.getPortfolioHoldings();
      for (final row in holdingRows) {
        final h = StockHolding.fromMap(row);
        _holdings.putIfAbsent(h.portfolioId, () => []).add(h);
      }
    }
  }

  /// Reload accounts from database (used after restore)
  Future<void> reload() async {
    debugPrint('AccountProvider: Reloading...');
    _accounts.clear();
    _holdings.clear();
    try {
      final rows = await _db.getAccounts();
      debugPrint('AccountProvider: Loaded ${rows.length} accounts from DB');
      for (final row in rows) {
        try {
          _accounts.add(Account.fromMap(row));
        } catch (e) {
          debugPrint('AccountProvider: Error parsing account: $e');
          debugPrint('AccountProvider: Account data: $row');
        }
      }
      final holdingRows = await _db.getPortfolioHoldings();
      debugPrint(
        'AccountProvider: Loaded ${holdingRows.length} holdings from DB',
      );
      for (final row in holdingRows) {
        try {
          final h = StockHolding.fromMap(row);
          _holdings.putIfAbsent(h.portfolioId, () => []).add(h);
        } catch (e) {
          debugPrint('AccountProvider: Error parsing holding: $e');
          debugPrint('AccountProvider: Holding data: $row');
        }
      }
      notifyListeners();
      debugPrint('AccountProvider: Reload complete');
    } catch (e) {
      debugPrint('AccountProvider: Reload failed: $e');
      rethrow;
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  List<Account> get accounts => List.unmodifiable(_accounts);

  List<Account> get visibleAccounts {
    if (_showHiddenAccounts) {
      return List.unmodifiable(_accounts);
    }
    return _accounts.where((a) => !a.isHidden).toList();
  }

  List<Account> get debtAccounts => _accounts
      .where(
        (a) =>
            (a.type == AccountType.debt || a.type == AccountType.creditCard) &&
            !a.isHidden,
      )
      .toList();

  Account? findById(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  List<StockHolding> getHoldings(String portfolioId) =>
      List.unmodifiable(_holdings[portfolioId] ?? []);

  // ── Balance computation ───────────────────────────────────────────────────

  double getBalance(String accountId, List<AppTransaction> transactions) {
    final account = findById(accountId);
    if (account == null) return 0;

    // Portfolio: balance = (cashBalance in USD * exchangeRate) + sum of holdings value in THB
    if (account.type == AccountType.portfolio) {
      double total = account.cashBalance * account.exchangeRate;
      for (final h in (_holdings[accountId] ?? [])) {
        total += h.shares * h.priceUsd * account.exchangeRate;
      }
      return total;
    }

    // Regular accounts: computed from transactions
    double balance = account.initialBalance;
    for (final tx in transactions) {
      if (tx.accountId == accountId) {
        if (tx.type == TransactionType.income) balance += tx.amount;
        if (tx.type == TransactionType.expense) balance -= tx.amount;
        if (tx.type == TransactionType.transfer) balance -= tx.amount;
        if (tx.type == TransactionType.debtRepay) balance -= tx.amount;
      }
      if (tx.toAccountId == accountId &&
          (tx.type == TransactionType.transfer ||
              tx.type == TransactionType.debtRepay)) {
        balance += tx.amount;
      }
    }
    return balance;
  }

  double getTotalNetWorth(List<AppTransaction> transactions) {
    return _accounts
        .where(
          (a) => !a.excludeFromNetWorth && (_showHiddenAccounts || !a.isHidden),
        )
        .fold(0.0, (sum, a) => sum + getBalance(a.id, transactions));
  }

  Map<String, double> getGroupTotals(List<AppTransaction> transactions) {
    final Map<String, double> totals = {};
    final accountsToShow = _showHiddenAccounts
        ? _accounts
        : _accounts.where((a) => !a.isHidden);
    for (final account in accountsToShow) {
      final group = accountTypeDisplayGroup(account.type);
      totals[group] =
          (totals[group] ?? 0) + getBalance(account.id, transactions);
    }
    return totals;
  }

  // ── Account CRUD ──────────────────────────────────────────────────────────

  void addAccount(Account account) {
    _accounts.add(account);
    notifyListeners();
    _db.insertAccount(account.toMap());
  }

  void updateAccount(Account updated) {
    final idx = _accounts.indexWhere((a) => a.id == updated.id);
    if (idx != -1) {
      _accounts[idx] = updated;
      notifyListeners();
      _db.updateAccount(updated.toMap());
    }
  }

  void deleteAccount(String id) {
    _accounts.removeWhere((a) => a.id == id);
    _holdings.remove(id);
    notifyListeners();
    _db.deleteAccount(id);
    _db.deleteHoldingsByPortfolio(id);
  }

  void reorderAccounts(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final account = _accounts.removeAt(oldIndex);
    _accounts.insert(newIndex, account);

    // Update sort order for all affected accounts
    for (int i = 0; i < _accounts.length; i++) {
      _accounts[i] = _accounts[i].copyWith(sortOrder: i);
      _db.updateAccountSortOrder(_accounts[i].id, i);
    }

    notifyListeners();
  }

  void reorderAccountsInGroup(String groupName, int oldIndex, int newIndex) {
    // Get visible accounts
    final visible = visibleAccounts;

    // Get accounts in this group
    final groupAccounts = visible
        .where((a) => accountTypeDisplayGroup(a.type) == groupName)
        .toList();

    if (groupAccounts.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= groupAccounts.length) return;

    // Adjust newIndex for ReorderableListView behavior
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // Clamp to valid range
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= groupAccounts.length) newIndex = groupAccounts.length - 1;

    // If same position, nothing to do
    if (oldIndex == newIndex) return;

    // Find the account being moved
    final movedAccount = groupAccounts[oldIndex];

    // Find target account (where to insert after)
    final targetAccount = groupAccounts[newIndex];

    // Find actual indices in _accounts
    final actualOldIndex = _accounts.indexWhere((a) => a.id == movedAccount.id);
    final actualTargetIndex = _accounts.indexWhere(
      (a) => a.id == targetAccount.id,
    );

    if (actualOldIndex == -1 || actualTargetIndex == -1) return;

    // Calculate new index (after the target)
    var actualNewIndex = actualTargetIndex;
    if (actualOldIndex < actualNewIndex) {
      actualNewIndex += 1;
    }

    // Perform the reorder
    reorderAccounts(actualOldIndex, actualNewIndex);
  }

  // ── Holdings CRUD ──────────────────────────────────────────────────────────

  void addHolding(StockHolding holding) {
    _holdings.putIfAbsent(holding.portfolioId, () => []).add(holding);
    notifyListeners();
    _db.insertHolding(holding.toMap());
  }

  void updateHolding(StockHolding updated) {
    final list = _holdings[updated.portfolioId];
    if (list == null) return;
    final idx = list.indexWhere((h) => h.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
      notifyListeners();
      _db.updateHolding(updated.toMap());
    }
  }

  void deleteHolding(String id, String portfolioId) {
    _holdings[portfolioId]?.removeWhere((h) => h.id == id);
    notifyListeners();
    _db.deleteHolding(id);
  }

  void reorderHoldings(String portfolioId, int oldIndex, int newIndex) {
    final holdings = _holdings[portfolioId];
    if (holdings == null) return;
    if (oldIndex < 0 || oldIndex >= holdings.length) return;
    if (newIndex < 0 || newIndex > holdings.length) return;

    // Adjust newIndex for the remove-then-insert operation
    if (newIndex > oldIndex) {
      newIndex--;
    }

    // Remove and re-insert
    final movedHolding = holdings.removeAt(oldIndex);
    holdings.insert(newIndex, movedHolding);

    // Update sortOrder for all holdings in this portfolio
    for (var i = 0; i < holdings.length; i++) {
      final h = holdings[i];
      final newSortOrder = i * 10; // Use multiples of 10 for flexibility
      if (h.sortOrder != newSortOrder) {
        h.sortOrder = newSortOrder;
        _db.updateHolding(h.toMap());
      }
    }

    notifyListeners();
  }

  String generateId() => _uuid.v4();
}
