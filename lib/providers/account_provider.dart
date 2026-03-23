import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../repositories/database_repository.dart';
import '../services/database_manager.dart';
import '../models/account.dart';
import '../models/stock_holding.dart';
import '../models/transaction.dart';

class AccountProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final DatabaseManager _dbManager = DatabaseManager();

  final List<Account> _accounts = [];
  final Map<String, List<StockHolding>> _holdings =
      {}; // portfolioId → holdings

  bool _showHiddenAccounts = false;
  bool _isLoading = false;

  bool get showHiddenAccounts => _showHiddenAccounts;
  bool get isLoading => _isLoading;

  void toggleShowHiddenAccounts() {
    _showHiddenAccounts = !_showHiddenAccounts;
    notifyListeners();
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  DatabaseRepository get _db => _dbManager.repository;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    debugPrint('AccountProvider: Initializing...');
    _setLoading(true);

    try {
      final accounts = await _db.getAccounts();
      // Sort by sortOrder to ensure correct order
      accounts.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _accounts.clear();
      _accounts.addAll(accounts);

      final holdings = await _db.getPortfolioHoldings();
      _holdings.clear();
      for (final holding in holdings) {
        _holdings.putIfAbsent(holding.portfolioId, () => []).add(holding);
      }
      // Sort holdings in each portfolio by sortOrder
      for (final portfolioId in _holdings.keys) {
        _holdings[portfolioId]!.sort(
          (a, b) => a.sortOrder.compareTo(b.sortOrder),
        );
      }

      debugPrint(
        'AccountProvider: Loaded ${_accounts.length} accounts, ${holdings.length} holdings',
      );
    } catch (e) {
      debugPrint('AccountProvider: Init error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Reload accounts from database (used after restore/mode switch)
  Future<void> reload() async {
    debugPrint('AccountProvider: Reloading...');
    return init(); // Same logic
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
        if (tx.type != TransactionType.income) balance -= tx.amount;
      }
      if (tx.toAccountId == accountId && tx.type.usesDestinationAccount) {
        balance += tx.amount;
      }
    }

    return balance;
  }

  double getTotalNetWorth(
    List<AppTransaction> transactions, {
    Set<String>? filterIds,
  }) {
    return _accounts
        .where(
          (a) =>
              !a.excludeFromNetWorth &&
              (filterIds == null || filterIds.contains(a.id)),
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

  Future<void> addAccount(Account account) async {
    _accounts.add(account);
    notifyListeners();

    try {
      await _db.insertAccount(account);
    } catch (e) {
      debugPrint('AccountProvider: Error adding account: $e');
      _accounts.removeWhere((a) => a.id == account.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateAccount(Account updated) async {
    final idx = _accounts.indexWhere((a) => a.id == updated.id);
    if (idx == -1) return;

    final oldAccount = _accounts[idx];
    _accounts[idx] = updated;
    notifyListeners();

    try {
      await _db.updateAccount(updated);
    } catch (e) {
      debugPrint('AccountProvider: Error updating account: $e');
      _accounts[idx] = oldAccount;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAccount(String id) async {
    final idx = _accounts.indexWhere((a) => a.id == id);
    if (idx == -1) return;

    final oldAccount = _accounts[idx];
    final oldHoldings = _holdings[id]?.toList() ?? [];

    _accounts.removeAt(idx);
    _holdings.remove(id);
    notifyListeners();

    try {
      await _db.deleteAccount(id);
      await _db.deleteHoldingsByPortfolio(id);
    } catch (e) {
      debugPrint('AccountProvider: Error deleting account: $e');
      _accounts.insert(idx, oldAccount);
      _holdings[id] = oldHoldings;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reorderAccounts(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final account = _accounts.removeAt(oldIndex);
    _accounts.insert(newIndex, account);

    // Update sort order for all affected accounts
    for (int i = 0; i < _accounts.length; i++) {
      _accounts[i] = _accounts[i].copyWith(sortOrder: i);
    }
    notifyListeners();

    try {
      for (int i = 0; i < _accounts.length; i++) {
        await _db.updateAccountSortOrder(_accounts[i].id, i);
      }
    } catch (e) {
      debugPrint('AccountProvider: Error reordering accounts: $e');
      // Note: Full rollback is complex, just reload on error
      await reload();
      rethrow;
    }
  }

  Future<void> reorderAccountsInGroup(
    String groupName,
    int oldIndex,
    int newIndex,
  ) async {
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
    await reorderAccounts(actualOldIndex, actualNewIndex);
  }

  // ── Holdings CRUD ──────────────────────────────────────────────────────────

  Future<void> addHolding(StockHolding holding) async {
    _holdings.putIfAbsent(holding.portfolioId, () => []).add(holding);
    notifyListeners();

    try {
      await _db.insertHolding(holding);
    } catch (e) {
      debugPrint('AccountProvider: Error adding holding: $e');
      _holdings[holding.portfolioId]?.removeWhere((h) => h.id == holding.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateHolding(StockHolding updated) async {
    final list = _holdings[updated.portfolioId];
    if (list == null) return;

    final idx = list.indexWhere((h) => h.id == updated.id);
    if (idx == -1) return;

    final oldHolding = list[idx];
    list[idx] = updated;
    notifyListeners();

    try {
      await _db.updateHolding(updated);
    } catch (e) {
      debugPrint('AccountProvider: Error updating holding: $e');
      list[idx] = oldHolding;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteHolding(String id, String portfolioId) async {
    final list = _holdings[portfolioId];
    if (list == null) return;

    final idx = list.indexWhere((h) => h.id == id);
    if (idx == -1) return;

    final oldHolding = list[idx];
    list.removeAt(idx);
    notifyListeners();

    try {
      await _db.deleteHolding(id);
    } catch (e) {
      debugPrint('AccountProvider: Error deleting holding: $e');
      list.insert(idx, oldHolding);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reorderHoldings(
    String portfolioId,
    int oldIndex,
    int newIndex,
  ) async {
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
      holdings[i].sortOrder = i * 10; // Use multiples of 10 for flexibility
    }
    notifyListeners();

    try {
      for (var i = 0; i < holdings.length; i++) {
        await _db.updateHoldingSortOrder(holdings[i].id, holdings[i].sortOrder);
      }
    } catch (e) {
      debugPrint('AccountProvider: Error reordering holdings: $e');
      await reload();
      rethrow;
    }
  }

  String generateId() => _uuid.v4();
}
