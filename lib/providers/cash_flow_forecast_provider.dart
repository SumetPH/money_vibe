import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../models/budget.dart';
import '../models/budget_forecast_setting.dart';
import '../models/fixed_cash_flow_item.dart';
import '../models/planned_purchase.dart';
import '../models/transaction.dart';
import '../repositories/database_repository.dart';
import '../services/cash_flow_forecast_service.dart';
import '../services/database_manager.dart';

/// State ของลิสต์จำลองรายการเงินเข้าออกและรายการอยากซื้อ (แยกงวดนี้/งวดถัดไป)
/// และการตั้งค่างบรายงวด สำหรับ Cash-flow forecast
class CashFlowForecastProvider extends ChangeNotifier {
  static const _sortOrderStep = 10;

  final _uuid = const Uuid();
  final DatabaseManager _dbManager = DatabaseManager();

  final List<FixedCashFlowItem> _items = [];
  final List<PlannedPurchase> _plannedPurchases = [];
  final List<BudgetForecastSetting> _budgetSettings = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<FixedCashFlowItem> get items => List.unmodifiable(_items);
  List<PlannedPurchase> get plannedPurchases =>
      List.unmodifiable(_plannedPurchases);
  List<BudgetForecastSetting> get budgetSettings =>
      List.unmodifiable(_budgetSettings);

