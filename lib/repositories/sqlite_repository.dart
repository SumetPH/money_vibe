import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_repository.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../models/stock_holding.dart';
import '../models/stock_trade.dart';
import '../models/portfolio_annual_report.dart';

class SqliteRepository with RepositoryLogger implements DatabaseRepository {
  Database? _db;
  bool _initialized = false;
  final String _localUserId = 'local_user';

  final _localSyncUpdateController = StreamController<String>.broadcast();

  @override
  Stream<String> get onLocalSyncLogUpdate => _localSyncUpdateController.stream;

  @override
  String get name => 'SQLite';

  @override
  String? get currentUserId => _localUserId;

  @override
  bool get isAuthenticated => true;

  @override
  Future<void> init() async {
    if (_initialized) return;

    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = p.join(documentsDirectory.path, 'money_vibe.db');
      log('Opening local SQLite database at: $path');

      _db = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
      _initialized = true;
      log('Local SQLite database initialized successfully');
    } catch (e, stackTrace) {
      logError('Failed to initialize local SQLite database', e);
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    log('Creating SQLite tables...');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        initial_balance REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'THB',
        start_date TEXT NOT NULL,
        icon INTEGER NOT NULL,
        color INTEGER NOT NULL,
        exclude_from_net_worth INTEGER NOT NULL DEFAULT 0,
        is_hidden INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        cash_balance REAL NOT NULL DEFAULT 0,
        exchange_rate REAL NOT NULL DEFAULT 1,
        auto_update_rate INTEGER NOT NULL DEFAULT 1,
        statement_day INTEGER,
        icon_url TEXT NOT NULL DEFAULT '',
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT DEFAULT (datetime('now', 'localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon INTEGER NOT NULL,
        color INTEGER NOT NULL,
        parent_id TEXT,
        note TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT DEFAULT (datetime('now', 'localtime')),
        FOREIGN KEY (parent_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        account_id TEXT NOT NULL,
        category_id TEXT,
        to_account_id TEXT,
        date_time TEXT NOT NULL,
        note TEXT,
        to_amount REAL,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT DEFAULT (datetime('now', 'localtime')),
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
        FOREIGN KEY (to_account_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS portfolio_holdings (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        portfolio_id TEXT NOT NULL,
        ticker TEXT NOT NULL,
        name TEXT NOT NULL DEFAULT '',
        shares REAL NOT NULL DEFAULT 0,
        price_usd REAL NOT NULL DEFAULT 0,
        cost_basis_usd REAL NOT NULL DEFAULT 0,
        logo_url TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        sell_plan_enabled INTEGER NOT NULL DEFAULT 0,
        take_profit_pct REAL NOT NULL DEFAULT 0,
        trailing_stop_pct REAL NOT NULL DEFAULT 0,
        peak_profit_pct REAL,
        stop_loss_pct REAL NOT NULL DEFAULT 0,
        portfolio_group TEXT DEFAULT '' NOT NULL,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT DEFAULT (datetime('now', 'localtime')),
        FOREIGN KEY (portfolio_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        category_ids TEXT NOT NULL DEFAULT '[]',
        icon INTEGER NOT NULL,
        color INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        group_name TEXT,
        budget_type TEXT NOT NULL DEFAULT 'expense',
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT DEFAULT (datetime('now', 'localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        icon INTEGER NOT NULL,
        color INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        day_of_month INTEGER NOT NULL DEFAULT 1,
        transaction_type TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        account_id TEXT NOT NULL,
        to_account_id TEXT,
        category_id TEXT,
        note TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_hidden INTEGER NOT NULL DEFAULT 0,
        notification_enabled INTEGER NOT NULL DEFAULT 0,
        notification_hour INTEGER NOT NULL DEFAULT 9,
        notification_minute INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT DEFAULT (datetime('now', 'localtime')),
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
        FOREIGN KEY (to_account_id) REFERENCES accounts (id) ON DELETE SET NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_occurrences (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        recurring_id TEXT NOT NULL,
        due_date TEXT NOT NULL,
        transaction_id TEXT,
        status TEXT NOT NULL DEFAULT 'done',
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT DEFAULT (datetime('now', 'localtime')),
        FOREIGN KEY (recurring_id) REFERENCES recurring_transactions (id) ON DELETE CASCADE,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_trades (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        portfolio_id TEXT NOT NULL,
        holding_id TEXT NOT NULL DEFAULT '',
        ticker TEXT NOT NULL,
        name TEXT NOT NULL DEFAULT '',
        logo_url TEXT NOT NULL DEFAULT '',
        shares_sold REAL NOT NULL,
        sell_price_usd REAL NOT NULL,
        cash_received_usd REAL NOT NULL,
        cost_basis_usd REAL NOT NULL,
        realized_pnl_usd REAL NOT NULL,
        sold_at TEXT NOT NULL,
        gross_proceeds_usd REAL,
        broker_fee_usd REAL,
        exchange_fee_usd REAL,
        tax_fee_usd REAL,
        cost_method TEXT NOT NULL DEFAULT 'average',
        pnl_source TEXT NOT NULL DEFAULT 'estimated',
        settled_at TEXT,
        broker_order_ref TEXT,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        FOREIGN KEY (portfolio_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS portfolio_annual_reports (
        id TEXT PRIMARY KEY,
        portfolio_id TEXT NOT NULL,
        year INTEGER NOT NULL,
        inflow_usd REAL NOT NULL DEFAULT 0.0,
        note TEXT,
        dividend_gross_usd REAL NOT NULL DEFAULT 0.0,
        dividend_tax_withheld_usd REAL NOT NULL DEFAULT 0.0,
        dividend_net_usd REAL NOT NULL DEFAULT 0.0,
        remitted_usd REAL NOT NULL DEFAULT 0.0,
        remitted_thb REAL NOT NULL DEFAULT 0.0,
        inflow_thb REAL NOT NULL DEFAULT 0.0,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        UNIQUE(portfolio_id, year),
        FOREIGN KEY (portfolio_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_logs (
        user_id TEXT NOT NULL,
        module_name TEXT NOT NULL,
        last_updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, module_name)
      )
    ''');

    log('All tables created.');
  }

  Database get db {
    if (_db == null) {
      throw StateError('SqliteRepository not initialized. Call init() first.');
    }
    return _db!;
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initialized = false;
  }

  @override
  Future<void> clearAllData() async {
    log('Clearing all SQLite tables for offline user...');
    await db.transaction((txn) async {
      await txn.delete('recurring_occurrences');
      await txn.delete('recurring_transactions');
      await txn.delete('transactions');
      await txn.delete('portfolio_holdings');
      await txn.delete('stock_trades');
      await txn.delete('budgets');
      await txn.delete('categories');
      await txn.delete('accounts');
      await txn.delete('portfolio_annual_reports');
      await txn.delete('sync_logs');
    });
  }

  @override
  Future<bool> isConnected() async => true;

  @override
  Future<Map<String, dynamic>> healthCheck() async {
    return {'status': 'healthy', 'type': 'SQLite'};
  }

  // ── Sync logs dummy ───────────────────────────────────────────────────────

  @override
  Future<void> updateSyncLog(String moduleName) async {
    final timestamp = DateTime.now().toIso8601String();
    await db.insert(
      'sync_logs',
      {
        'user_id': _localUserId,
        'module_name': moduleName,
        'last_updated_at': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _localSyncUpdateController.add(moduleName);
  }

  @override
  Future<Map<String, DateTime>> getSyncLogs() async {
    final list = await db.query('sync_logs');
    final Map<String, DateTime> logs = {};
    for (final row in list) {
      final module = row['module_name'] as String;
      final timestamp = row['last_updated_at'] as String;
      logs[module] = DateTime.parse(timestamp);
    }
    return logs;
  }

  // ── Accounts CRUD ─────────────────────────────────────────────────────────

  @override
  Future<List<Account>> getAccounts() async {
    final list = await db.query('accounts', orderBy: 'sort_order');
    return list.map((row) => Account.fromMap(row)).toList();
  }

  @override
  Future<void> insertAccount(Account account) async {
    final map = account.toMap();
    map['user_id'] = _localUserId;
    await db.insert('accounts', map, conflictAlgorithm: ConflictAlgorithm.replace);
    await updateSyncLog('accounts');
  }

  @override
  Future<void> updateAccount(Account account) async {
    final map = account.toMap();
    map['user_id'] = _localUserId;
    await db.update(
      'accounts',
      map,
      where: 'id = ? AND user_id = ?',
      whereArgs: [account.id, _localUserId],
    );
    await updateSyncLog('accounts');
  }

  @override
  Future<void> updateAccountSortOrder(String id, int sortOrder) async {
    await db.update(
      'accounts',
      {'sort_order': sortOrder},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('accounts');
  }

  @override
  Future<void> deleteAccount(String id) async {
    await db.delete(
      'accounts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('accounts');
  }

  @override
  Future<Set<String>> getExistingAccountIds() async {
    final list = await db.query('accounts', columns: ['id']);
    return list.map((row) => row['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertAccounts(List<Account> accounts) async {
    final batch = db.batch();
    for (final a in accounts) {
      final map = a.toMap();
      map['user_id'] = _localUserId;
      batch.insert('accounts', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // ── Categories CRUD ───────────────────────────────────────────────────────

  @override
  Future<List<Category>> getCategories() async {
    final list = await db.query('categories', orderBy: 'sort_order');
    return list.map((row) => Category.fromMap(row)).toList();
  }

  @override
  Future<void> insertCategory(Category category) async {
    final map = category.toMap();
    map['user_id'] = _localUserId;
    await db.insert('categories', map, conflictAlgorithm: ConflictAlgorithm.replace);
    await updateSyncLog('categories');
  }

  @override
  Future<void> updateCategory(Category category) async {
    final map = category.toMap();
    map['user_id'] = _localUserId;
    await db.update(
      'categories',
      map,
      where: 'id = ? AND user_id = ?',
      whereArgs: [category.id, _localUserId],
    );
    await updateSyncLog('categories');
  }

  @override
  Future<void> updateCategorySortOrder(String id, int sortOrder) async {
    await db.update(
      'categories',
      {'sort_order': sortOrder},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('categories');
  }

  @override
  Future<void> deleteCategory(String id) async {
    await db.delete(
      'categories',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('categories');
  }

  @override
  Future<Set<String>> getExistingCategoryIds() async {
    final list = await db.query('categories', columns: ['id']);
    return list.map((row) => row['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertCategories(List<Category> categories) async {
    final batch = db.batch();
    for (final c in categories) {
      final map = c.toMap();
      map['user_id'] = _localUserId;
      batch.insert('categories', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // ── Transactions CRUD ─────────────────────────────────────────────────────

  @override
  Future<List<AppTransaction>> getTransactions() async {
    final list = await db.query('transactions', orderBy: 'date_time DESC');
    return list.map((row) => AppTransaction.fromMap(row)).toList();
  }

  @override
  Future<void> insertTransaction(AppTransaction transaction) async {
    final map = transaction.toMap();
    map['user_id'] = _localUserId;
    await db.insert('transactions', map, conflictAlgorithm: ConflictAlgorithm.replace);
    await updateSyncLog('transactions');
  }

  @override
  Future<void> updateTransaction(AppTransaction transaction) async {
    final map = transaction.toMap();
    map['user_id'] = _localUserId;
    await db.update(
      'transactions',
      map,
      where: 'id = ? AND user_id = ?',
      whereArgs: [transaction.id, _localUserId],
    );
    await updateSyncLog('transactions');
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await db.delete(
      'transactions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('transactions');
  }

  @override
  Future<Set<String>> getExistingTransactionIds() async {
    final list = await db.query('transactions', columns: ['id']);
    return list.map((row) => row['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertTransactions(List<AppTransaction> transactions) async {
    final batch = db.batch();
    for (final t in transactions) {
      final map = t.toMap();
      map['user_id'] = _localUserId;
      batch.insert('transactions', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // ── Portfolio CRUD ────────────────────────────────────────────────────────

  Map<String, dynamic> _normalizeHoldingWrite(StockHolding holding) {
    final map = holding.toMap();
    map['user_id'] = _localUserId;
    map['sell_plan_enabled'] = holding.sellPlanEnabled ? 1 : 0;
    return map;
  }

  StockHolding _normalizeHoldingRead(Map<String, dynamic> row) {
    final copy = Map<String, dynamic>.from(row);
    copy['sell_plan_enabled'] = (copy['sell_plan_enabled'] as int? ?? 0) == 1;
    return StockHolding.fromMap(copy);
  }

  @override
  Future<List<StockHolding>> getPortfolioHoldings() async {
    final list = await db.query('portfolio_holdings', orderBy: 'sort_order');
    return list.map((row) => _normalizeHoldingRead(row)).toList();
  }

  @override
  Future<void> insertHolding(StockHolding holding) async {
    final map = _normalizeHoldingWrite(holding);
    await db.insert('portfolio_holdings', map, conflictAlgorithm: ConflictAlgorithm.replace);
    await updateSyncLog('portfolio_holdings');
  }

  @override
  Future<void> updateHolding(StockHolding holding) async {
    final map = _normalizeHoldingWrite(holding);
    await db.update(
      'portfolio_holdings',
      map,
      where: 'id = ? AND user_id = ?',
      whereArgs: [holding.id, _localUserId],
    );
    await updateSyncLog('portfolio_holdings');
  }

  @override
  Future<void> updateHoldingSortOrder(String id, int sortOrder) async {
    await db.update(
      'portfolio_holdings',
      {'sort_order': sortOrder},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('portfolio_holdings');
  }

  @override
  Future<void> deleteHolding(String id) async {
    await db.delete(
      'portfolio_holdings',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('portfolio_holdings');
  }

  @override
  Future<void> deleteHoldingsByPortfolio(String portfolioId) async {
    await db.delete(
      'portfolio_holdings',
      where: 'portfolio_id = ? AND user_id = ?',
      whereArgs: [portfolioId, _localUserId],
    );
    await updateSyncLog('portfolio_holdings');
  }

  @override
  Future<Set<String>> getExistingHoldingIds() async {
    final list = await db.query('portfolio_holdings', columns: ['id']);
    return list.map((row) => row['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertHoldings(List<StockHolding> holdings) async {
    final batch = db.batch();
    for (final h in holdings) {
      final map = _normalizeHoldingWrite(h);
      batch.insert('portfolio_holdings', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // ── Stock Trades CRUD ─────────────────────────────────────────────────────

  @override
  Future<List<StockTrade>> getStockTrades() async {
    final list = await db.query('stock_trades', orderBy: 'sold_at DESC');
    return list.map((row) => StockTrade.fromMap(row)).toList();
  }

  @override
  Future<void> insertStockTrade(StockTrade trade) async {
    final map = trade.toMap();
    map['user_id'] = _localUserId;
    await db.insert('stock_trades', map, conflictAlgorithm: ConflictAlgorithm.replace);
    await updateSyncLog('stock_trades');
  }

  @override
  Future<void> updateStockTrade(StockTrade trade) async {
    final map = trade.toMap();
    map['user_id'] = _localUserId;
    await db.update(
      'stock_trades',
      map,
      where: 'id = ? AND user_id = ?',
      whereArgs: [trade.id, _localUserId],
    );
    await updateSyncLog('stock_trades');
  }

  @override
  Future<void> deleteStockTrade(String id) async {
    await db.delete(
      'stock_trades',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('stock_trades');
  }

  @override
  Future<Set<String>> getExistingStockTradeIds() async {
    final list = await db.query('stock_trades', columns: ['id']);
    return list.map((row) => row['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertStockTrades(List<StockTrade> trades) async {
    final batch = db.batch();
    for (final t in trades) {
      final map = t.toMap();
      map['user_id'] = _localUserId;
      batch.insert('stock_trades', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // ── Portfolio Annual Reports CRUD ─────────────────────────────────────────

  @override
  Future<List<PortfolioAnnualReport>> getPortfolioAnnualReports() async {
    final list = await db.query('portfolio_annual_reports', orderBy: 'year DESC');
    return list.map((row) => PortfolioAnnualReport.fromMap(row)).toList();
  }

  @override
  Future<void> insertPortfolioAnnualReport(PortfolioAnnualReport report) async {
    final map = report.toMap();
    await db.insert('portfolio_annual_reports', map, conflictAlgorithm: ConflictAlgorithm.replace);
    await updateSyncLog('portfolio_annual_reports');
  }

  @override
  Future<void> updatePortfolioAnnualReport(PortfolioAnnualReport report) async {
    final map = report.toMap();
    await db.update(
      'portfolio_annual_reports',
      map,
      where: 'id = ?',
      whereArgs: [report.id],
    );
    await updateSyncLog('portfolio_annual_reports');
  }

  @override
  Future<void> deletePortfolioAnnualReport(String id) async {
    await db.delete(
      'portfolio_annual_reports',
      where: 'id = ?',
      whereArgs: [id],
    );
    await updateSyncLog('portfolio_annual_reports');
  }

  // ── Budgets CRUD ──────────────────────────────────────────────────────────

  @override
  Future<List<Budget>> getBudgets() async {
    final list = await db.query('budgets', orderBy: 'sort_order');
    return list.map((row) => Budget.fromMap(row)).toList();
  }

  @override
  Future<void> insertBudget(Budget budget) async {
    final map = budget.toMap();
    map['user_id'] = _localUserId;
    await db.insert('budgets', map, conflictAlgorithm: ConflictAlgorithm.replace);
    await updateSyncLog('budgets');
  }

  @override
  Future<void> updateBudget(Budget budget) async {
    final map = budget.toMap();
    map['user_id'] = _localUserId;
    await db.update(
      'budgets',
      map,
      where: 'id = ? AND user_id = ?',
      whereArgs: [budget.id, _localUserId],
    );
    await updateSyncLog('budgets');
  }

  @override
  Future<void> updateBudgetSortOrder(String id, int sortOrder) async {
    await db.update(
      'budgets',
      {'sort_order': sortOrder},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('budgets');
  }

  @override
  Future<void> deleteBudget(String id) async {
    await db.delete(
      'budgets',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('budgets');
  }

  @override
  Future<Set<String>> getExistingBudgetIds() async {
    final list = await db.query('budgets', columns: ['id']);
    return list.map((row) => row['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertBudgets(List<Budget> budgets) async {
    final batch = db.batch();
    for (final b in budgets) {
      final map = b.toMap();
      map['user_id'] = _localUserId;
      batch.insert('budgets', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // ── Recurring Transactions CRUD ───────────────────────────────────────────

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    final list = await db.query('recurring_transactions', orderBy: 'sort_order');
    return list.map((row) => RecurringTransaction.fromMap(row)).toList();
  }

  @override
  Future<void> insertRecurringTransaction(RecurringTransaction recurring) async {
    final map = recurring.toMap();
    map['user_id'] = _localUserId;
    await db.insert('recurring_transactions', map, conflictAlgorithm: ConflictAlgorithm.replace);
    await updateSyncLog('recurring_transactions');
  }

  @override
  Future<void> updateRecurringTransaction(RecurringTransaction recurring) async {
    final map = recurring.toMap();
    map['user_id'] = _localUserId;
    await db.update(
      'recurring_transactions',
      map,
      where: 'id = ? AND user_id = ?',
      whereArgs: [recurring.id, _localUserId],
    );
    await updateSyncLog('recurring_transactions');
  }

  @override
  Future<void> deleteRecurringTransaction(String id) async {
    await db.delete(
      'recurring_transactions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('recurring_transactions');
  }

  @override
  Future<void> updateRecurringSortOrder(String id, int sortOrder) async {
    await db.update(
      'recurring_transactions',
      {'sort_order': sortOrder},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('recurring_transactions');
  }

  @override
  Future<Set<String>> getExistingRecurringIds() async {
    final list = await db.query('recurring_transactions', columns: ['id']);
    return list.map((row) => row['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertRecurring(List<RecurringTransaction> recurring) async {
    final batch = db.batch();
    for (final r in recurring) {
      final map = r.toMap();
      map['user_id'] = _localUserId;
      batch.insert('recurring_transactions', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // ── Recurring Occurrences CRUD ────────────────────────────────────────────

  @override
  Future<List<RecurringOccurrence>> getRecurringOccurrences() async {
    final list = await db.query('recurring_occurrences', orderBy: 'due_date');
    return list.map((row) => RecurringOccurrence.fromMap(row)).toList();
  }

  @override
  Future<List<RecurringOccurrence>> getOccurrencesFor(String recurringId) async {
    final list = await db.query(
      'recurring_occurrences',
      where: 'recurring_id = ? AND user_id = ?',
      whereArgs: [recurringId, _localUserId],
      orderBy: 'due_date',
    );
    return list.map((row) => RecurringOccurrence.fromMap(row)).toList();
  }

  @override
  Future<void> insertRecurringOccurrence(RecurringOccurrence occurrence) async {
    final map = occurrence.toMap();
    map['user_id'] = _localUserId;
    await db.insert('recurring_occurrences', map, conflictAlgorithm: ConflictAlgorithm.replace);
    await updateSyncLog('recurring_occurrences');
  }

  @override
  Future<void> deleteOccurrence(String id) async {
    await db.delete(
      'recurring_occurrences',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _localUserId],
    );
    await updateSyncLog('recurring_occurrences');
  }

  @override
  Future<void> deleteOccurrencesByRecurring(String recurringId) async {
    await db.delete(
      'recurring_occurrences',
      where: 'recurring_id = ? AND user_id = ?',
      whereArgs: [recurringId, _localUserId],
    );
    await updateSyncLog('recurring_occurrences');
  }

  @override
  Future<Set<String>> getExistingOccurrenceIds() async {
    final list = await db.query('recurring_occurrences', columns: ['id']);
    return list.map((row) => row['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertOccurrences(List<RecurringOccurrence> occurrences) async {
    final batch = db.batch();
    for (final o in occurrences) {
      final map = o.toMap();
      map['user_id'] = _localUserId;
      batch.insert('recurring_occurrences', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }
}
