import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../repositories/database_repository.dart';
import '../services/database_manager.dart';
import '../models/budget.dart';

class BudgetNameConflictException implements Exception {
  final String name;

  const BudgetNameConflictException(this.name);
}

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
  bool _showHiddenBudgets = false;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  bool get showHiddenBudgets => _showHiddenBudgets;
  List<Budget> get budgets => List.unmodifiable(_budgets);
  List<Budget> get visibleBudgets => _showHiddenBudgets
      ? List.unmodifiable(_budgets)
      : _budgets.where((budget) => !budget.isHidden).toList();

  void toggleShowHiddenBudgets() {
    _showHiddenBudgets = !_showHiddenBudgets;
    notifyListeners();
  }

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
    final normalizedName = budget.name.trim().toLowerCase();
    if (_budgets.any(
      (existing) => existing.name.trim().toLowerCase() == normalizedName,
    )) {
      throw BudgetNameConflictException(budget.name);
    }

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

  Future<void> addBudgetWithCategoryTransfers(Budget budget) async {
    if (budget.type != BudgetType.expense) {
      return addBudget(budget);
    }

    final normalizedName = budget.name.trim().toLowerCase();
    if (_budgets.any(
      (existing) => existing.name.trim().toLowerCase() == normalizedName,
    )) {
      throw BudgetNameConflictException(budget.name);
    }

    final sortOrder = _budgets.isEmpty
        ? 0
        : (_budgets.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b) +
              10);
    final b = budget.copyWith(sortOrder: sortOrder);
    final selectedCategoryIds = b.categoryIds.toSet();
    final oldBudgets = List<Budget>.from(_budgets);
    final changedBudgets = <Budget>[];

    for (var i = 0; i < _budgets.length; i++) {
      final existingBudget = _budgets[i];
      if (existingBudget.type != BudgetType.expense) continue;

      final remainingCategoryIds = existingBudget.categoryIds
          .where((categoryId) => !selectedCategoryIds.contains(categoryId))
          .toList();
      if (remainingCategoryIds.length == existingBudget.categoryIds.length) {
        continue;
      }

      final updatedBudget = existingBudget.copyWith(
        categoryIds: remainingCategoryIds,
      );
      _budgets[i] = updatedBudget;
      changedBudgets.add(updatedBudget);
    }

    _budgets.add(b);
    changedBudgets.add(b);
    notifyListeners();

    try {
      await _db.updateBudgets(changedBudgets);
    } catch (e) {
      debugPrint(
        'BudgetProvider: Error adding budget with category transfers: $e',
      );
      _budgets
        ..clear()
        ..addAll(oldBudgets);
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

  Future<void> updateBudgetWithCategoryTransfers(Budget budget) async {
    if (budget.type != BudgetType.expense) {
      return updateBudget(budget);
    }

    final idx = _budgets.indexWhere((item) => item.id == budget.id);
    if (idx == -1) return;

    final selectedCategoryIds = budget.categoryIds.toSet();
    final oldBudgets = List<Budget>.from(_budgets);
    final changedBudgets = <Budget>[];

    for (var i = 0; i < _budgets.length; i++) {
      final existingBudget = _budgets[i];
      if (existingBudget.id == budget.id ||
          existingBudget.type != BudgetType.expense) {
        continue;
      }

      final remainingCategoryIds = existingBudget.categoryIds
          .where((categoryId) => !selectedCategoryIds.contains(categoryId))
          .toList();
      if (remainingCategoryIds.length == existingBudget.categoryIds.length) {
        continue;
      }

      final updatedBudget = existingBudget.copyWith(
        categoryIds: remainingCategoryIds,
      );
      _budgets[i] = updatedBudget;
      changedBudgets.add(updatedBudget);
    }

    _budgets[idx] = budget;
    changedBudgets.add(budget);
    notifyListeners();

    try {
      await _db.updateBudgets(changedBudgets);
    } catch (e) {
      debugPrint('BudgetProvider: Error transferring budget categories: $e');
      _budgets
        ..clear()
        ..addAll(oldBudgets);
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
    await _reorderBudgetSubset(visibleBudgets, oldIndex, newIndex);
  }

  Future<void> _reorderBudgetSubset(
    List<Budget> subset,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < 0 || oldIndex >= subset.length) return;
    if (newIndex > oldIndex) newIndex--;
    if (newIndex < 0 || newIndex >= subset.length || oldIndex == newIndex) {
      return;
    }

    final moved = subset[oldIndex];
    final target = subset[newIndex];
    final actualOldIndex = _budgets.indexWhere((item) => item.id == moved.id);
    final actualTargetIndex = _budgets.indexWhere(
      (item) => item.id == target.id,
    );
    if (actualOldIndex == -1 || actualTargetIndex == -1) return;

    final removed = _budgets.removeAt(actualOldIndex);
    final insertIndex = _budgets.indexWhere((item) => item.id == target.id);
    _budgets.insert(
      newIndex > oldIndex ? insertIndex + 1 : insertIndex,
      removed,
    );

    await _persistBudgetOrder();
  }

  Future<void> _persistBudgetOrder() async {
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

  Future<void> reorderBudgetsInGroup(
    String? groupName,
    int oldIndex,
    int newIndex,
  ) async {
    final groupBudgets = visibleBudgets
        .where((budget) => _isBudgetInGroup(budget, groupName))
        .toList();
    await _reorderBudgetSubset(groupBudgets, oldIndex, newIndex);
  }

  Future<void> reorderBudgetGroups(int oldIndex, int newIndex) async {
    final groupedBudgets = <String, List<Budget>>{};

    for (final budget in visibleBudgets) {
      final groupName = budget.groupName;
      if (groupName != null && groupName.isNotEmpty) {
        (groupedBudgets[groupName] ??= []).add(budget);
      }
    }

    final groupNames = groupedBudgets.keys.toList();
    if (oldIndex < 0 || oldIndex >= groupNames.length) return;
    if (newIndex > oldIndex) newIndex--;
    if (newIndex < 0 || newIndex >= groupNames.length) return;
    if (oldIndex == newIndex) return;

    final movedGroupName = groupNames[oldIndex];
    final targetGroupName = groupNames[newIndex];
    final movedBudgets = _budgets
        .where((budget) => budget.groupName == movedGroupName)
        .toList();
    final movedIds = movedBudgets.map((budget) => budget.id).toSet();
    _budgets.removeWhere((budget) => movedIds.contains(budget.id));

    final targetIndices = <int>[
      for (var i = 0; i < _budgets.length; i++)
        if (_budgets[i].groupName == targetGroupName) i,
    ];
    if (targetIndices.isEmpty) {
      await reload();
      return;
    }
    final insertIndex = newIndex > oldIndex
        ? targetIndices.last + 1
        : targetIndices.first;
    _budgets.insertAll(insertIndex, movedBudgets);

    await _persistBudgetOrder();
  }

  bool _isBudgetInGroup(Budget budget, String? groupName) {
    if (groupName == null) {
      return budget.groupName == null || budget.groupName!.isEmpty;
    }
    return budget.groupName == groupName;
  }

  String generateId() => _uuid.v4();
}
