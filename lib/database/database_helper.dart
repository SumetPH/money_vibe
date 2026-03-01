import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  DatabaseHelper._();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'money.db');
    return openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE accounts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            initial_balance REAL NOT NULL DEFAULT 0,
            currency TEXT NOT NULL DEFAULT 'THB',
            start_date INTEGER NOT NULL,
            icon INTEGER NOT NULL,
            color INTEGER NOT NULL,
            exclude_from_net_worth INTEGER NOT NULL DEFAULT 0,
            is_hidden INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            cash_balance REAL NOT NULL DEFAULT 0,
            exchange_rate REAL NOT NULL DEFAULT 35.0,
            auto_update_rate INTEGER NOT NULL DEFAULT 1
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
            is_default INTEGER NOT NULL DEFAULT 0,
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
            payee TEXT,
            location TEXT,
            date_time INTEGER NOT NULL,
            note TEXT,
            tags TEXT NOT NULL DEFAULT '',
            is_cleared INTEGER NOT NULL DEFAULT 0,
            record_date INTEGER
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE accounts ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE categories ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE accounts ADD COLUMN cash_balance REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE accounts ADD COLUMN exchange_rate REAL NOT NULL DEFAULT 35.0',
          );
          await db.execute('''
            CREATE TABLE portfolio_holdings (
              id TEXT PRIMARY KEY,
              portfolio_id TEXT NOT NULL,
              ticker TEXT NOT NULL,
              name TEXT NOT NULL DEFAULT '',
              shares REAL NOT NULL DEFAULT 0,
              price_usd REAL NOT NULL DEFAULT 0,
              sort_order INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE portfolio_holdings ADD COLUMN cost_basis_usd REAL NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE accounts ADD COLUMN auto_update_rate INTEGER NOT NULL DEFAULT 1',
          );
        }
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
}
