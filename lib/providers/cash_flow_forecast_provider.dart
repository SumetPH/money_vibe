import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../models/fixed_cash_flow_item.dart';
import '../models/transaction.dart';
import '../repositories/database_repository.dart';
import '../services/cash_flow_forecast_service.dart';
import '../services/database_manager.dart';

/// State ของรายการเงินเข้าออกประจำและ paid mark สำหรับ Cash-flow forecast
class CashFlowForecastProvider extends ChangeNotifier {
  static const _sortOrderStep = 10;

  final _uuid = const Uuid();
  final DatabaseManager _dbManager = DatabaseManager();

  final List<FixedCashFlowItem> _items = [];
  final List<FixedCashFlowPaidMark> _paidMarks = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<FixedCashFlowItem> get items => List.unmodifiable(_items);
  List<FixedCashFlowPaidMark> get paidMarks => List.unmodifiable(_paidMarks);
  FixedCashFlowItem? get paydayItem =>
      _items.where((i) => i.isPayday).firstOrNull;

  DatabaseRepository get _db => _dbManager.repository;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _db.getFixedCashFlowItems(),
        _db.getFixedCashFlowPaidMarks(),
      ]);
      final items = results[0] as List<FixedCashFlowItem>;
      final marks = results[1] as List<FixedCashFlowPaidMark>;
      _items
        ..clear()
        ..addAll(
          [...items]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        );
      _paidMarks
        ..clear()
        ..addAll(marks);
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Init error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => init();

  // ── Forecast ──────────────────────────────────────────────────────────────

  CashFlowForecast? buildForecast({
    required List<Account> accounts,
    required List<AppTransaction> transactions,
    required double Function(Account account) balanceInThb,
    required int monthlyCycleStartDay,
    DateTime? today,
  }) => CashFlowForecastService.calculate(
    today: today ?? DateTime.now(),
    monthlyCycleStartDay: monthlyCycleStartDay,
    accounts: accounts,
    balanceInThb: balanceInThb,
    transactions: transactions,
    items: _items,
    paidMarks: _paidMarks,
  );

  // ── Items ─────────────────────────────────────────────────────────────────

  Future<void> addItem({
    required String name,
    required double amount,
    required int dayOfMonth,
    required CashFlowDirection direction,
    required bool isPayday,
  }) async {
    final sortOrder = _items.isEmpty
        ? 0
        : _items.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b) +
              _sortOrderStep;
    final item = FixedCashFlowItem(
      id: _uuid.v4(),
      name: name,
      amount: amount,
      dayOfMonth: dayOfMonth,
      direction: direction,
      sortOrder: sortOrder,
    );
    final previous = List<FixedCashFlowItem>.from(_items);
    _items.add(item);
    notifyListeners();
    try {
      await _db.insertFixedCashFlowItem(item);
      if (isPayday) await _setPayday(item.id);
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Error adding item: $e');
      _restoreItems(previous);
      rethrow;
    }
  }

  Future<void> updateItem(FixedCashFlowItem updated) async {
    final index = _items.indexWhere((i) => i.id == updated.id);
    if (index == -1) return;
    final previous = List<FixedCashFlowItem>.from(_items);
    final wasPayday = previous[index].isPayday;
    // รายการเงินออกเป็น payday ไม่ได้
    final isPayday = updated.isPayday && updated.isIncoming;
    _items[index] = updated.copyWith(isPayday: wasPayday);
    notifyListeners();
    try {
      // ล้าง payday ก่อนเขียน เพราะ DB ห้าม payday ที่เป็นรายการเงินออก
      if (!isPayday && wasPayday) await _setPayday(null);
      await _db.updateFixedCashFlowItem(_items[index]);
      if (isPayday && !wasPayday) await _setPayday(updated.id);
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Error updating item: $e');
      _restoreItems(previous);
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    final previousItems = List<FixedCashFlowItem>.from(_items);
    final previousMarks = List<FixedCashFlowPaidMark>.from(_paidMarks);
    _items.removeWhere((i) => i.id == id);
    _paidMarks.removeWhere((m) => m.itemId == id);
    notifyListeners();
    try {
      await _db.deleteFixedCashFlowItem(id);
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Error deleting item: $e');
      _restoreItems(previousItems);
      _paidMarks
        ..clear()
        ..addAll(previousMarks);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _setPayday(String? itemId) async {
    await _db.setPaydayItem(itemId);
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(isPayday: _items[i].id == itemId);
    }
    notifyListeners();
  }

  void _restoreItems(List<FixedCashFlowItem> previous) {
    _items
      ..clear()
      ..addAll(previous);
    notifyListeners();
  }

  // ── Paid marks ────────────────────────────────────────────────────────────

  bool isMarked(String itemId, String month) =>
      _paidMarks.any((m) => m.itemId == itemId && m.month == month);

  Future<void> setMarked({
    required String itemId,
    required String month,
    required bool isMarked,
  }) async {
    if (this.isMarked(itemId, month) == isMarked) return;
    final previous = List<FixedCashFlowPaidMark>.from(_paidMarks);
    final mark = FixedCashFlowPaidMark(
      id: _uuid.v4(),
      itemId: itemId,
      month: month,
    );
    if (isMarked) {
      _paidMarks.add(mark);
    } else {
      _paidMarks.removeWhere((m) => m.itemId == itemId && m.month == month);
    }
    notifyListeners();
    try {
      if (isMarked) {
        await _db.upsertFixedCashFlowPaidMark(mark);
      } else {
        await _db.deleteFixedCashFlowPaidMark(itemId, month);
      }
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Error toggling paid mark: $e');
      _paidMarks
        ..clear()
        ..addAll(previous);
      notifyListeners();
      rethrow;
    }
  }
}
