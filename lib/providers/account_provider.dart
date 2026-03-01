import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/transaction.dart';

class AccountProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final _db = DatabaseHelper.instance;

  final List<Account> _accounts = [];

  // ── Seed data (used only on first launch) ─────────────────────────────────

  static List<Account> get _seedAccounts => [
    Account(
      id: 'acc_cash',
      name: 'เงินสด',
      type: AccountType.cash,
      initialBalance: 970,
      icon: Icons.account_balance_wallet,
      color: const Color(0xFF8D6E63),
    ),
    Account(
      id: 'acc_kbank_main',
      name: 'KBank Main',
      type: AccountType.bankAccount,
      initialBalance: 500,
      icon: Icons.account_balance,
      color: const Color(0xFF4CAF50),
    ),
    Account(
      id: 'acc_ktb_main',
      name: 'KTB Main',
      type: AccountType.bankAccount,
      initialBalance: 883.64,
      icon: Icons.account_balance,
      color: const Color(0xFF2196F3),
    ),
    Account(
      id: 'acc_ktb_saving',
      name: 'KTB Saving',
      type: AccountType.bankAccount,
      initialBalance: 19000,
      icon: Icons.savings,
      color: const Color(0xFF03A9F4),
    ),
    Account(
      id: 'acc_ktc_mc',
      name: 'KTC Mastercard',
      type: AccountType.creditCard,
      initialBalance: -1356.75,
      icon: Icons.credit_card,
      color: const Color(0xFFFF5722),
    ),
    Account(
      id: 'acc_kbank_visa',
      name: 'KBank Visa',
      type: AccountType.creditCard,
      initialBalance: -738.41,
      icon: Icons.credit_card,
      color: const Color(0xFF1565C0),
    ),
    Account(
      id: 'acc_car',
      name: 'รถยนต์',
      type: AccountType.debt,
      initialBalance: -146036,
      icon: Icons.directions_car,
      color: const Color(0xFF607D8B),
    ),
    Account(
      id: 'acc_car_ins',
      name: 'ประกันรถยนต์ 2569',
      type: AccountType.debt,
      initialBalance: -5498.42,
      icon: Icons.shield,
      color: const Color(0xFF78909C),
    ),
    Account(
      id: 'acc_chair',
      name: 'เก้าอี้',
      type: AccountType.debt,
      initialBalance: -1824,
      icon: Icons.weekend,
      color: const Color(0xFF795548),
    ),
    Account(
      id: 'acc_iphone',
      name: 'iPhone 16',
      type: AccountType.debt,
      initialBalance: -19728,
      icon: Icons.phone_iphone,
      color: const Color(0xFF9E9E9E),
    ),
    Account(
      id: 'acc_invest',
      name: 'กองทุนรวม',
      type: AccountType.investment,
      initialBalance: 100000,
      icon: Icons.show_chart,
      color: const Color(0xFF009688),
    ),
  ];

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final rows = await _db.getAccounts();
    if (rows.isEmpty) {
      final seeds = _seedAccounts;
      for (final acc in seeds) {
        await _db.insertAccount(acc.toMap());
      }
      _accounts.addAll(seeds);
    } else {
      _accounts.addAll(rows.map(Account.fromMap));
    }
  }

  /// Reload accounts from database (used after restore)
  Future<void> reload() async {
    _accounts.clear();
    final rows = await _db.getAccounts();
    _accounts.addAll(rows.map(Account.fromMap));
    notifyListeners();
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  List<Account> get accounts => List.unmodifiable(_accounts);

  List<Account> get visibleAccounts =>
      _accounts.where((a) => !a.isHidden).toList();

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

  // ── Balance computation ───────────────────────────────────────────────────

  double getBalance(String accountId, List<AppTransaction> transactions) {
    final account = findById(accountId);
    if (account == null) return 0;
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
        .where((a) => !a.excludeFromNetWorth && !a.isHidden)
        .fold(0.0, (sum, a) => sum + getBalance(a.id, transactions));
  }

  Map<String, double> getGroupTotals(List<AppTransaction> transactions) {
    final Map<String, double> totals = {};
    for (final account in visibleAccounts) {
      final group = accountTypeDisplayGroup(account.type);
      totals[group] =
          (totals[group] ?? 0) + getBalance(account.id, transactions);
    }
    return totals;
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

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
    notifyListeners();
    _db.deleteAccount(id);
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

  String generateId() => _uuid.v4();
}
