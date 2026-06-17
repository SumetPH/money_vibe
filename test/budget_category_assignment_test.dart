import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/models/account.dart';
import 'package:money_vibe/models/budget.dart';
import 'package:money_vibe/models/category.dart';
import 'package:money_vibe/models/recurring_transaction.dart';
import 'package:money_vibe/models/stock_holding.dart';
import 'package:money_vibe/models/stock_trade.dart';
import 'package:money_vibe/models/transaction.dart';
import 'package:money_vibe/providers/budget_provider.dart';
import 'package:money_vibe/providers/category_provider.dart';
import 'package:money_vibe/providers/settings_provider.dart';
import 'package:money_vibe/repositories/database_repository.dart';
import 'package:money_vibe/screens/budget/budget_form_screen.dart';
import 'package:money_vibe/services/database_manager.dart';
import 'package:money_vibe/theme/app_colors.dart';
import 'package:provider/provider.dart';

class FakeBudgetDatabaseRepository implements DatabaseRepository {
  FakeBudgetDatabaseRepository({
    List<Budget>? budgets,
    List<Category>? categories,
  }) : budgets = List<Budget>.from(budgets ?? const []),
       categories = List<Category>.from(categories ?? const []);

  final List<Budget> budgets;
  final List<Category> categories;

  @override
  String get name => 'FakeBudgetDatabaseRepository';

  @override
  bool get isAuthenticated => true;

  @override
  String? get currentUserId => 'test-user';

  @override
  Stream<String> get onLocalSyncLogUpdate => const Stream<String>.empty();

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> clearAllData() async {}

  @override
  Future<bool> isConnected() async => true;

  @override
  Future<Map<String, dynamic>> healthCheck() async => {'status': 'ok'};

  @override
  Future<List<Budget>> getBudgets() async => List<Budget>.from(budgets);

  @override
  Future<void> insertBudget(Budget budget) async {
    budgets.add(budget);
  }

  @override
  Future<void> updateBudget(Budget budget) async {
    final index = budgets.indexWhere((item) => item.id == budget.id);
    if (index != -1) {
      budgets[index] = budget;
    }
  }

