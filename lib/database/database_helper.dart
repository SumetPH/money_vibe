import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;
  static bool _initialized = false;

  DatabaseHelper._();

  /// Initialize sqflite for desktop platforms (macOS, Windows, Linux)
  static void initialize() {
    if (_initialized) return;

    // Use FFI for desktop platforms
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _initialized = true;
  }

  Future<Database> get database async {
    initialize(); // Ensure initialization before use
    _db ??= await _initDb();
    return _db!;
  }

  /// Clear database by deleting and recreating it
  Future<void> clearDatabase() async {
    debugPrint('DatabaseHelper: Starting clearDatabase...');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'money.db');
    debugPrint('DatabaseHelper: Database path = $path');

    // Close database connection first
    if (_db != null) {
      debugPrint('DatabaseHelper: Closing existing database connection...');
      await _db!.close();
      _db = null;
    }

    // Delete database file
    debugPrint('DatabaseHelper: Deleting database file...');
    await deleteDatabase(path);

    // Verify deletion
    final dbFile = File(path);
    final exists = await dbFile.exists();
    debugPrint('DatabaseHelper: Database file exists after delete = $exists');

    // Reset and recreate
    _db = null;
    debugPrint('DatabaseHelper: Reinitializing database...');
    await _initDb();
    debugPrint('DatabaseHelper: Database reinitialized');
  }

  /// Reset database connection after restore
  ///
  /// ใช้หลังจาก restore database เพื่อปิด connection เก่าและเปิด connection ใหม่
  /// ไปยังไฟล์ database ที่ถูกเขียนทับ
  Future<void> resetDatabaseConnection() async {
    debugPrint('DatabaseHelper: Resetting database connection...');
    if (_db != null) {
      debugPrint('DatabaseHelper: Closing existing database connection...');
      await _db!.close();
      _db = null;
      debugPrint(
        'DatabaseHelper: Database connection closed, will reconnect on next access',
      );
    }
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'money.db');
    const targetVersion = 3;

    // Auto backup before migration
    final dbFile = File(path);
    if (await dbFile.exists()) {
      final tempDb = await openDatabase(path, singleInstance: false);
      final currentVersion = await tempDb.getVersion();
      await tempDb.close();
      if (currentVersion > 0 && currentVersion < targetVersion) {
        final now = DateTime.now();
        final ts =
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
            '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
        final backupPath = join(dbPath, 'money_v${currentVersion}_$ts.db');
        await dbFile.copy(backupPath);
      }
    }

    return openDatabase(
      path,
      version: targetVersion,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE budgets (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              amount REAL NOT NULL DEFAULT 0,
              category_ids TEXT NOT NULL DEFAULT '[]',
              icon INTEGER NOT NULL,
              color INTEGER NOT NULL,
              sort_order INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE recurring_transactions (
              id TEXT PRIMARY KEY,
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
              sort_order INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE recurring_occurrences (
              id TEXT PRIMARY KEY,
              recurring_id TEXT NOT NULL,
              due_date TEXT NOT NULL,
              transaction_id TEXT,
              status TEXT NOT NULL DEFAULT 'done'
            )
          ''');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE accounts (
            id TEXT PRIMARY KEY,
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
            exchange_rate REAL NOT NULL DEFAULT 35.0,
            auto_update_rate INTEGER NOT NULL DEFAULT 1,
            statement_day INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            icon INTEGER NOT NULL,
            color INTEGER NOT NULL,
            parent_id TEXT,
            note TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            account_id TEXT NOT NULL,
            category_id TEXT,
            to_account_id TEXT,
            date_time TEXT NOT NULL,
            note TEXT,
            tags TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE portfolio_holdings (
            id TEXT PRIMARY KEY,
            portfolio_id TEXT NOT NULL,
            ticker TEXT NOT NULL,
            name TEXT NOT NULL DEFAULT '',
            shares REAL NOT NULL DEFAULT 0,
            price_usd REAL NOT NULL DEFAULT 0,
            cost_basis_usd REAL NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE budgets (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            amount REAL NOT NULL DEFAULT 0,
            category_ids TEXT NOT NULL DEFAULT '[]',
            icon INTEGER NOT NULL,
            color INTEGER NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE recurring_transactions (
            id TEXT PRIMARY KEY,
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
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE recurring_occurrences (
            id TEXT PRIMARY KEY,
            recurring_id TEXT NOT NULL,
            due_date TEXT NOT NULL,
            transaction_id TEXT,
            status TEXT NOT NULL DEFAULT 'done'
          )
        ''');
      },
    );
  }

  // ── Accounts ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await database;
    return db.query('accounts', orderBy: 'sort_order ASC, rowid ASC');
  }

  Future<void> insertAccount(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'accounts',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateAccount(Map<String, dynamic> data) async {
    final db = await database;
    await db.update('accounts', data, where: 'id = ?', whereArgs: [data['id']]);
  }

  Future<void> updateAccountSortOrder(String id, int sortOrder) async {
    final db = await database;
    await db.update(
      'accounts',
      {'sort_order': sortOrder},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAccount(String id) async {
    final db = await database;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return db.query('categories', orderBy: 'sort_order ASC, rowid ASC');
  }

  Future<void> updateCategorySortOrder(String id, int sortOrder) async {
    final db = await database;
    await db.update(
      'categories',
      {'sort_order': sortOrder},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertCategory(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'categories',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCategory(Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'categories',
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await database;
    return db.query('transactions', orderBy: 'date_time DESC');
  }

  Future<void> insertTransaction(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'transactions',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransaction(Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'transactions',
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ── Portfolio Holdings ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPortfolioHoldings() async {
    final db = await database;
    return db.query('portfolio_holdings', orderBy: 'sort_order ASC, rowid ASC');
  }

  Future<void> insertHolding(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'portfolio_holdings',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateHolding(Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'portfolio_holdings',
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  Future<void> updateHoldingSortOrder(String id, int sortOrder) async {
    final db = await database;
    await db.update(
      'portfolio_holdings',
      {'sort_order': sortOrder},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteHolding(String id) async {
    final db = await database;
    await db.delete('portfolio_holdings', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteHoldingsByPortfolio(String portfolioId) async {
    final db = await database;
    await db.delete(
      'portfolio_holdings',
      where: 'portfolio_id = ?',
      whereArgs: [portfolioId],
    );
  }

  // ── Budgets ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBudgets() async {
    final db = await database;
    return db.query('budgets', orderBy: 'sort_order ASC, rowid ASC');
  }

  Future<void> insertBudget(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'budgets',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateBudget(Map<String, dynamic> data) async {
    final db = await database;
    await db.update('budgets', data, where: 'id = ?', whereArgs: [data['id']]);
  }

  Future<void> updateBudgetSortOrder(String id, int sortOrder) async {
    final db = await database;
    await db.update(
      'budgets',
      {'sort_order': sortOrder},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteBudget(String id) async {
    final db = await database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // ── Recurring Transactions ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecurringTransactions() async {
    final db = await database;
    return db.query(
      'recurring_transactions',
      orderBy: 'sort_order ASC, rowid ASC',
    );
  }

  Future<void> insertRecurringTransaction(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'recurring_transactions',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateRecurringTransaction(Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'recurring_transactions',
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  Future<void> deleteRecurringTransaction(String id) async {
    final db = await database;
    await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateRecurringSortOrder(String id, int sortOrder) async {
    final db = await database;
    await db.update(
      'recurring_transactions',
      {'sort_order': sortOrder},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Recurring Occurrences ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecurringOccurrences() async {
    final db = await database;
    return db.query('recurring_occurrences', orderBy: 'due_date ASC');
  }

  Future<List<Map<String, dynamic>>> getOccurrencesFor(
    String recurringId,
  ) async {
    final db = await database;
    return db.query(
      'recurring_occurrences',
      where: 'recurring_id = ?',
      whereArgs: [recurringId],
      orderBy: 'due_date ASC',
    );
  }

  Future<void> insertRecurringOccurrence(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'recurring_occurrences',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteOccurrence(String id) async {
    final db = await database;
    await db.delete('recurring_occurrences', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteOccurrencesByRecurring(String recurringId) async {
    final db = await database;
    await db.delete(
      'recurring_occurrences',
      where: 'recurring_id = ?',
      whereArgs: [recurringId],
    );
  }
}
