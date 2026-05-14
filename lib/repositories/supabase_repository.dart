import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_repository.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../models/stock_holding.dart';
import 'supabase_adapters/account_adapter.dart';
import 'supabase_adapters/budget_adapter.dart';
import 'supabase_adapters/category_adapter.dart';
import 'supabase_adapters/portfolio_adapter.dart';
import 'supabase_adapters/recurring_adapter.dart';
import 'supabase_adapters/transaction_adapter.dart';

/// Supabase Repository Implementation
///
/// หมายเหตุเรื่อง DateTime:
/// - ใช้ timestamp without time zone (เก็บเวลา local โดยตรง)
/// - ไม่มีการแปลง timezone
/// - แปลงเป็น ISO8601 string เมื่อส่งไป Supabase
/// - รับค่ากลับมาเป็น DateTime หรือ String แล้ว parse กลับ
///
/// หมายเหตุเรื่อง Authentication:
/// - ทุก table มี user_id column เพื่อแยกข้อมูลต่อ user
/// - RLS policies จะตรวจสอบ auth.uid() = user_id
/// - ต้อง login ก่อนถึงจะใช้งานได้
class SupabaseRepository with RepositoryLogger implements DatabaseRepository {
  final String supabaseUrl;
  final String supabaseAnonKey;

  SupabaseClient? _client;
  bool _initialized = false;

  late final _accountAdapter = SupabaseAccountAdapter(this);
  late final _categoryAdapter = SupabaseCategoryAdapter(this);
  late final _transactionAdapter = SupabaseTransactionAdapter(this);
  late final _portfolioAdapter = SupabasePortfolioAdapter(this);
  late final _budgetAdapter = SupabaseBudgetAdapter(this);
  late final _recurringAdapter = SupabaseRecurringAdapter(this);