  @override
  Future<void> updateBudgetSortOrder(String id, int sortOrder) async {
    final index = budgets.indexWhere((item) => item.id == id);
    if (index != -1) {
      budgets[index] = budgets[index].copyWith(sortOrder: sortOrder);
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    budgets.removeWhere((item) => item.id == id);
  }

  @override
  Future<Set<String>> getExistingBudgetIds() async =>
      budgets.map((item) => item.id).toSet();

  @override
  Future<void> bulkInsertBudgets(List<Budget> budgets) async {
    this.budgets.addAll(budgets);
  }

  @override
  Future<List<Category>> getCategories() async =>
      List<Category>.from(categories);

  @override
  Future<void> insertCategory(Category category) async {
    categories.add(category);
  }

  @override
  Future<void> updateCategory(Category category) async {
    final index = categories.indexWhere((item) => item.id == category.id);
    if (index != -1) {
      categories[index] = category;
    }
  }

  @override
  Future<void> updateCategorySortOrder(String id, int sortOrder) async {
    final index = categories.indexWhere((item) => item.id == id);
    if (index != -1) {
      categories[index] = categories[index].copyWith(sortOrder: sortOrder);
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    categories.removeWhere((item) => item.id == id);
  }

  @override
  Future<Set<String>> getExistingCategoryIds() async =>
      categories.map((item) => item.id).toSet();

  @override
  Future<void> bulkInsertCategories(List<Category> categories) async {
    this.categories.addAll(categories);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('getAccounts')) {
      return Future.value(<Account>[]);
    }
    if (name.contains('getTransactions')) {
      return Future.value(<AppTransaction>[]);
    }
    if (name.contains('getPortfolioHoldings')) {
      return Future.value(<StockHolding>[]);
    }
    if (name.contains('getStockTrades')) {
      return Future.value(<StockTrade>[]);
    }
    if (name.contains('getRecurringTransactions')) {
      return Future.value(<RecurringTransaction>[]);
    }
    if (name.contains('getRecurringOccurrences')) {
      return Future.value(<RecurringOccurrence>[]);
    }
    if (name.contains('getSyncLogs')) {
      return Future.value(<String, DateTime>{});
    }
    return null;
  }
}

Category buildCategory({required String id, required String name}) {
  return Category(
    id: id,
    name: name,
    type: CategoryType.expense,
    icon: Icons.category,
    color: AppColors.accountColors.first,
  );
}

Budget buildBudget({
  required String id,
  required String name,
  required List<String> categoryIds,
}) {
  return Budget(
    id: id,
    name: name,
    amount: 1000,
    categoryIds: categoryIds,
    icon: Icons.savings,
    color: AppColors.accountColors.first,
    type: BudgetType.expense,
  );
}

void main() {
  group('BudgetProvider category assignment', () {
    late FakeBudgetDatabaseRepository fakeDb;
    late BudgetProvider provider;

    setUp(() async {
      fakeDb = FakeBudgetDatabaseRepository(
        budgets: [
          buildBudget(
            id: 'budget-1',
            name: 'ค่าใช้จ่ายประจำ',
            categoryIds: ['cat-food'],
          ),
        ],
        categories: [
          buildCategory(id: 'cat-food', name: 'อาหาร'),
          buildCategory(id: 'cat-travel', name: 'เดินทาง'),
          buildCategory(id: 'cat-home', name: 'บ้าน'),
        ],
      );
      DatabaseManager().repository = fakeDb;
      provider = BudgetProvider();
      await provider.init();
    });

    test('allows adding a budget with an unused category', () async {
      await provider.addBudget(
        buildBudget(
          id: 'budget-2',
          name: 'ค่าเดินทาง',
          categoryIds: ['cat-travel'],
        ),
      );

      expect(provider.budgets.map((budget) => budget.id), contains('budget-2'));
    });

    test(
      'rejects adding a budget with a category already used by another budget',
      () async {
        await expectLater(
          () => provider.addBudget(
            buildBudget(
              id: 'budget-2',
              name: 'งบซ้ำ',
              categoryIds: ['cat-food'],
            ),
          ),
          throwsA(isA<BudgetCategoryConflictException>()),
        );
      },
    );

    test('allows updating a budget while keeping its own categories', () async {
      await provider.updateBudget(
        buildBudget(
          id: 'budget-1',
          name: 'ค่าใช้จ่ายประจำใหม่',
          categoryIds: ['cat-food'],
        ),
      );

      expect(
        provider.budgets.firstWhere((budget) => budget.id == 'budget-1').name,
        'ค่าใช้จ่ายประจำใหม่',
      );
    });

    test(
      'rejects updating a budget with a category already used by another budget',
      () async {
        await provider.addBudget(
          buildBudget(
            id: 'budget-2',
            name: 'งบบ้าน',
            categoryIds: ['cat-home'],
          ),
        );

        await expectLater(
          () => provider.updateBudget(
            buildBudget(
              id: 'budget-2',
              name: 'งบบ้าน',
              categoryIds: ['cat-home', 'cat-food'],
            ),
          ),
          throwsA(isA<BudgetCategoryConflictException>()),
        );
      },
    );
  });

  group('BudgetFormScreen category picker', () {
    late FakeBudgetDatabaseRepository fakeDb;
    late BudgetProvider budgetProvider;
    late CategoryProvider categoryProvider;
    late SettingsProvider settingsProvider;

    setUp(() async {
      fakeDb = FakeBudgetDatabaseRepository(
        budgets: [
          buildBudget(
            id: 'budget-1',
            name: 'ค่าใช้จ่ายประจำ',
            categoryIds: ['cat-food'],
          ),
        ],
        categories: [
          buildCategory(id: 'cat-food', name: 'อาหาร'),
          buildCategory(id: 'cat-travel', name: 'เดินทาง'),
        ],
      );
      DatabaseManager().repository = fakeDb;

      budgetProvider = BudgetProvider();
      categoryProvider = CategoryProvider();
      settingsProvider = SettingsProvider();

      await budgetProvider.init();
      await categoryProvider.init();
    });

    Widget buildTestApp({Budget? budget}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<CategoryProvider>.value(
            value: categoryProvider,
          ),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
          ),
        ],
        child: MaterialApp(home: BudgetFormScreen(budget: budget)),
      );
    }

    Future<void> openCategoryPicker(WidgetTester tester) async {
      await tester.tap(find.text('หมวดหมู่'));
      await tester.pumpAndSettle();
      expect(find.text('เลือกหมวดหมู่'), findsOneWidget);
    }

    testWidgets('shows disabled category with budget name explanation', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await openCategoryPicker(tester);

      expect(find.text('อาหาร'), findsOneWidget);
      expect(find.text('ใช้อยู่ในงบ: ค่าใช้จ่ายประจำ'), findsOneWidget);
    });

    testWidgets('tapping disabled category does not select it', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await openCategoryPicker(tester);

      await tester.tap(find.text('อาหาร'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เสร็จสิ้น'));
      await tester.pumpAndSettle();

      expect(find.text('ไม่ได้เลือก'), findsOneWidget);
    });

    testWidgets('editing budget keeps its own category enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          budget: buildBudget(
            id: 'budget-1',
            name: 'ค่าใช้จ่ายประจำ',
            categoryIds: ['cat-food'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('อาหาร'), findsOneWidget);

      await openCategoryPicker(tester);
      await tester.tap(find.widgetWithText(ListTile, 'อาหาร'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เสร็จสิ้น'));
      await tester.pumpAndSettle();

      expect(find.text('ไม่ได้เลือก'), findsOneWidget);
    });
  });
}
