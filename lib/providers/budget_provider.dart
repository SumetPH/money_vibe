import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/budget.dart';

class BudgetProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final _db = DatabaseHelper.instance;

  final List<Budget> _budgets = [];

  List<Budget> get budgets => List.unmodifiable(_budgets);

  Future<void> init() async {
    debugPrint('BudgetProvider: Initializing...');
    debugPrint(
      'BudgetProvider: Before clear - _budgets.length = ${_budgets.length}',
    );
    try {
      _budgets.clear();
      debugPrint(
        'BudgetProvider: After clear - _budgets.length = ${_budgets.length}',
      );
      final rows = await _db.getBudgets();
      debugPrint('BudgetProvider: Loaded ${rows.length} budgets from DB');
      for (final row in rows) {
        try {
          _budgets.add(Budget.fromMap(row));
        } catch (e) {
          debugPrint('BudgetProvider: Error parsing budget: $e');
          debugPrint('BudgetProvider: Budget data: $row');
          rethrow;
        }
      }
      debugPrint(
        'BudgetProvider: After load - _budgets.length = ${_budgets.length}',
      );
      notifyListeners();
      debugPrint('BudgetProvider: Init complete');
    } catch (e) {
      debugPrint('BudgetProvider: Init failed: $e');
      rethrow;
    }
  }

  Future<void> reload() => init();

  String generateId() => _uuid.v4();

  Future<void> addBudget(Budget budget) async {
    final sortOrder = _budgets.isEmpty
        ? 0
        : (_budgets.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b) +
              10);
    final b = budget.copyWith(sortOrder: sortOrder);
    await _db.insertBudget(b.toMap());
    _budgets.add(b);
    notifyListeners();
  }

  Future<void> updateBudget(Budget budget) async {
    await _db.updateBudget(budget.toMap());
    final idx = _budgets.indexWhere((b) => b.id == budget.id);
    if (idx != -1) {
      _budgets[idx] = budget;
      notifyListeners();
    }
  }

  Future<void> deleteBudget(String id) async {
    await _db.deleteBudget(id);
    _budgets.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  Future<void> reorderBudgets(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final moved = _budgets.removeAt(oldIndex);
    _budgets.insert(newIndex, moved);
    for (var i = 0; i < _budgets.length; i++) {
      final updated = _budgets[i].copyWith(sortOrder: i * 10);
      _budgets[i] = updated;
      await _db.updateBudgetSortOrder(updated.id, i * 10);
    }
    notifyListeners();
  }
}
