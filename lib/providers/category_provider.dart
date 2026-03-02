import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class CategoryProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final _db = DatabaseHelper.instance;

  final List<Category> _categories = [];

  // ── Seed data ─────────────────────────────────────────────────────────────

  static List<Category> get _seedCategories => [
    Category(
      id: 'cat_food',
      name: 'อาหาร',
      icon: Icons.restaurant,
      color: const Color(0xFFFF9800),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_drink',
      name: 'เครื่องดื่ม',
      icon: Icons.local_cafe,
      color: const Color(0xFF795548),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_expense',
      name: 'ใช้จ่าย',
      icon: Icons.shopping_cart,
      color: const Color(0xFFFF7043),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_car',
      name: 'รถยนต์',
      icon: Icons.directions_car,
      color: const Color(0xFF607D8B),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_fuel',
      name: 'น้ำมัน',
      icon: Icons.local_gas_station,
      color: const Color(0xFFF44336),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_debt_pay',
      name: 'ผ่อนชำระ',
      icon: Icons.payment,
      color: const Color(0xFFE91E63),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_home',
      name: 'บ้าน',
      icon: Icons.home,
      color: const Color(0xFF4CAF50),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_special',
      name: 'พิเศษ',
      icon: Icons.star,
      color: const Color(0xFFFFB300),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_games',
      name: 'เกมส์',
      icon: Icons.sports_esports,
      color: const Color(0xFF9C27B0),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_books',
      name: 'หนังสือ',
      icon: Icons.menu_book,
      color: const Color(0xFF795548),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_ai',
      name: 'AI',
      icon: Icons.auto_awesome,
      color: const Color(0xFF2196F3),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_subscription',
      name: 'Subscription',
      icon: Icons.subscriptions,
      color: const Color(0xFFFF5722),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_transport',
      name: 'การเดินทาง',
      icon: Icons.directions_bus,
      color: const Color(0xFF03A9F4),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_health',
      name: 'สุขภาพ',
      icon: Icons.local_hospital,
      color: const Color(0xFFF44336),
      type: CategoryType.expense,
    ),
    Category(
      id: 'cat_shopping',
      name: 'ช้อปปิ้ง',
      icon: Icons.shopping_bag,
      color: const Color(0xFFE91E63),
      type: CategoryType.expense,
    ),
    // Income categories
    Category(
      id: 'cat_salary',
      name: 'เงินเดือน',
      icon: Icons.work,
      color: const Color(0xFF4CAF50),
      type: CategoryType.income,
    ),
    Category(
      id: 'cat_laadin',
      name: 'ลาดิน',
      icon: Icons.attach_money,
      color: const Color(0xFF66BB6A),
      type: CategoryType.income,
    ),
    Category(
      id: 'cat_freelance',
      name: 'Freelance',
      icon: Icons.laptop,
      color: const Color(0xFF26A69A),
      type: CategoryType.income,
    ),
    Category(
      id: 'cat_investment_income',
      name: 'รายได้จากการลงทุน',
      icon: Icons.show_chart,
      color: const Color(0xFF009688),
      type: CategoryType.income,
    ),
    Category(
      id: 'cat_other_income',
      name: 'รายได้อื่นๆ',
      icon: Icons.monetization_on,
      color: const Color(0xFF8BC34A),
      type: CategoryType.income,
    ),
  ];

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final rows = await _db.getCategories();
    if (rows.isEmpty) {
      // final seeds = _seedCategories;
      // for (final cat in seeds) {
      //   await _db.insertCategory(cat.toMap());
      // }
      // _categories.addAll(seeds);
    } else {
      _categories.addAll(rows.map(Category.fromMap));
    }
  }

  /// Reload categories from database (used after restore)
  Future<void> reload() async {
    debugPrint('CategoryProvider: Reloading...');
    _categories.clear();
    final rows = await _db.getCategories();
    debugPrint('CategoryProvider: Loaded ${rows.length} categories from DB');
    _categories.addAll(rows.map(Category.fromMap));
    notifyListeners();
    debugPrint(
      'CategoryProvider: Reload complete, total: ${_categories.length}',
    );
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
          (t) =>
              t.categoryId == categoryId && t.type != TransactionType.transfer,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  void addCategory(Category cat) {
    _categories.add(cat);
    notifyListeners();
    _db.insertCategory(cat.toMap());
  }

  void updateCategory(Category updated) {
    final idx = _categories.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      _categories[idx] = updated;
      notifyListeners();
      _db.updateCategory(updated.toMap());
    }
  }

  void deleteCategory(String id) {
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
    _db.deleteCategory(id);
  }

  void reorderCategories(CategoryType type, int oldIndex, int newIndex) {
    // Get categories of this type sorted by current order
    final typeCategories = _categories.where((c) => c.type == type).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (oldIndex < 0 || oldIndex >= typeCategories.length) return;
    if (newIndex < 0 || newIndex > typeCategories.length) return;

    // Adjust newIndex for the remove-then-insert operation
    if (newIndex > oldIndex) {
      newIndex--;
    }

    // Remove and re-insert
    final movedCategory = typeCategories.removeAt(oldIndex);
    typeCategories.insert(newIndex, movedCategory);

    // Update sortOrder for all categories in this type
    for (var i = 0; i < typeCategories.length; i++) {
      final cat = typeCategories[i];
      final newSortOrder = i * 10; // Use multiples of 10 for flexibility
      if (cat.sortOrder != newSortOrder) {
        cat.sortOrder = newSortOrder;
        _db.updateCategorySortOrder(cat.id, newSortOrder);
      }
    }

    notifyListeners();
  }

  String generateId() => _uuid.v4();
}
