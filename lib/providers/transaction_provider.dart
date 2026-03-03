import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';

class TransactionProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final _db = DatabaseHelper.instance;

  final List<AppTransaction> _transactions = [];

  // ── Seed data ─────────────────────────────────────────────────────────────

  // static List<AppTransaction> get _seedTransactions => [
  //   // 28 Feb 2026
  //   AppTransaction(
  //     id: 'tx1',
  //     type: TransactionType.income,
  //     amount: 500,
  //     accountId: 'acc_kbank_main',
  //     categoryId: 'cat_laadin',
  //     dateTime: DateTime(2026, 2, 28, 12, 37),
  //   ),
  //   AppTransaction(
  //     id: 'tx2',
  //     type: TransactionType.expense,
  //     amount: 287,
  //     accountId: 'acc_ktc_mc',
  //     categoryId: 'cat_food',
  //     dateTime: DateTime(2026, 2, 28, 12, 37),
  //   ),
  //   AppTransaction(
  //     id: 'tx3',
  //     type: TransactionType.expense,
  //     amount: 130,
  //     accountId: 'acc_cash',
  //     categoryId: 'cat_food',
  //     dateTime: DateTime(2026, 2, 28, 12, 4),
  //   ),
  //   AppTransaction(
  //     id: 'tx4',
  //     type: TransactionType.expense,
  //     amount: 65,
  //     accountId: 'acc_ktc_mc',
  //     categoryId: 'cat_drink',
  //     dateTime: DateTime(2026, 2, 28, 12, 3),
  //   ),
  //   AppTransaction(
  //     id: 'tx5',
  //     type: TransactionType.expense,
  //     amount: 455,
  //     accountId: 'acc_ktc_mc',
  //     categoryId: 'cat_food',
  //     dateTime: DateTime(2026, 2, 28, 12, 3),
  //   ),
  //   // 27 Feb 2026
  //   AppTransaction(
  //     id: 'tx6',
  //     type: TransactionType.transfer,
  //     amount: 4000,
  //     accountId: 'acc_ktb_main',
  //     toAccountId: 'acc_ktb_saving',
  //     dateTime: DateTime(2026, 2, 27, 13, 56),
  //   ),
  //   AppTransaction(
  //     id: 'tx7',
  //     type: TransactionType.transfer,
  //     amount: 15275.54,
  //     accountId: 'acc_ktb_main',
  //     toAccountId: 'acc_kbank_main',
  //     dateTime: DateTime(2026, 2, 27, 13, 47),
  //   ),
  //   AppTransaction(
  //     id: 'tx8',
  //     type: TransactionType.debtRepay,
  //     amount: 5859.89,
  //     accountId: 'acc_ktb_main',
  //     toAccountId: 'acc_ktc_mc',
  //     dateTime: DateTime(2026, 2, 27, 13, 44),
  //   ),
  //   AppTransaction(
  //     id: 'tx9',
  //     type: TransactionType.debtRepay,
  //     amount: 11103.54,
  //     accountId: 'acc_kbank_main',
  //     toAccountId: 'acc_kbank_visa',
  //     dateTime: DateTime(2026, 2, 27, 13, 43),
  //   ),
  //   AppTransaction(
  //     id: 'tx10',
  //     type: TransactionType.debtRepay,
  //     amount: 6638,
  //     accountId: 'acc_kbank_main',
  //     toAccountId: 'acc_car',
  //     dateTime: DateTime(2026, 2, 27, 13, 43),
  //   ),
  //   AppTransaction(
  //     id: 'tx11',
  //     type: TransactionType.expense,
  //     amount: 2500,
  //     accountId: 'acc_kbank_main',
  //     categoryId: 'cat_home',
  //     dateTime: DateTime(2026, 2, 27, 13, 43),
  //   ),
  // ];

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final rows = await _db.getTransactions();
    if (rows.isEmpty) {
      // final seeds = _seedTransactions;
      // for (final tx in seeds) {
      //   await _db.insertTransaction(tx.toMap());
      // }
      // _transactions.addAll(seeds);
    } else {
      _transactions.addAll(rows.map(AppTransaction.fromMap));
    }
  }

  /// Reload transactions from database (used after restore)
  Future<void> reload() async {
    debugPrint('TransactionProvider: Reloading...');
    _transactions.clear();
    try {
      final rows = await _db.getTransactions();
      debugPrint(
        'TransactionProvider: Loaded ${rows.length} transactions from DB',
      );
      for (final row in rows) {
        try {
          _transactions.add(AppTransaction.fromMap(row));
        } catch (e) {
          debugPrint('TransactionProvider: Error parsing transaction: $e');
          debugPrint('TransactionProvider: Transaction data: $row');
        }
      }
      notifyListeners();
      debugPrint('TransactionProvider: Reload complete');
    } catch (e) {
      debugPrint('TransactionProvider: Reload failed: $e');
      rethrow;
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  List<AppTransaction> get transactions => List.unmodifiable(_transactions);

  List<AppTransaction> getTransactionsForPeriod(DateTime from, DateTime to) {
    return _transactions
        .where(
          (t) =>
              t.dateTime.isAfter(from.subtract(const Duration(seconds: 1))) &&
              t.dateTime.isBefore(to.add(const Duration(days: 1))),
        )
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  List<AppTransaction> getLast30Days() {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    return getTransactionsForPeriod(from, now);
  }

  List<AppTransaction> getLast90Days() {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 90));
    return getTransactionsForPeriod(from, now);
  }

  List<AppTransaction> getLast180Days() {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 180));
    return getTransactionsForPeriod(from, now);
  }

  Map<DateTime, List<AppTransaction>> groupByDate(List<AppTransaction> txs) {
    final Map<DateTime, List<AppTransaction>> grouped = {};
    for (final tx in txs) {
      final date = DateTime(
        tx.dateTime.year,
        tx.dateTime.month,
        tx.dateTime.day,
      );
      grouped.putIfAbsent(date, () => []).add(tx);
    }
    return grouped;
  }

  double getTotalIncome(List<AppTransaction> txs) {
    return txs
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getTotalExpense(List<AppTransaction> txs) {
    return txs
        .where(
          (t) =>
              t.type == TransactionType.expense ||
              t.type == TransactionType.debtRepay,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  void addTransaction(AppTransaction tx) {
    _transactions.add(tx);
    notifyListeners();
    _db.insertTransaction(tx.toMap());
  }

  void updateTransaction(AppTransaction updated) {
    final idx = _transactions.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      _transactions[idx] = updated;
      notifyListeners();
      _db.updateTransaction(updated.toMap());
    }
  }

  void deleteTransaction(String id) {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
    _db.deleteTransaction(id);
  }

  String generateId() => _uuid.v4();
}