  DatabaseRepository get _db => _dbManager.repository;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _db.getFixedCashFlowItems(),
        _db.getPlannedPurchases(),
        _db.getBudgetForecastSettings(),
      ]);
      final items = results[0] as List<FixedCashFlowItem>;
      final purchases = results[1] as List<PlannedPurchase>;
      final budgetSettings = results[2] as List<BudgetForecastSetting>;
      _items
        ..clear()
        ..addAll(
          [...items]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        );
      _plannedPurchases
        ..clear()
        ..addAll(
          [...purchases]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        );
      _budgetSettings
        ..clear()
        ..addAll(budgetSettings);
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
    required List<Budget> budgets,
    required int monthlyCycleStartDay,
    DateTime? today,
  }) => CashFlowForecastService.calculate(
    today: today ?? DateTime.now(),
    anchorDay: anchorDay,
    budgets: budgets,
    budgetSettings: _budgetSettings,
    plannedPurchases: _plannedPurchases,
    monthlyCycleStartDay: monthlyCycleStartDay,
    accounts: accounts,
    balanceInThb: balanceInThb,
    transactions: transactions,
    items: _items,
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
    budgets: budgets,
    budgetSettings: _budgetSettings,
    plannedPurchases: _plannedPurchases,
  );

  // ── Items ─────────────────────────────────────────────────────────────────

  Future<void> addItem({
    required String name,
    required double amount,
    required CashFlowDirection direction,
    required CashFlowPeriod period,
  }) => _saveItem(
    FixedCashFlowItem(
      id: _uuid.v4(),
      name: name,
      amount: amount,
      direction: direction,
      period: period,
      sortOrder: _nextSortOrder(_items.map((i) => i.sortOrder)),
    ),
    isNew: true,
  );

  /// ใช้ทั้งแก้ไขรายละเอียด ย้ายงวด และติ๊กว่าเกิดขึ้นแล้ว ([FixedCashFlowItem.isDone])
  Future<void> updateItem(FixedCashFlowItem updated) =>
      _saveItem(updated, isNew: false);

  Future<void> _saveItem(FixedCashFlowItem item, {required bool isNew}) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (!isNew && index == -1) return;
    final previous = List<FixedCashFlowItem>.from(_items);
    if (isNew) {
      _items.add(item);
    } else {
      _items[index] = item;
    }
    notifyListeners();
    try {
      if (isNew) {
        await _db.insertFixedCashFlowItem(item);
      } else {
        await _db.updateFixedCashFlowItem(item);
      }
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Error saving item: $e');
      _restoreItems(previous);
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    final previous = List<FixedCashFlowItem>.from(_items);
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
    try {
      await _db.deleteFixedCashFlowItem(id);
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Error deleting item: $e');
      _restoreItems(previous);
      rethrow;
    }
  }

  void _restoreItems(List<FixedCashFlowItem> previous) {
    _items
      ..clear()
      ..addAll(previous);
    notifyListeners();
  }

  /// ลากเรียงลำดับในลิสต์ของ [period]; [newIndex] คือตำแหน่งสุดท้ายของรายการ
  Future<void> reorderItems(
    CashFlowPeriod period,
    int oldIndex,
    int newIndex,
  ) async {
    final previous = List<FixedCashFlowItem>.from(_items);
    final changed = _reorderInPeriod(
      _items,
      period,
      oldIndex,
      newIndex,
      periodOf: (i) => i.period,
      sortOrderOf: (i) => i.sortOrder,
      withSortOrder: (i, order) => i.copyWith(sortOrder: order),
    );
    if (changed.isEmpty) return;
    notifyListeners();
    try {
      await Future.wait(changed.map(_db.updateFixedCashFlowItem));
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Error reordering items: $e');
      _restoreItems(previous);
      rethrow;
    }
  }

  int _nextSortOrder(Iterable<int> sortOrders) => sortOrders.isEmpty
      ? 0
      : sortOrders.reduce((a, b) => a > b ? a : b) + _sortOrderStep;

  /// เรียงลำดับใหม่เฉพาะแถวของ [period] ใน [rows] (แก้ [rows] ในที่) และคืนแถวที่ sortOrder เปลี่ยน
  List<T> _reorderInPeriod<T>(
    List<T> rows,
    CashFlowPeriod period,
    int oldIndex,
    int newIndex, {
    required CashFlowPeriod Function(T row) periodOf,
    required int Function(T row) sortOrderOf,
    required T Function(T row, int sortOrder) withSortOrder,
  }) {
    final subset = rows.where((r) => periodOf(r) == period).toList();
    if (oldIndex < 0 ||
        oldIndex >= subset.length ||
        newIndex < 0 ||
        newIndex >= subset.length ||
        oldIndex == newIndex) {
      return const [];
    }
    final moved = subset.removeAt(oldIndex);
    subset.insert(newIndex, moved);
    final renumbered = [
      for (var i = 0; i < subset.length; i++)
        withSortOrder(subset[i], i * _sortOrderStep),
    ];
    final changed = [
      for (var i = 0; i < subset.length; i++)
        if (sortOrderOf(subset[i]) != sortOrderOf(renumbered[i])) renumbered[i],
    ];
    // ลำดับในลิสต์ของงวดอื่นไม่เปลี่ยน; sortOrder เทียบกันเฉพาะในงวดเดียวกัน
    final others = rows.where((r) => periodOf(r) != period).toList();
    rows
      ..clear()
      ..addAll(others)
      ..addAll(renumbered);
    return changed;
  }

  // ── Planned purchases ─────────────────────────────────────────────────────

  Future<void> addPlannedPurchase({
    required String name,
    required double amount,
    required CashFlowPeriod period,
  }) async {
    final purchase = PlannedPurchase(
      id: _uuid.v4(),
      name: name,
      amount: amount,
      period: period,
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

  /// ใช้ทั้งแก้ไขรายละเอียด ย้ายงวด และติ๊กให้นำมาคำนวณ ([PlannedPurchase.isIncluded])
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

  /// ลากเรียงลำดับในลิสต์อยากซื้อของ [period]; [newIndex] คือตำแหน่งสุดท้ายของรายการ
  Future<void> reorderPlannedPurchases(
    CashFlowPeriod period,
    int oldIndex,
    int newIndex,
  ) async {
    final previous = List<PlannedPurchase>.from(_plannedPurchases);
    final changed = _reorderInPeriod(
      _plannedPurchases,
      period,
      oldIndex,
      newIndex,
      periodOf: (p) => p.period,
      sortOrderOf: (p) => p.sortOrder,
      withSortOrder: (p, order) => p.copyWith(sortOrder: order),
    );
    if (changed.isEmpty) return;
    notifyListeners();
    try {
      await Future.wait(changed.map(_db.updatePlannedPurchase));
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Error reordering purchases: $e');
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

  // ── Budget settings per window ────────────────────────────────────────────

  /// การตั้งค่างบ [budgetId] ของงวดที่เคลียร์ยอดวัน [periodEnd] (ค่าเริ่มต้นถ้ายังไม่ตั้ง)
  BudgetForecastSetting budgetSettingFor(String budgetId, DateTime periodEnd) =>
      _budgetSettings
          .where(
            (s) => s.budgetId == budgetId && _isSameDay(s.periodEnd, periodEnd),
          )
          .firstOrNull ??
      BudgetForecastSetting(
        id: _uuid.v4(),
        budgetId: budgetId,
        periodEnd: DateTime(periodEnd.year, periodEnd.month, periodEnd.day),
      );

  /// บันทึกการตั้งค่างบของงวด; ค่าที่กลับเป็นค่าเริ่มต้นจะถูกลบทิ้ง
  Future<void> saveBudgetSetting(BudgetForecastSetting setting) async {
    final previous = List<BudgetForecastSetting>.from(_budgetSettings);
    _budgetSettings.removeWhere(
      (s) =>
          s.budgetId == setting.budgetId &&
          _isSameDay(s.periodEnd, setting.periodEnd),
    );
    if (!setting.isDefault) _budgetSettings.add(setting);
    notifyListeners();
    try {
      if (setting.isDefault) {
        await _db.deleteBudgetForecastSetting(
          setting.budgetId,
          setting.periodEnd,
        );
      } else {
        await _db.upsertBudgetForecastSetting(setting);
      }
    } catch (e) {
      debugPrint('CashFlowForecastProvider: Error saving budget setting: $e');
      _budgetSettings
        ..clear()
        ..addAll(previous);
      notifyListeners();
      rethrow;
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
