import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../repositories/database_repository.dart';
import '../services/database_manager.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class CategoryProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final DatabaseManager _dbManager = DatabaseManager();

  final List<Category> _categories = [];
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
    debugPrint('CategoryProvider: Initializing...');
    _setLoading(true);
    
    try {
      final categories = await _db.getCategories();
      // Sort by sortOrder to ensure correct order
      categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _categories.clear();
      _categories.addAll(categories.cast<Category>());
      debugPrint('CategoryProvider: Loaded ${categories.length} categories');
    } catch (e) {
      debugPrint('CategoryProvider: Init error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Reload categories from database (used after restore/mode switch)
  Future<void> reload() async {
    debugPrint('CategoryProvider: Reloading...');
    return init(); // Same logic
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  List<Category> get categories => List.unmodifiable(_categories);

  List<Category> categoriesOfType(CategoryType type) =>
      _categories.where((c) => c.type == type).toList();

  List<Category> get expenseCategories =>
      categoriesOfType(CategoryType.expense);

  List<Category> get incomeCategories => categoriesOfType(CategoryType.income);

  List<Category> mainCategoriesOfType(CategoryType type) =>
      _categories.where((c) => c.type == type && c.parentId == null).toList();

  Category? findById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  double getTotalForCategory(
    String categoryId,
    List<AppTransaction> transactions,
  ) {
    return transactions
        .where(
          (t) => t.categoryId == categoryId && !t.type.isTransferLike,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> addCategory(Category cat) async {
    _categories.add(cat);
    notifyListeners();

    try {
      await _db.insertCategory(cat);
    } catch (e) {
      debugPrint('CategoryProvider: Error adding category: $e');
      _categories.removeWhere((c) => c.id == cat.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateCategory(Category updated) async {
    final idx = _categories.indexWhere((c) => c.id == updated.id);
    if (idx == -1) return;

    final oldCat = _categories[idx];
    _categories[idx] = updated;
    notifyListeners();

    try {
      await _db.updateCategory(updated);
    } catch (e) {
      debugPrint('CategoryProvider: Error updating category: $e');
      _categories[idx] = oldCat;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    final idx = _categories.indexWhere((c) => c.id == id);
    if (idx == -1) return;

    final oldCat = _categories[idx];
    _categories.removeAt(idx);
    notifyListeners();

    try {
      await _db.deleteCategory(id);
    } catch (e) {
      debugPrint('CategoryProvider: Error deleting category: $e');
      _categories.insert(idx, oldCat);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reorderCategories(CategoryType type, int oldIndex, int newIndex) async {
    debugPrint('CategoryProvider: Reordering - type=$type, oldIndex=$oldIndex, newIndex=$newIndex');
    
    // Get categories of this type sorted by current order
    final typeCategories = _categories.where((c) => c.type == type).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    debugPrint('CategoryProvider: Found ${typeCategories.length} categories of type $type');

    if (oldIndex < 0 || oldIndex >= typeCategories.length) {
      debugPrint('CategoryProvider: Invalid oldIndex=$oldIndex, length=${typeCategories.length}');
      return;
    }
    if (newIndex < 0 || newIndex > typeCategories.length) {
      debugPrint('CategoryProvider: Invalid newIndex=$newIndex, length=${typeCategories.length}');
      return;
    }

    // Adjust newIndex for the remove-then-insert operation
    if (newIndex > oldIndex) {
      newIndex--;
    }

    // Remove and re-insert
    final movedCategory = typeCategories.removeAt(oldIndex);
    typeCategories.insert(newIndex, movedCategory);
    debugPrint('CategoryProvider: Moved ${movedCategory.name} from $oldIndex to $newIndex');

    // Update sortOrder for all categories in this type
    for (var i = 0; i < typeCategories.length; i++) {
      typeCategories[i].sortOrder = i * 10; // Use multiples of 10 for flexibility
      debugPrint('CategoryProvider: ${typeCategories[i].name} sortOrder = ${typeCategories[i].sortOrder}');
    }
    
    // Sort _categories by sortOrder to ensure correct order for UI
    _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    debugPrint('CategoryProvider: _categories sorted by sortOrder');
    
    notifyListeners();

    try {
      debugPrint('CategoryProvider: Saving to database...');
      for (final cat in typeCategories) {
        await _db.updateCategorySortOrder(cat.id, cat.sortOrder);
      }
      debugPrint('CategoryProvider: Reorder complete');
    } catch (e) {
      debugPrint('CategoryProvider: Error reordering categories: $e');
      await reload();
      rethrow;
    }
  }

  String generateId() => _uuid.v4();
}
