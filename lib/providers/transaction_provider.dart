import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../repositories/database_repository.dart';
import '../services/database_manager.dart';
import '../models/transaction.dart';

class TransactionProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final DatabaseManager _dbManager = DatabaseManager();

  final List<AppTransaction> _transactions = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  // ── Helper ────────────────────────────────────────────────────────────────

  DatabaseRepository get _db => _dbManager.repository;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _setLoading(true);
    
    try {
      final transactions = await _db.getTransactions();
      _transactions.clear();
      _transactions.addAll(transactions);
    } catch (e) {
      debugPrint('TransactionProvider: Init error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Reload transactions from database (used after restore/mode switch)
  Future<void> reload() async {
    debugPrint('TransactionProvider: Reloading...');
    return init(); // Same logic
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

  Future<void> addTransaction(AppTransaction tx) async {
    _transactions.add(tx);
    notifyListeners();

    try {
      await _db.insertTransaction(tx);
    } catch (e) {
      debugPrint('TransactionProvider: Error adding transaction: $e');
      _transactions.removeWhere((t) => t.id == tx.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTransaction(AppTransaction updated) async {
    final idx = _transactions.indexWhere((t) => t.id == updated.id);
    if (idx == -1) return;

    final oldTx = _transactions[idx];
    _transactions[idx] = updated;
    notifyListeners();

    try {
      await _db.updateTransaction(updated);
    } catch (e) {
      debugPrint('TransactionProvider: Error updating transaction: $e');
      _transactions[idx] = oldTx;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id) async {
    final idx = _transactions.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final oldTx = _transactions[idx];
    _transactions.removeAt(idx);
    notifyListeners();

    try {
      await _db.deleteTransaction(id);
    } catch (e) {
      debugPrint('TransactionProvider: Error deleting transaction: $e');
      _transactions.insert(idx, oldTx);
      notifyListeners();
      rethrow;
    }
  }

  String generateId() => _uuid.v4();
}
