import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../repositories/database_repository.dart';
import '../services/database_manager.dart';
import '../models/budget.dart';

class BudgetCategoryConflictException implements Exception {
  final String categoryId;
  final String budgetId;
  final String budgetName;

  const BudgetCategoryConflictException({
    required this.categoryId,
    required this.budgetId,
    required this.budgetName,
  });

  @override
  String toString() =>
      'BudgetCategoryConflictException(categoryId: $categoryId, budgetId: $budgetId, budgetName: $budgetName)';
}

class BudgetProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final DatabaseManager _dbManager = DatabaseManager();

  final List<Budget> _budgets = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<Budget> get budgets => List.unmodifiable(_budgets);

  Map<String, Budget> expenseCategoryBudgetMap({String? excludingBudgetId}) {
    final categoryMap = <String, Budget>{};

    for (final budget in _budgets) {
      if (budget.type != BudgetType.expense) continue;
      if (excludingBudgetId != null && budget.id == excludingBudgetId) continue;

      for (final categoryId in budget.categoryIds) {
        categoryMap.putIfAbsent(categoryId, () => budget);
      }
    }

    return categoryMap;
  }

  Budget? getBudgetUsingCategory(
    String categoryId, {
    String? excludingBudgetId,
  }) {
    return expenseCategoryBudgetMap(
      excludingBudgetId: excludingBudgetId,
    )[categoryId];
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  DatabaseRepository get _db => _dbManager.repository;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _validateBudgetCategoryAssignments(Budget budget) {
    if (budget.type != BudgetType.expense) return;

    final usedCategoryMap = expenseCategoryBudgetMap(
      excludingBudgetId: budget.id,
    );
    for (final categoryId in budget.categoryIds) {
      final existingBudget = usedCategoryMap[categoryId];
      if (existingBudget != null) {
        throw BudgetCategoryConflictException(
          categoryId: categoryId,
          budgetId: existingBudget.id,
          budgetName: existingBudget.name,
        );
      }
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    debugPrint('BudgetProvider: Initializing...');
    _setLoading(true);

    try {
      final budgets = await _db.getBudgets();
      // Sort by sortOrder to ensure correct order
      budgets.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _budgets.clear();
      _budgets.addAll(budgets);
      debugPrint('BudgetProvider: Loaded ${budgets.length} budgets');
    } catch (e) {
      debugPrint('BudgetProvider: Init error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reload() async {
    debugPrint('BudgetProvider: Reloading...');
    return init();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> addBudget(Budget budget) async {
    _validateBudgetCategoryAssignments(budget);

    final sortOrder = _budgets.isEmpty
        ? 0
        : (_budgets.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b) +
              10);
    final b = budget.copyWith(sortOrder: sortOrder);

    _budgets.add(b);
    notifyListeners();

    try {
      await _db.insertBudget(b);
    } catch (e) {
      debugPrint('BudgetProvider: Error adding budget: $e');
      _budgets.removeWhere((item) => item.id == b.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateBudget(Budget budget) async {
    final idx = _budgets.indexWhere((b) => b.id == budget.id);
    if (idx == -1) return;

    _validateBudgetCategoryAssignments(budget);

    final oldBudget = _budgets[idx];
    _budgets[idx] = budget;
    notifyListeners();

    try {
      await _db.updateBudget(budget);
    } catch (e) {
      debugPrint('BudgetProvider: Error updating budget: $e');
      _budgets[idx] = oldBudget;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBudget(String id) async {
    final idx = _budgets.indexWhere((b) => b.id == id);
    if (idx == -1) return;

    final oldBudget = _budgets[idx];
    _budgets.removeAt(idx);
    notifyListeners();

    try {
      await _db.deleteBudget(id);
    } catch (e) {
      debugPrint('BudgetProvider: Error deleting budget: $e');
      _budgets.insert(idx, oldBudget);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reorderBudgets(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final moved = _budgets.removeAt(oldIndex);
    _budgets.insert(newIndex, moved);

    for (var i = 0; i < _budgets.length; i++) {
      _budgets[i] = _budgets[i].copyWith(sortOrder: i * 10);
    }
    notifyListeners();

    try {
      for (var i = 0; i < _budgets.length; i++) {
        await _db.updateBudgetSortOrder(_budgets[i].id, i * 10);
      }
    } catch (e) {
      debugPrint('BudgetProvider: Error reordering budgets: $e');
      await reload();
      rethrow;
    }
  }

  String generateId() => _uuid.v4();
}
