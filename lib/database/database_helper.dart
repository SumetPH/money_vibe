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
      version: 1,
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
            auto_clear INTEGER NOT NULL DEFAULT 1,
            show_on_main INTEGER NOT NULL DEFAULT 0,
            is_default INTEGER NOT NULL DEFAULT 0,
            exclude_from_net_worth INTEGER NOT NULL DEFAULT 0,
            is_hidden INTEGER NOT NULL DEFAULT 0,
            group_name TEXT,
            note TEXT
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
            note TEXT
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
      },
    );
  }

  // ── Accounts ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await database;
    return db.query('accounts', orderBy: 'rowid ASC');
  }

  Future<void> insertAccount(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('accounts', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAccount(Map<String, dynamic> data) async {
    final db = await database;
    await db.update('accounts', data,
        where: 'id = ?', whereArgs: [data['id']]);
  }

  Future<void> deleteAccount(String id) async {
    final db = await database;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return db.query('categories', orderBy: 'rowid ASC');
  }

  Future<void> insertCategory(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('categories', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCategory(Map<String, dynamic> data) async {
    final db = await database;
    await db.update('categories', data,
        where: 'id = ?', whereArgs: [data['id']]);
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
    await db.insert('transactions', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTransaction(Map<String, dynamic> data) async {
    final db = await database;
    await db.update('transactions', data,
        where: 'id = ?', whereArgs: [data['id']]);
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }
}
