// Foundation debugPrint is accessed through RepositoryLogger mixin
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_repository.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../models/stock_holding.dart';

/// Supabase Repository Implementation
/// 
/// หมายเหตุเรื่อง DateTime:
/// - ใช้ timestamp without time zone (เก็บเวลา local โดยตรง)
/// - ไม่มีการแปลง timezone
/// - แปลงเป็น ISO8601 string เมื่อส่งไป Supabase
/// - รับค่ากลับมาเป็น DateTime หรือ String แล้ว parse กลับ
class SupabaseRepository with RepositoryLogger implements DatabaseRepository {
  final String supabaseUrl;
  final String supabaseAnonKey;
  
  SupabaseClient? _client;
  bool _initialized = false;

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

  @override
  String get name => 'Supabase';

  @override
  Future<void> init() async {
    if (_initialized) {

      return;
    }


    
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    
    _client = Supabase.instance.client;
    _initialized = true;

  }

  @override
  Future<void> close() async {
    // Supabase singleton pattern, no explicit close needed
    _initialized = false;
    _client = null;
  }

  // ── Helper Methods ─────────────────────────────────────────────────────────

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
      } else if (key.contains('_date') || key.contains('date_') || key == 'date_time') {
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

  /// แปลง ARGB color เป็น signed int สำหรับ PostgreSQL
  /// PostgreSQL integer เป็น signed 32-bit (-2,147,483,648 to 2,147,483,647)
  /// แต่ Flutter ARGB เป็น unsigned 32-bit (0 to 4,294,967,295)
  int _colorToSupabase(int argb) {
    if (argb > 2147483647) {
      return argb - 4294967296; // แปลงเป็น signed int
    }
    return argb;
  }

  /// แปลง signed int จาก PostgreSQL กลับเป็น ARGB
  int _colorFromSupabase(int value) {
    if (value < 0) {
      return value + 4294967296; // แปลงกลับเป็น unsigned int
    }
    return value;
  }

  /// แปลง Account เป็น format ที่ Supabase เข้าใจ
  Map<String, dynamic> _accountToSupabase(Account account) {
    return {
      'id': account.id,
      'name': account.name,
      'type': account.type.name,
      'initial_balance': account.initialBalance,
      'currency': account.currency,
      'start_date': account.startDate.toIso8601String(),
      'icon': account.icon.codePoint,
      'color': _colorToSupabase(account.color.toARGB32()),
      'exclude_from_net_worth': account.excludeFromNetWorth ? 1 : 0,
      'is_hidden': account.isHidden ? 1 : 0,
      'sort_order': account.sortOrder,
      'cash_balance': account.cashBalance,
      'exchange_rate': account.exchangeRate,
      'auto_update_rate': account.autoUpdateRate ? 1 : 0,
      'statement_day': account.statementDay,
    };
  }

  Account _accountFromSupabase(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    // แปลง color จาก signed int กลับเป็น ARGB
    if (normalized['color'] is int) {
      normalized['color'] = _colorFromSupabase(normalized['color'] as int);
    }
    // Debug: ตรวจสอบค่า sort_order
    if (normalized['sort_order'] == null) {
      log('Warning: sort_order is null for account ${normalized['id']}');
    }
    return Account.fromMap(normalized);
  }

  /// แปลง Category เป็น format ที่ Supabase เข้าใจ
  Map<String, dynamic> _categoryToSupabase(Category category) {
    return {
      'id': category.id,
      'name': category.name,
      'type': category.type.name,
      'icon': category.icon.codePoint,
      'color': _colorToSupabase(category.color.toARGB32()),
      'parent_id': category.parentId,
      'note': category.note ?? '',
      'sort_order': category.sortOrder,
    };
  }

  Category _categoryFromSupabase(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    // แปลง color จาก signed int กลับเป็น ARGB
    if (normalized['color'] is int) {
      normalized['color'] = _colorFromSupabase(normalized['color'] as int);
    }
    return Category.fromMap(normalized);
  }

  /// แปลง Transaction เป็น format ที่ Supabase เข้าใจ
  Map<String, dynamic> _transactionToSupabase(AppTransaction transaction) {
    return {
      'id': transaction.id,
      'type': transaction.type.name,
      'amount': transaction.amount,
      'account_id': transaction.accountId,
      'category_id': transaction.categoryId,
      'to_account_id': transaction.toAccountId,
      'date_time': transaction.dateTime.toIso8601String(),
      'note': transaction.note,
      'tags': transaction.tags.join(','),
    };
  }

  AppTransaction _transactionFromSupabase(Map<String, dynamic> row) {
    final normalized = _normalizeRow(row);
    return AppTransaction.fromMap(normalized);
  }

  /// แปลง Budget เป็น format ที่ Supabase เข้าใจ
  Map<String, dynamic> _budgetToSupabase(Budget budget) {
    return {
      'id': budget.id,
      'name': budget.name,
      'amount': budget.amount,
      'category_ids': budget.categoryIds.join(','),
      'icon': budget.icon.codePoint,
      'color': _colorToSupabase(budget.color.toARGB32()),
      'sort_order': budget.sortOrder,
    };
  }

  Budget _budgetFromSupabase(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    // แปลง color จาก signed int กลับเป็น ARGB
    if (normalized['color'] is int) {
      normalized['color'] = _colorFromSupabase(normalized['color'] as int);
    }
    return Budget.fromMap(normalized);
  }

  /// แปลง RecurringTransaction เป็น format ที่ Supabase เข้าใจ
  Map<String, dynamic> _recurringToSupabase(RecurringTransaction recurring) {
    return {
      'id': recurring.id,
      'name': recurring.name,
      'icon': recurring.icon.codePoint,
      'color': _colorToSupabase(recurring.color.toARGB32()),
      'start_date': recurring.startDate.toIso8601String(),
      'end_date': recurring.endDate?.toIso8601String(),
      'day_of_month': recurring.dayOfMonth,
      'transaction_type': recurring.transactionType.name,
      'amount': recurring.amount,
      'account_id': recurring.accountId,
      'to_account_id': recurring.toAccountId,
      'category_id': recurring.categoryId,
      'note': recurring.note,
      'sort_order': recurring.sortOrder,
    };
  }

  RecurringTransaction _recurringFromSupabase(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    // แปลง color จาก signed int กลับเป็น ARGB
    if (normalized['color'] is int) {
      normalized['color'] = _colorFromSupabase(normalized['color'] as int);
    }
    return RecurringTransaction.fromMap(normalized);
  }

  /// แปลง RecurringOccurrence เป็น format ที่ Supabase เข้าใจ
  Map<String, dynamic> _occurrenceToSupabase(RecurringOccurrence occurrence) {
    return {
      'id': occurrence.id,
      'recurring_id': occurrence.recurringId,
      'due_date': occurrence.dueDate.toIso8601String(),
      'transaction_id': occurrence.transactionId,
      'status': occurrence.status.name,
    };
  }

  RecurringOccurrence _occurrenceFromSupabase(Map<String, dynamic> row) {
    final normalized = _normalizeRow(row);
    return RecurringOccurrence.fromMap(normalized);
  }

  /// แปลง StockHolding เป็น format ที่ Supabase เข้าใจ
  Map<String, dynamic> _holdingToSupabase(StockHolding holding) {
    return {
      'id': holding.id,
      'portfolio_id': holding.portfolioId,
      'ticker': holding.ticker,
      'name': holding.name,
      'shares': holding.shares,
      'price_usd': holding.priceUsd,
      'cost_basis_usd': holding.costBasisUsd,
      'sort_order': holding.sortOrder,
    };
  }

  StockHolding _holdingFromSupabase(Map<String, dynamic> row) {
    final normalized = _normalizeRow(row);
    return StockHolding.fromMap(normalized);
  }

  // ── Accounts ──────────────────────────────────────────────────────────────

  @override
  Future<List<Account>> getAccounts() async {
    log('Fetching accounts...');
    final response = await client.from('accounts').select().order('sort_order');
    return (response as List).map((row) => _accountFromSupabase(row)).toList();
  }

  @override
  Future<void> insertAccount(Account account) async {
    log('Inserting account: ${account.id}');
    await client.from('accounts').insert(_accountToSupabase(account));
  }

  @override
  Future<void> updateAccount(Account account) async {
    log('Updating account: ${account.id}');
    await client
        .from('accounts')
        .update(_accountToSupabase(account))
        .eq('id', account.id);
  }

  @override
  Future<void> updateAccountSortOrder(String id, int sortOrder) async {
    log('Updating account sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('accounts')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .select();
      
      if ((response as List).isEmpty) {
        throw Exception('Failed to update account sort order: No rows affected');
      }
      log('Updated account sort order successfully: $id');
    } catch (e) {
      logError('Error updating account sort order', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    log('Deleting account: $id');
    await client.from('accounts').delete().eq('id', id);
  }

  // ── Categories ────────────────────────────────────────────────────────────

  @override
  Future<List<Category>> getCategories() async {
    log('Fetching categories...');
    final response = await client.from('categories').select().order('sort_order');
    return (response as List).map((row) => _categoryFromSupabase(row)).toList();
  }

  @override
  Future<void> insertCategory(Category category) async {
    log('Inserting category: ${category.id}');
    await client.from('categories').insert(_categoryToSupabase(category));
  }

  @override
  Future<void> updateCategory(Category category) async {
    log('Updating category: ${category.id}');
    await client
        .from('categories')
        .update(_categoryToSupabase(category))
        .eq('id', category.id);
  }

  @override
  Future<void> updateCategorySortOrder(String id, int sortOrder) async {
    log('Updating category sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('categories')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .select();
      
      if ((response as List).isEmpty) {
        throw Exception('Failed to update category sort order: No rows affected');
      }
      log('Updated category sort order successfully: $id');
    } catch (e) {
      logError('Error updating category sort order', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    log('Deleting category: $id');
    await client.from('categories').delete().eq('id', id);
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  @override
  Future<List<AppTransaction>> getTransactions() async {
    log('Fetching transactions with pagination...');
    final allTransactions = <AppTransaction>[];
    int offset = 0;
    const int pageSize = 1000;
    
    while (true) {

      final response = await client
          .from('transactions')
          .select()
          .order('date_time', ascending: false)
          .range(offset, offset + pageSize - 1);
      
      final batch = (response as List).map((row) => _transactionFromSupabase(row)).toList();

      
      if (batch.isEmpty) {

        break;
      }
      
      allTransactions.addAll(batch);
      
      if (batch.length < pageSize) {

        break;
      }
      
      offset += pageSize;

    }
    
    log('Fetched ${allTransactions.length} transactions total');
    return allTransactions;
  }

  @override
  Future<void> insertTransaction(AppTransaction transaction) async {
    log('Inserting transaction: ${transaction.id}');
    await client.from('transactions').insert(_transactionToSupabase(transaction));
  }

  @override
  Future<void> updateTransaction(AppTransaction transaction) async {
    log('Updating transaction: ${transaction.id}');
    await client
        .from('transactions')
        .update(_transactionToSupabase(transaction))
        .eq('id', transaction.id);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    log('Deleting transaction: $id');
    await client.from('transactions').delete().eq('id', id);
  }

  // ── Portfolio Holdings ─────────────────────────────────────────────────────

  @override
  Future<List<StockHolding>> getPortfolioHoldings() async {
    log('Fetching portfolio holdings...');
    final response = await client.from('portfolio_holdings').select().order('sort_order');
    return (response as List).map((row) => _holdingFromSupabase(row)).toList();
  }

  @override
  Future<void> insertHolding(StockHolding holding) async {
    log('Inserting holding: ${holding.id}');
    await client.from('portfolio_holdings').insert(_holdingToSupabase(holding));
  }

  @override
  Future<void> updateHolding(StockHolding holding) async {
    log('Updating holding: ${holding.id}');
    await client
        .from('portfolio_holdings')
        .update(_holdingToSupabase(holding))
        .eq('id', holding.id);
  }

  @override
  Future<void> deleteHolding(String id) async {
    log('Deleting holding: $id');
    await client.from('portfolio_holdings').delete().eq('id', id);
  }

  @override
  Future<void> deleteHoldingsByPortfolio(String portfolioId) async {
    log('Deleting holdings for portfolio: $portfolioId');
    await client.from('portfolio_holdings').delete().eq('portfolio_id', portfolioId);
  }

  // ── Budgets ────────────────────────────────────────────────────────────────

  @override
  Future<List<Budget>> getBudgets() async {
    log('Fetching budgets...');
    final response = await client.from('budgets').select().order('sort_order');
    return (response as List).map((row) => _budgetFromSupabase(row)).toList();
  }

  @override
  Future<void> insertBudget(Budget budget) async {
    log('Inserting budget: ${budget.id}');
    await client.from('budgets').insert(_budgetToSupabase(budget));
  }

  @override
  Future<void> updateBudget(Budget budget) async {
    log('Updating budget: ${budget.id}');
    await client
        .from('budgets')
        .update(_budgetToSupabase(budget))
        .eq('id', budget.id);
  }

  @override
  Future<void> updateBudgetSortOrder(String id, int sortOrder) async {
    log('Updating budget sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('budgets')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .select();
      
      if ((response as List).isEmpty) {
        throw Exception('Failed to update budget sort order: No rows affected');
      }
      log('Updated budget sort order successfully: $id');
    } catch (e) {
      logError('Error updating budget sort order', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    log('Deleting budget: $id');
    await client.from('budgets').delete().eq('id', id);
  }

  // ── Recurring Transactions ─────────────────────────────────────────────────

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    log('Fetching recurring transactions...');
    final response = await client.from('recurring_transactions').select().order('sort_order');
    return (response as List).map((row) => _recurringFromSupabase(row)).toList();
  }

  @override
  Future<void> insertRecurringTransaction(RecurringTransaction recurring) async {
    log('Inserting recurring transaction: ${recurring.id}');
    await client.from('recurring_transactions').insert(_recurringToSupabase(recurring));
  }

  @override
  Future<void> updateRecurringTransaction(RecurringTransaction recurring) async {
    log('Updating recurring transaction: ${recurring.id}');
    await client
        .from('recurring_transactions')
        .update(_recurringToSupabase(recurring))
        .eq('id', recurring.id);
  }

  @override
  Future<void> deleteRecurringTransaction(String id) async {
    log('Deleting recurring transaction: $id');
    await client.from('recurring_transactions').delete().eq('id', id);
  }

  @override
  Future<void> updateRecurringSortOrder(String id, int sortOrder) async {
    log('Updating recurring sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('recurring_transactions')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .select();
      
      if ((response as List).isEmpty) {
        throw Exception('Failed to update recurring sort order: No rows affected');
      }
      log('Updated recurring sort order successfully: $id');
    } catch (e) {
      logError('Error updating recurring sort order', e);
      rethrow;
    }
  }

  // ── Recurring Occurrences ──────────────────────────────────────────────────

  @override
  Future<List<RecurringOccurrence>> getRecurringOccurrences() async {
    log('Fetching recurring occurrences...');
    final response = await client.from('recurring_occurrences').select().order('due_date');
    return (response as List).map((row) => _occurrenceFromSupabase(row)).toList();
  }

  @override
  Future<List<RecurringOccurrence>> getOccurrencesFor(String recurringId) async {
    log('Fetching occurrences for: $recurringId');
    final response = await client
        .from('recurring_occurrences')
        .select()
        .eq('recurring_id', recurringId)
        .order('due_date');
    return (response as List).map((row) => _occurrenceFromSupabase(row)).toList();
  }

  @override
  Future<void> insertRecurringOccurrence(RecurringOccurrence occurrence) async {
    log('Inserting occurrence: ${occurrence.id}');
    await client.from('recurring_occurrences').insert(_occurrenceToSupabase(occurrence));
  }

  @override
  Future<void> deleteOccurrence(String id) async {
    log('Deleting occurrence: $id');
    await client.from('recurring_occurrences').delete().eq('id', id);
  }

  @override
  Future<void> deleteOccurrencesByRecurring(String recurringId) async {
    log('Deleting occurrences for recurring: $recurringId');
    await client.from('recurring_occurrences').delete().eq('recurring_id', recurringId);
  }

  // ── Migration Helpers ──────────────────────────────────────────────────────

  @override
  Future<void> clearAllData() async {
    log('Clearing all data...');
    
    // ลบตามลำดับ dependencies (child -> parent)
    await client.from('recurring_occurrences').delete().neq('id', '');
    await client.from('recurring_transactions').delete().neq('id', '');
    await client.from('transactions').delete().neq('id', '');
    await client.from('portfolio_holdings').delete().neq('id', '');
    await client.from('budgets').delete().neq('id', '');
    await client.from('categories').delete().neq('id', '');
    await client.from('accounts').delete().neq('id', '');
    
    log('All data cleared');
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
      logError('Connection check failed (PostgrestException: ${e.code})', e.message);
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
      final response = await client.from('accounts').select('count').limit(1);
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

  Future<void> bulkInsertAccounts(List<Account> accounts) async {
    log('Bulk inserting ${accounts.length} accounts...');
    await _batchInsert('accounts', accounts.map((a) => _accountToSupabase(a)).toList());
  }

  Future<void> bulkInsertCategories(List<Category> categories) async {
    log('Bulk inserting ${categories.length} categories...');
    await _batchInsert('categories', categories.map((c) => _categoryToSupabase(c)).toList());
  }

  Future<void> bulkInsertTransactions(List<AppTransaction> transactions) async {
    log('Bulk inserting ${transactions.length} transactions...');
    await _batchInsert('transactions', transactions.map((t) => _transactionToSupabase(t)).toList());
  }

  Future<void> bulkInsertBudgets(List<Budget> budgets) async {
    log('Bulk inserting ${budgets.length} budgets...');
    await _batchInsert('budgets', budgets.map((b) => _budgetToSupabase(b)).toList());
  }

  Future<void> bulkInsertHoldings(List<StockHolding> holdings) async {
    log('Bulk inserting ${holdings.length} holdings...');
    await _batchInsert('portfolio_holdings', holdings.map((h) => _holdingToSupabase(h)).toList());
  }

  Future<void> bulkInsertRecurring(List<RecurringTransaction> recurring) async {
    log('Bulk inserting ${recurring.length} recurring transactions...');
    await _batchInsert('recurring_transactions', recurring.map((r) => _recurringToSupabase(r)).toList());
  }

  Future<void> bulkInsertOccurrences(List<RecurringOccurrence> occurrences) async {
    log('Bulk inserting ${occurrences.length} occurrences...');
    await _batchInsert('recurring_occurrences', occurrences.map((o) => _occurrenceToSupabase(o)).toList());
  }

  /// Helper สำหรับ batch insert
  Future<void> _batchInsert(String table, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;

    for (var i = 0; i < data.length; i += _batchSize) {
      final end = (i + _batchSize < data.length) ? i + _batchSize : data.length;
      final batch = data.sublist(i, end);
      
      log('Inserting batch ${i ~/ _batchSize + 1}: ${batch.length} records to $table');
      await client.from(table).insert(batch);
    }
    
    log('Completed inserting ${data.length} records to $table');
  }
}
