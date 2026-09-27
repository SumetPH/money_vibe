import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../models/budget.dart';
import '../models/fixed_cash_flow_item.dart';
import '../models/planned_purchase.dart';
import '../models/transaction.dart';
import '../repositories/database_repository.dart';
import '../services/cash_flow_forecast_service.dart';
import '../services/database_manager.dart';

/// State ของรายการเงินเข้าออกประจำ, paid mark และรายการอยากซื้อสำหรับ Cash-flow forecast
class CashFlowForecastProvider extends ChangeNotifier {
  static const _sortOrderStep = 10;

  final _uuid = const Uuid();
  final DatabaseManager _dbManager = DatabaseManager();

  final List<FixedCashFlowItem> _items = [];
  final List<FixedCashFlowPaidMark> _paidMarks = [];
  final List<PlannedPurchase> _plannedPurchases = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<FixedCashFlowItem> get items => List.unmodifiable(_items);
  List<FixedCashFlowPaidMark> get paidMarks => List.unmodifiable(_paidMarks);
  List<PlannedPurchase> get plannedPurchases =>
      List.unmodifiable(_plannedPurchases);

  DatabaseRepository get _db => _dbManager.repository;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _db.getFixedCashFlowItems(),
        _db.getFixedCashFlowPaidMarks(),
        _db.getPlannedPurchases(),
      ]);
      final items = results[0] as List<FixedCashFlowItem>;
      final marks = results[1] as List<FixedCashFlowPaidMark>;
      final purchases = results[2] as List<PlannedPurchase>;
      _items
        ..clear()
        ..addAll(
          [...items]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        );
      _paidMarks
        ..clear()
        ..addAll(marks);
      _plannedPurchases
        ..clear()
        ..addAll(
          [...purchases]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        );
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
    required int? anchorDay,
    DateTime? today,
  }) => CashFlowForecastService.calculate(
    today: today ?? DateTime.now(),
    anchorDay: anchorDay,
    accounts: accounts,
    balanceInThb: balanceInThb,
    transactions: transactions,
    items: _items,
    paidMarks: _paidMarks,
  );

  NextPeriodForecast buildNextPeriod({
    required CashFlowForecast current,
    required List<Account> accounts,
    required List<AppTransaction> transactions,
    required List<Budget> budgets,
    required int monthlyCycleStartDay,
    required int anchorDay,
    DateTime? today,
  }) => CashFlowForecastService.calculateNextPeriod(
    current: current,
    today: today ?? DateTime.now(),
    monthlyCycleStartDay: monthlyCycleStartDay,
    anchorDay: anchorDay,
    accounts: accounts,
    transactions: transactions,
    items: _items,
    paidMarks: _paidMarks,
    budgets: budgets,
    plannedPurchases: _plannedPurchases,
  );

  // ── Items ─────────────────────────────────────────────────────────────────

  /// เพิ่มรายการทุกเดือน ([dayOfMonth]) หรือครั้งเดียว ([oneTimeDate])
  Future<void> addItem({
    required String name,
    required double amount,
    required CashFlowDirection direction,
    int? dayOfMonth,
    DateTime? oneTimeDate,
  }) async {
    final sortOrder = _nextSortOrder(_items.map((i) => i.sortOrder));
    final item = FixedCashFlowItem(
      id: _uuid.v4(),
      name: name,
      amount: amount,
      dayOfMonth: dayOfMonth,
      oneTimeDate: oneTimeDate,
      direction: direction,
      sortOrder: sortOrder,
    );
    final previous = List<FixedCashFlowItem>.from(_items);
    _items.add(item);
    notifyListeners();
    try {
      await _db.insertFixedCashFlowItem(item);
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
    _items[index] = updated;
    notifyListeners();
    try {
      await _db.updateFixedCashFlowItem(updated);
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

  void _restoreItems(List<FixedCashFlowItem> previous) {
    _items
      ..clear()
      ..addAll(previous);
    notifyListeners();
  }

  int _nextSortOrder(Iterable<int> sortOrders) => sortOrders.isEmpty
      ? 0
      : sortOrders.reduce((a, b) => a > b ? a : b) + _sortOrderStep;

  // ── Planned purchases ─────────────────────────────────────────────────────

  Future<void> addPlannedPurchase({
    required String name,
    required double amount,
  }) async {
    final purchase = PlannedPurchase(
      id: _uuid.v4(),
      name: name,
      amount: amount,
      sortOrder: _nextSortOrder(_plannedPurchases.map((p) => p.sortOrder)),
    );
    final previous = List<PlannedPurchase>.from(_plannedPurchases);
    _plannedPurchases.add(purchase);
    notifyListeners();
    try {
      await _db.insertPlannedPurchase(purchase);
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Error adding purchase: $e');
      _restorePurchases(previous);
      rethrow;
    }
  }

  /// ใช้ทั้งแก้ไขรายละเอียดและเปิด/ปิดการนับ ([PlannedPurchase.isIncluded])
  Future<void> updatePlannedPurchase(PlannedPurchase updated) async {
    final index = _plannedPurchases.indexWhere((p) => p.id == updated.id);
    if (index == -1) return;
    final previous = List<PlannedPurchase>.from(_plannedPurchases);
    _plannedPurchases[index] = updated;
    notifyListeners();
    try {
      await _db.updatePlannedPurchase(updated);
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Error updating purchase: $e');
      _restorePurchases(previous);
      rethrow;
    }
  }

  Future<void> deletePlannedPurchase(String id) async {
    final previous = List<PlannedPurchase>.from(_plannedPurchases);
    _plannedPurchases.removeWhere((p) => p.id == id);
    notifyListeners();
    try {
      await _db.deletePlannedPurchase(id);
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Error deleting purchase: $e');
      _restorePurchases(previous);
      rethrow;
    }
  }

  void _restorePurchases(List<PlannedPurchase> previous) {
    _plannedPurchases
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