  SupabaseRepository({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  SupabaseClient get client {
    if (_client == null) {
      throw StateError('Supabase not initialized. Call init() first.');
    }
    return _client!;
  }

  /// ดึง user_id ของผู้ใช้ปัจจุบัน
  String? get currentUserId => _client?.auth.currentUser?.id;

  /// ตรวจสอบว่า user ได้ login หรือยัง
  bool get isAuthenticated => currentUserId != null;

  @override
  String get name => 'Supabase';

  @override
  Future<void> init() async {
    if (_initialized) {
      return;
    }

    // ตรวจสอบว่า Supabase ถูก initialize แล้วหรือไม่
    // โดยการลองเข้าถึง client ถ้าไม่ throw แสดงว่า initialize แล้ว
    bool isSupabaseInitialized = false;
    try {
      // ลองเข้าถึง Supabase.instance.client
      // ถ้า Supabase ถูก initialize แล้วจะได้ client กลับมา
      _client = Supabase.instance.client;
      isSupabaseInitialized = true;
    } catch (_) {
      // ยังไม่ได้ initialize หรือ initialize ไม่สมบูรณ์
      isSupabaseInitialized = false;
    }

    if (isSupabaseInitialized) {
      _initialized = true;
      debugPrint(
        '[SupabaseRepository] Supabase already initialized, reusing existing instance',
      );
      return;
    }

    // ยังไม่ได้ initialize → initialize ใหม่
    debugPrint(
      '[SupabaseRepository] Initializing Supabase with URL: $supabaseUrl',
    );
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

    _client = Supabase.instance.client;
    _initialized = true;
    debugPrint('[SupabaseRepository] Supabase initialized successfully');
  }

  @override
  Future<void> close() async {
    // Supabase singleton pattern, no explicit close needed
    _initialized = false;
    _client = null;
  }

  // ── Helper Methods ─────────────────────────────────────────────────────────

  /// ตรวจสอบว่า user ได้ login หรือไม่
  void _requireAuth() {
    if (!isAuthenticated) {
      throw StateError('User not authenticated. Please login first.');
    }
  }

  /// Convert Supabase response row เป็น Map ที่ใช้กับ Models (Public Helper)
  Map<String, dynamic> normalizeRow(Map<String, dynamic> row) =>
      _normalizeRow(row);

  /// Convert Supabase response row เป็น Map ที่ใช้กับ Models
  /// จัดการเรื่อง DateTime conversion ให้ถูกต้อง
  Map<String, dynamic> _normalizeRow(Map<String, dynamic> row) {
    final normalized = <String, dynamic>{};

    row.forEach((key, value) {
      // แปลง key จาก snake_case เป็น underscore format ตาม SQLite
      final sqliteKey = key;

      // จัดการ DateTime fields
      if (value is DateTime) {
        // ถ้าเป็น DateTime อยู่แล้ว แปลงเป็น ISO8601 string
        normalized[sqliteKey] = value.toIso8601String();
      } else if (key.contains('_date') ||
          key.contains('date_') ||
          key == 'date_time') {
        // ถ้าเป็น field ที่เกี่ยวกับวันที่ และเป็น String
        if (value is String) {
          normalized[sqliteKey] = value;
        } else if (value != null) {
          normalized[sqliteKey] = value.toString();
        } else {
          normalized[sqliteKey] = DateTime.now().toIso8601String();
        }
      } else {
        normalized[sqliteKey] = value;
      }
    });

    return normalized;
  }

  /// แปลง ARGB color เป็น signed int สำหรับ PostgreSQL (Static Helper)
  static int colorToSupabase(int argb) {
    if (argb > 2147483647) {
      return argb - 4294967296; // แปลงเป็น signed int
    }
    return argb;
  }

  /// แปลง signed int จาก PostgreSQL กลับเป็น ARGB (Static Helper)
  static int colorFromSupabase(int value) {
    if (value < 0) {
      return value + 4294967296; // แปลงกลับเป็น unsigned int
    }
    return value;
  }

  // ── Accounts (Delegated to Adapter) ───────────────────────────────────────

  @override
  Future<List<Account>> getAccounts() => _accountAdapter.getAccounts();

  @override
  Future<void> insertAccount(Account account) =>
      _accountAdapter.insertAccount(account);

  @override
  Future<void> updateAccount(Account account) =>
      _accountAdapter.updateAccount(account);

  @override
  Future<void> updateAccountSortOrder(String id, int sortOrder) =>
      _accountAdapter.updateAccountSortOrder(id, sortOrder);

  @override
  Future<void> deleteAccount(String id) => _accountAdapter.deleteAccount(id);

  // ── Categories (Delegated to Adapter) ─────────────────────────────────────

  @override
  Future<List<Category>> getCategories() => _categoryAdapter.getCategories();

  @override
  Future<void> insertCategory(Category category) =>
      _categoryAdapter.insertCategory(category);

  @override
  Future<void> updateCategory(Category category) =>
      _categoryAdapter.updateCategory(category);

  @override
  Future<void> updateCategorySortOrder(String id, int sortOrder) =>
      _categoryAdapter.updateCategorySortOrder(id, sortOrder);

  @override
  Future<void> deleteCategory(String id) => _categoryAdapter.deleteCategory(id);

  // ── Transactions (Delegated to Adapter) ───────────────────────────────────

  @override
  Future<List<AppTransaction>> getTransactions() =>
      _transactionAdapter.getTransactions();

  @override
  Future<void> insertTransaction(AppTransaction transaction) =>
      _transactionAdapter.insertTransaction(transaction);

  @override
  Future<void> updateTransaction(AppTransaction transaction) =>
      _transactionAdapter.updateTransaction(transaction);

  @override
  Future<void> deleteTransaction(String id) =>
      _transactionAdapter.deleteTransaction(id);

  // ── Portfolio Holdings (Delegated to Adapter) ─────────────────────────────

  @override
  Future<List<StockHolding>> getPortfolioHoldings() =>
      _portfolioAdapter.getPortfolioHoldings();

  @override
  Future<void> insertHolding(StockHolding holding) =>
      _portfolioAdapter.insertHolding(holding);

  @override
  Future<void> updateHolding(StockHolding holding) =>
      _portfolioAdapter.updateHolding(holding);

  @override
  Future<void> updateHoldingSortOrder(String id, int sortOrder) =>
      _portfolioAdapter.updateHoldingSortOrder(id, sortOrder);

  @override
  Future<void> deleteHolding(String id) => _portfolioAdapter.deleteHolding(id);

  @override
  Future<void> deleteHoldingsByPortfolio(String portfolioId) =>
      _portfolioAdapter.deleteHoldingsByPortfolio(portfolioId);

  // ── Budgets ────────────────────────────────────────────────────────────────

  // ── Budgets (Delegated to Adapter) ────────────────────────────────────────

  @override
  Future<List<Budget>> getBudgets() => _budgetAdapter.getBudgets();

  @override
  Future<void> insertBudget(Budget budget) =>
      _budgetAdapter.insertBudget(budget);

  @override
  Future<void> updateBudget(Budget budget) =>
      _budgetAdapter.updateBudget(budget);

  @override
  Future<void> updateBudgetSortOrder(String id, int sortOrder) =>
      _budgetAdapter.updateBudgetSortOrder(id, sortOrder);

  @override
  Future<void> deleteBudget(String id) => _budgetAdapter.deleteBudget(id);

  // ── Recurring Transactions (Delegated to Adapter) ─────────────────────────

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() =>
      _recurringAdapter.getRecurringTransactions();

  @override
  Future<void> insertRecurringTransaction(RecurringTransaction recurring) =>
      _recurringAdapter.insertRecurringTransaction(recurring);

  @override
  Future<void> updateRecurringTransaction(RecurringTransaction recurring) =>
      _recurringAdapter.updateRecurringTransaction(recurring);

  @override
  Future<void> deleteRecurringTransaction(String id) =>
      _recurringAdapter.deleteRecurringTransaction(id);

  @override
  Future<void> updateRecurringSortOrder(String id, int sortOrder) =>
      _recurringAdapter.updateRecurringSortOrder(id, sortOrder);

  // ── Recurring Occurrences (Delegated to Adapter) ──────────────────────────

  @override
  Future<List<RecurringOccurrence>> getRecurringOccurrences() =>
      _recurringAdapter.getRecurringOccurrences();

  @override
  Future<List<RecurringOccurrence>> getOccurrencesFor(String recurringId) =>
      _recurringAdapter.getOccurrencesFor(recurringId);

  @override
  Future<void> insertRecurringOccurrence(RecurringOccurrence occurrence) =>
      _recurringAdapter.insertRecurringOccurrence(occurrence);

  @override
  Future<void> deleteOccurrence(String id) =>
      _recurringAdapter.deleteOccurrence(id);

  @override
  Future<void> deleteOccurrencesByRecurring(String recurringId) =>
      _recurringAdapter.deleteOccurrencesByRecurring(recurringId);

  // ── Migration Helpers ──────────────────────────────────────────────────────

  @override
  Future<void> clearAllData() async {
    _requireAuth();
    log('Clearing all data for user: $currentUserId');

    // ลบตามลำดับ dependencies (child -> parent)
    // ใช้ .select() เพื่อดูจำนวนที่ลบ
    final occurrences = await client
        .from('recurring_occurrences')
        .delete()
        .eq('user_id', currentUserId!)
        .select();
    log('Deleted ${occurrences.length} occurrences');

    final recurring = await client
        .from('recurring_transactions')
        .delete()
        .eq('user_id', currentUserId!)
        .select();
    log('Deleted ${recurring.length} recurring transactions');

    final transactions = await client
        .from('transactions')
        .delete()
        .eq('user_id', currentUserId!)
        .select();
    log('Deleted ${transactions.length} transactions');

    final holdings = await client
        .from('portfolio_holdings')
        .delete()
        .eq('user_id', currentUserId!)
        .select();
    log('Deleted ${holdings.length} holdings');

    final budgets = await client
        .from('budgets')
        .delete()
        .eq('user_id', currentUserId!)
        .select();
    log('Deleted ${budgets.length} budgets');

    final categories = await client
        .from('categories')
        .delete()
        .eq('user_id', currentUserId!)
        .select();
    log('Deleted ${categories.length} categories');

    final accounts = await client
        .from('accounts')
        .delete()
        .eq('user_id', currentUserId!)
        .select();
    log('Deleted ${accounts.length} accounts');

    log('All data cleared for user: $currentUserId');
  }

  @override
  Future<bool> isConnected() async {
    try {
      // ลอง query table ถ้าไม่มี table จะได้ error code 42P01
      // ถ้าเชื่อมต่อไม่ได้จะได้ error อื่น (เช่น network error)
      await client.from('accounts').select('count').limit(1);
      log('Connection check: success (table exists)');
      return true;
    } on PostgrestException catch (e) {
      // Error code 42P01 = table does not exist (ไม่มี table)
      // Error code 42501 = permission denied (RLS หรือ permission)
      // ถ้าเป็น error พวกนี้แสดงว่าเชื่อมต่อได้ แค่ยังไม่สร้าง table
      log('PostgrestException caught: code=${e.code}, message=${e.message}');
      if (e.code == '42P01' || e.code == '42501' || e.code == 'PGRST301') {
        log('Connected but table not ready (code: ${e.code})');
        return true;
      }
      logError(
        'Connection check failed (PostgrestException: ${e.code})',
        e.message,
      );
      return false;
    } on AuthException catch (e) {
      logError('Connection check failed (AuthException)', e.message);
      return false;
    } on FormatException catch (e) {
      logError('Connection check failed (FormatException)', e.message);
      return false;
    } catch (e, stackTrace) {
      logError('Connection check failed (Unknown)', e.toString());
      logError('Stack trace', stackTrace.toString());
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> healthCheck() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await client
          .from('accounts')
          .select('count')
          .eq('user_id', currentUserId!)
          .limit(1);
      stopwatch.stop();
      return {
        'status': 'healthy',
        'latencyMs': stopwatch.elapsedMilliseconds,
        'response': response,
      };
    } catch (e) {
      stopwatch.stop();
      logError('Health check failed', e);
      return {
        'status': 'error',
        'error': e.toString(),
        'latencyMs': stopwatch.elapsedMilliseconds,
      };
    }
  }

  /// Bulk insert สำหรับ migration (batch operation)
  /// แบ่งเป็น batch ละ 500 records เพื่อป้องกัน timeout
  static const int _batchSize = 500;

  @override
  Future<void> bulkInsertAccounts(List<Account> accounts) =>
      _accountAdapter.bulkInsertAccounts(accounts);

  @override
  Future<void> bulkInsertCategories(List<Category> categories) =>
      _categoryAdapter.bulkInsertCategories(categories);

  @override
  Future<void> bulkInsertTransactions(List<AppTransaction> transactions) =>
      _transactionAdapter.bulkInsertTransactions(transactions);

  @override
  Future<void> bulkInsertBudgets(List<Budget> budgets) =>
      _budgetAdapter.bulkInsertBudgets(budgets);

  @override
  Future<void> bulkInsertHoldings(List<StockHolding> holdings) =>
      _portfolioAdapter.bulkInsertHoldings(holdings);

  @override
  Future<void> bulkInsertRecurring(List<RecurringTransaction> recurring) =>
      _recurringAdapter.bulkInsertRecurring(recurring);

  @override
  Future<void> bulkInsertOccurrences(List<RecurringOccurrence> occurrences) =>
      _recurringAdapter.bulkInsertOccurrences(occurrences);

  // ── Bulk Import: Get Existing IDs ──────────────────────────────────────────

  @override
  @override
  Future<Set<String>> getExistingAccountIds() =>
      _accountAdapter.getExistingAccountIds();

  @override
  @override
  Future<Set<String>> getExistingCategoryIds() =>
      _categoryAdapter.getExistingCategoryIds();

  @override
  @override
  Future<Set<String>> getExistingTransactionIds() =>
      _transactionAdapter.getExistingTransactionIds();

  @override
  @override
  Future<Set<String>> getExistingBudgetIds() =>
      _budgetAdapter.getExistingBudgetIds();

  @override
  @override
  Future<Set<String>> getExistingHoldingIds() =>
      _portfolioAdapter.getExistingHoldingIds();

  @override
  @override
  Future<Set<String>> getExistingRecurringIds() =>
      _recurringAdapter.getExistingRecurringIds();

  @override
  @override
  Future<Set<String>> getExistingOccurrenceIds() =>
      _recurringAdapter.getExistingOccurrenceIds();

  /// Helper สำหรับ batch insert (Public wrapper สำหรับ Adapter)
  Future<void> batchInsert(String table, List<Map<String, dynamic>> data) =>
      _batchInsert(table, data);

  /// Helper สำหรับ batch insert
  /// ใช้ insert แบบ ignore conflicts (upsert แต่ไม่ update)
  Future<void> _batchInsert(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    if (data.isEmpty) return;

    for (var i = 0; i < data.length; i += _batchSize) {
      final end = (i + _batchSize < data.length) ? i + _batchSize : data.length;
      final batch = data.sublist(i, end);

      log(
        'Inserting batch ${i ~/ _batchSize + 1}: ${batch.length} records to $table',
      );
      try {
        // ใช้ upsert แต่กำหนด ignoreDuplicates เพื่อ skip ข้อมูลที่มีอยู่แล้ว
        await client
            .from(table)
            .upsert(batch, onConflict: 'id', ignoreDuplicates: true);
      } catch (e) {
        logError('Error inserting batch to $table', e);
        // ถ้า ignoreDuplicates ไม่รองรับ ให้ log แล้วข้าม
        rethrow;
      }
    }

    log('Completed inserting ${data.length} records to $table');
  }
}
