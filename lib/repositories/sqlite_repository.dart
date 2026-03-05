// Foundation debugPrint is accessed through RepositoryLogger mixin
import 'database_repository.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../models/stock_holding.dart';

/// SQLite Repository Implementation
/// ใช้ DatabaseHelper เดิมเป็น backend แต่ expose เป็น interface ใหม่
class SQLiteRepository with RepositoryLogger implements DatabaseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static bool _initialized = false;

  @override
  String get name => 'SQLite';

  @override
  Future<void> init() async {
    log('Initializing...');
    if (!_initialized) {
      DatabaseHelper.initialize();
      _initialized = true;
    }
    await _dbHelper.database;
    log('Initialized successfully');
  }

  @override
  Future<void> close() async {
    log('Close called (no-op for singleton)');
  }

  // ── Accounts ──────────────────────────────────────────────────────────────

  @override
  Future<List<Account>> getAccounts() async {
    final rows = await _dbHelper.getAccounts();
    return rows.map((row) => Account.fromMap(row)).toList();
  }

  @override
  Future<void> insertAccount(Account account) async {
    await _dbHelper.insertAccount(account.toMap());
  }

  @override
  Future<void> updateAccount(Account account) async {
    await _dbHelper.updateAccount(account.toMap());
  }

  @override
  Future<void> updateAccountSortOrder(String id, int sortOrder) async {
    await _dbHelper.updateAccountSortOrder(id, sortOrder);
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _dbHelper.deleteAccount(id);
  }

  // ── Categories ────────────────────────────────────────────────────────────

  @override
  Future<List<Category>> getCategories() async {
    final rows = await _dbHelper.getCategories();
    return rows.map((row) => Category.fromMap(row)).toList();
  }

  @override
  Future<void> insertCategory(Category category) async {
    await _dbHelper.insertCategory(category.toMap());
  }

  @override
  Future<void> updateCategory(Category category) async {
    await _dbHelper.updateCategory(category.toMap());
  }

  @override
  Future<void> updateCategorySortOrder(String id, int sortOrder) async {
    await _dbHelper.updateCategorySortOrder(id, sortOrder);
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _dbHelper.deleteCategory(id);
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  @override
  Future<List<AppTransaction>> getTransactions() async {
    final rows = await _dbHelper.getTransactions();
    return rows.map((row) => AppTransaction.fromMap(row)).toList();
  }

  @override
  Future<void> insertTransaction(AppTransaction transaction) async {
    await _dbHelper.insertTransaction(transaction.toMap());
  }

  @override
  Future<void> updateTransaction(AppTransaction transaction) async {
    await _dbHelper.updateTransaction(transaction.toMap());
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _dbHelper.deleteTransaction(id);
  }

  // ── Portfolio Holdings ─────────────────────────────────────────────────────

  @override
  Future<List<StockHolding>> getPortfolioHoldings() async {
    final rows = await _dbHelper.getPortfolioHoldings();
    return rows.map((row) => StockHolding.fromMap(row)).toList();
  }

  @override
  Future<void> insertHolding(StockHolding holding) async {
    await _dbHelper.insertHolding(holding.toMap());
  }

  @override
  Future<void> updateHolding(StockHolding holding) async {
    await _dbHelper.updateHolding(holding.toMap());
  }

  @override
  Future<void> updateHoldingSortOrder(String id, int sortOrder) async {
    await _dbHelper.updateHoldingSortOrder(id, sortOrder);
  }

  @override
  Future<void> deleteHolding(String id) async {
    await _dbHelper.deleteHolding(id);
  }

  @override
  Future<void> deleteHoldingsByPortfolio(String portfolioId) async {
    await _dbHelper.deleteHoldingsByPortfolio(portfolioId);
  }

  // ── Budgets ────────────────────────────────────────────────────────────────

  @override
  Future<List<Budget>> getBudgets() async {
    final rows = await _dbHelper.getBudgets();
    return rows.map((row) => Budget.fromMap(row)).toList();
  }

  @override
  Future<void> insertBudget(Budget budget) async {
    await _dbHelper.insertBudget(budget.toMap());
  }

  @override
  Future<void> updateBudget(Budget budget) async {
    await _dbHelper.updateBudget(budget.toMap());
  }

  @override
  Future<void> updateBudgetSortOrder(String id, int sortOrder) async {
    await _dbHelper.updateBudgetSortOrder(id, sortOrder);
  }

  @override
  Future<void> deleteBudget(String id) async {
    await _dbHelper.deleteBudget(id);
  }

  // ── Recurring Transactions ─────────────────────────────────────────────────

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    final rows = await _dbHelper.getRecurringTransactions();
    return rows.map((row) => RecurringTransaction.fromMap(row)).toList();
  }

  @override
  Future<void> insertRecurringTransaction(RecurringTransaction recurring) async {
    await _dbHelper.insertRecurringTransaction(recurring.toMap());
  }

  @override
  Future<void> updateRecurringTransaction(RecurringTransaction recurring) async {
    await _dbHelper.updateRecurringTransaction(recurring.toMap());
  }

  @override
  Future<void> deleteRecurringTransaction(String id) async {
    await _dbHelper.deleteRecurringTransaction(id);
  }

  @override
  Future<void> updateRecurringSortOrder(String id, int sortOrder) async {
    await _dbHelper.updateRecurringSortOrder(id, sortOrder);
  }

  // ── Recurring Occurrences ──────────────────────────────────────────────────

  @override
  Future<List<RecurringOccurrence>> getRecurringOccurrences() async {
    final rows = await _dbHelper.getRecurringOccurrences();
    return rows.map((row) => RecurringOccurrence.fromMap(row)).toList();
  }

  @override
  Future<List<RecurringOccurrence>> getOccurrencesFor(String recurringId) async {
    final rows = await _dbHelper.getOccurrencesFor(recurringId);
    return rows.map((row) => RecurringOccurrence.fromMap(row)).toList();
  }

  @override
  Future<void> insertRecurringOccurrence(RecurringOccurrence occurrence) async {
    await _dbHelper.insertRecurringOccurrence(occurrence.toMap());
  }

  @override
  Future<void> deleteOccurrence(String id) async {
    await _dbHelper.deleteOccurrence(id);
  }

  @override
  Future<void> deleteOccurrencesByRecurring(String recurringId) async {
    await _dbHelper.deleteOccurrencesByRecurring(recurringId);
  }

  // ── Migration Helpers ──────────────────────────────────────────────────────

  @override
  Future<void> clearAllData() async {
    log('Clearing all data...');
    await _dbHelper.clearDatabase();
    log('All data cleared');
  }

  @override
  Future<bool> isConnected() async {
    try {
      final db = await _dbHelper.database;
      return db.isOpen;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> healthCheck() async {
    final stopwatch = Stopwatch()..start();
    try {
      final db = await _dbHelper.database;
      stopwatch.stop();
      return {
        'status': 'healthy',
        'isOpen': db.isOpen,
        'latencyMs': stopwatch.elapsedMilliseconds,
      };
    } catch (e) {
      stopwatch.stop();
      return {
        'status': 'error',
        'error': e.toString(),
        'latencyMs': stopwatch.elapsedMilliseconds,
      };
    }
  }
}
