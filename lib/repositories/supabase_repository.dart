import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
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
      debugPrint('[SupabaseRepository] Supabase already initialized, reusing existing instance');
      return;
    }

    // ยังไม่ได้ initialize → initialize ใหม่
    debugPrint('[SupabaseRepository] Initializing Supabase with URL: $supabaseUrl');
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    
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

  /// แปลง Account เป็น format ที่ Supabase เข้าใจ (รวม user_id)
  Map<String, dynamic> _accountToSupabase(Account account) {
    return {
      'id': account.id,
      'user_id': currentUserId,
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

  /// แปลง Category เป็น format ที่ Supabase เข้าใจ (รวม user_id)
  Map<String, dynamic> _categoryToSupabase(Category category) {
    return {
      'id': category.id,
      'user_id': currentUserId,
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

  /// แปลง Transaction เป็น format ที่ Supabase เข้าใจ (รวม user_id)
  Map<String, dynamic> _transactionToSupabase(AppTransaction transaction) {
    return {
      'id': transaction.id,
      'user_id': currentUserId,
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

  /// แปลง Budget เป็น format ที่ Supabase เข้าใจ (รวม user_id)
  Map<String, dynamic> _budgetToSupabase(Budget budget) {
    return {
      'id': budget.id,
      'user_id': currentUserId,
      'name': budget.name,
      'amount': budget.amount,
      'category_ids': jsonEncode(budget.categoryIds),
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

  /// แปลง RecurringTransaction เป็น format ที่ Supabase เข้าใจ (รวม user_id)
  Map<String, dynamic> _recurringToSupabase(RecurringTransaction recurring) {
    return {
      'id': recurring.id,
      'user_id': currentUserId,
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

  /// แปลง RecurringOccurrence เป็น format ที่ Supabase เข้าใจ (รวม user_id)
  Map<String, dynamic> _occurrenceToSupabase(RecurringOccurrence occurrence) {
    return {
      'id': occurrence.id,
      'user_id': currentUserId,
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

  /// แปลง StockHolding เป็น format ที่ Supabase เข้าใจ (รวม user_id)
  Map<String, dynamic> _holdingToSupabase(StockHolding holding) {
    return {
      'id': holding.id,
      'user_id': currentUserId,
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
    _requireAuth();
    log('Fetching accounts for user: $currentUserId');
    final response = await client
        .from('accounts')
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List).map((row) => _accountFromSupabase(row)).toList();
  }

  @override
  Future<void> insertAccount(Account account) async {
    _requireAuth();
    log('Inserting account: ${account.id} for user: $currentUserId');
    await client.from('accounts').insert(_accountToSupabase(account));
  }

  @override
  Future<void> updateAccount(Account account) async {
    _requireAuth();
    log('Updating account: ${account.id} for user: $currentUserId');
    await client
        .from('accounts')
        .update(_accountToSupabase(account))
        .eq('id', account.id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<void> updateAccountSortOrder(String id, int sortOrder) async {
    _requireAuth();
    log('Updating account sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('accounts')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .eq('user_id', currentUserId!)
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
    _requireAuth();
    log('Deleting account: $id for user: $currentUserId');
    await client
        .from('accounts')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  // ── Categories ────────────────────────────────────────────────────────────

  @override
  Future<List<Category>> getCategories() async {
    _requireAuth();
    log('Fetching categories for user: $currentUserId');
    final response = await client
        .from('categories')
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List).map((row) => _categoryFromSupabase(row)).toList();
  }

  @override
  Future<void> insertCategory(Category category) async {
    _requireAuth();
    log('Inserting category: ${category.id} for user: $currentUserId');
    await client.from('categories').insert(_categoryToSupabase(category));
  }

  @override
  Future<void> updateCategory(Category category) async {
    _requireAuth();
    log('Updating category: ${category.id} for user: $currentUserId');
    await client
        .from('categories')
        .update(_categoryToSupabase(category))
        .eq('id', category.id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<void> updateCategorySortOrder(String id, int sortOrder) async {
    _requireAuth();
    log('Updating category sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('categories')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .eq('user_id', currentUserId!)
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
    _requireAuth();
    log('Deleting category: $id for user: $currentUserId');
    await client
        .from('categories')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  @override
  Future<List<AppTransaction>> getTransactions() async {
    _requireAuth();
    log('Fetching transactions for user: $currentUserId');
    final allTransactions = <AppTransaction>[];
    int offset = 0;
    const int pageSize = 1000;
    
    while (true) {
      final response = await client
          .from('transactions')
          .select()
          .eq('user_id', currentUserId!)
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
    _requireAuth();
    log('Inserting transaction: ${transaction.id} for user: $currentUserId');
    await client.from('transactions').insert(_transactionToSupabase(transaction));
  }

  @override
  Future<void> updateTransaction(AppTransaction transaction) async {
    _requireAuth();
    log('Updating transaction: ${transaction.id} for user: $currentUserId');
    await client
        .from('transactions')
        .update(_transactionToSupabase(transaction))
        .eq('id', transaction.id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _requireAuth();
    log('Deleting transaction: $id for user: $currentUserId');
    await client
        .from('transactions')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  // ── Portfolio Holdings ─────────────────────────────────────────────────────

  @override
  Future<List<StockHolding>> getPortfolioHoldings() async {
    _requireAuth();
    log('Fetching portfolio holdings for user: $currentUserId');
    final response = await client
        .from('portfolio_holdings')
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List).map((row) => _holdingFromSupabase(row)).toList();
  }

  @override
  Future<void> insertHolding(StockHolding holding) async {
    _requireAuth();
    log('Inserting holding: ${holding.id} for user: $currentUserId');
    await client.from('portfolio_holdings').insert(_holdingToSupabase(holding));
  }

  @override
  Future<void> updateHolding(StockHolding holding) async {
    _requireAuth();
    log('Updating holding: ${holding.id} for user: $currentUserId');
    await client
        .from('portfolio_holdings')
        .update(_holdingToSupabase(holding))
        .eq('id', holding.id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<void> updateHoldingSortOrder(String id, int sortOrder) async {
    _requireAuth();
    log('Updating holding sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('portfolio_holdings')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .eq('user_id', currentUserId!)
          .select();
      
      if ((response as List).isEmpty) {
        throw Exception('Failed to update holding sort order: No rows affected');
      }
      log('Updated holding sort order successfully: $id');
    } catch (e) {
      logError('Error updating holding sort order', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteHolding(String id) async {
    _requireAuth();
    log('Deleting holding: $id for user: $currentUserId');
    await client
        .from('portfolio_holdings')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<void> deleteHoldingsByPortfolio(String portfolioId) async {
    _requireAuth();
    log('Deleting holdings for portfolio: $portfolioId, user: $currentUserId');
    await client
        .from('portfolio_holdings')
        .delete()
        .eq('portfolio_id', portfolioId)
        .eq('user_id', currentUserId!);
  }

  // ── Budgets ────────────────────────────────────────────────────────────────

  @override
  Future<List<Budget>> getBudgets() async {
    _requireAuth();
    log('Fetching budgets for user: $currentUserId');
    final response = await client
        .from('budgets')
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List).map((row) => _budgetFromSupabase(row)).toList();
  }

  @override
  Future<void> insertBudget(Budget budget) async {
    _requireAuth();
    log('Inserting budget: ${budget.id} for user: $currentUserId');
    await client.from('budgets').insert(_budgetToSupabase(budget));
  }

  @override
  Future<void> updateBudget(Budget budget) async {
    _requireAuth();
    log('Updating budget: ${budget.id} for user: $currentUserId');
    await client
        .from('budgets')
        .update(_budgetToSupabase(budget))
        .eq('id', budget.id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<void> updateBudgetSortOrder(String id, int sortOrder) async {
    _requireAuth();
    log('Updating budget sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('budgets')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .eq('user_id', currentUserId!)
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
    _requireAuth();
    log('Deleting budget: $id for user: $currentUserId');
    await client
        .from('budgets')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  // ── Recurring Transactions ─────────────────────────────────────────────────

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    _requireAuth();
    log('Fetching recurring transactions for user: $currentUserId');
    final response = await client
        .from('recurring_transactions')
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List).map((row) => _recurringFromSupabase(row)).toList();
  }

  @override
  Future<void> insertRecurringTransaction(RecurringTransaction recurring) async {
    _requireAuth();
    log('Inserting recurring transaction: ${recurring.id} for user: $currentUserId');
    await client.from('recurring_transactions').insert(_recurringToSupabase(recurring));
  }

  @override
  Future<void> updateRecurringTransaction(RecurringTransaction recurring) async {
    _requireAuth();
    log('Updating recurring transaction: ${recurring.id} for user: $currentUserId');
    await client
        .from('recurring_transactions')
        .update(_recurringToSupabase(recurring))
        .eq('id', recurring.id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<void> deleteRecurringTransaction(String id) async {
    _requireAuth();
    log('Deleting recurring transaction: $id for user: $currentUserId');
    await client
        .from('recurring_transactions')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<void> updateRecurringSortOrder(String id, int sortOrder) async {
    _requireAuth();
    log('Updating recurring sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('recurring_transactions')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .eq('user_id', currentUserId!)
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
    _requireAuth();
    log('Fetching recurring occurrences for user: $currentUserId');
    final response = await client
        .from('recurring_occurrences')
        .select()
        .eq('user_id', currentUserId!)
        .order('due_date');
    return (response as List).map((row) => _occurrenceFromSupabase(row)).toList();
  }

  @override
  Future<List<RecurringOccurrence>> getOccurrencesFor(String recurringId) async {
    _requireAuth();
    log('Fetching occurrences for: $recurringId, user: $currentUserId');
    final response = await client
        .from('recurring_occurrences')
        .select()
        .eq('recurring_id', recurringId)
        .eq('user_id', currentUserId!)
        .order('due_date');
    return (response as List).map((row) => _occurrenceFromSupabase(row)).toList();
  }

  @override
  Future<void> insertRecurringOccurrence(RecurringOccurrence occurrence) async {
    _requireAuth();
    log('Inserting occurrence: ${occurrence.id} for user: $currentUserId');
    await client.from('recurring_occurrences').insert(_occurrenceToSupabase(occurrence));
  }

  @override
  Future<void> deleteOccurrence(String id) async {
    _requireAuth();
    log('Deleting occurrence: $id for user: $currentUserId');
    await client
        .from('recurring_occurrences')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<void> deleteOccurrencesByRecurring(String recurringId) async {
    _requireAuth();
    log('Deleting occurrences for recurring: $recurringId, user: $currentUserId');
    await client
        .from('recurring_occurrences')
        .delete()
        .eq('recurring_id', recurringId)
        .eq('user_id', currentUserId!);
  }

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
  Future<void> bulkInsertAccounts(List<Account> accounts) async {
    _requireAuth();
    log('Bulk inserting ${accounts.length} accounts for user: $currentUserId');
    
    // ตรวจสอบว่ามี ID ซ้ำใน list หรือไม่
    final ids = accounts.map((a) => a.id).toList();
    final uniqueIds = ids.toSet();
    if (ids.length != uniqueIds.length) {
      log('WARNING: Found ${ids.length - uniqueIds.length} duplicate IDs in accounts list');
      log('Duplicate IDs: ${ids.where((id) => ids.where((x) => x == id).length > 1).toSet()}');
    }
    
    // Log ตัวอย่าง IDs ที่จะ insert (5 ตัวแรก)
    log('Sample IDs to insert: ${ids.take(5).toList()}');
    log('Sample account names: ${accounts.take(5).map((a) => '${a.id.substring(0, 8)}:${a.name}').toList()}');
    
    await _batchInsert('accounts', accounts.map((a) => _accountToSupabase(a)).toList());
  }

  @override
  Future<void> bulkInsertCategories(List<Category> categories) async {
    _requireAuth();
    log('Bulk inserting ${categories.length} categories for user: $currentUserId');
    await _batchInsert('categories', categories.map((c) => _categoryToSupabase(c)).toList());
  }

  @override
  Future<void> bulkInsertTransactions(List<AppTransaction> transactions) async {
    _requireAuth();
    log('Bulk inserting ${transactions.length} transactions for user: $currentUserId');
    await _batchInsert('transactions', transactions.map((t) => _transactionToSupabase(t)).toList());
  }

  @override
  Future<void> bulkInsertBudgets(List<Budget> budgets) async {
    _requireAuth();
    log('Bulk inserting ${budgets.length} budgets for user: $currentUserId');
    await _batchInsert('budgets', budgets.map((b) => _budgetToSupabase(b)).toList());
  }

  @override
  Future<void> bulkInsertHoldings(List<StockHolding> holdings) async {
    _requireAuth();
    log('Bulk inserting ${holdings.length} holdings for user: $currentUserId');
    await _batchInsert('portfolio_holdings', holdings.map((h) => _holdingToSupabase(h)).toList());
  }

  @override
  Future<void> bulkInsertRecurring(List<RecurringTransaction> recurring) async {
    _requireAuth();
    log('Bulk inserting ${recurring.length} recurring transactions for user: $currentUserId');
    await _batchInsert('recurring_transactions', recurring.map((r) => _recurringToSupabase(r)).toList());
  }

  @override
  Future<void> bulkInsertOccurrences(List<RecurringOccurrence> occurrences) async {
    _requireAuth();
    log('Bulk inserting ${occurrences.length} occurrences for user: $currentUserId');
    await _batchInsert('recurring_occurrences', occurrences.map((o) => _occurrenceToSupabase(o)).toList());
  }

  // ── Bulk Import: Get Existing IDs ──────────────────────────────────────────
  
  @override
  @override
  Future<Set<String>> getExistingAccountIds() async {
    _requireAuth();
    final response = await client
        .from('accounts')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }
  
  @override
  @override
  Future<Set<String>> getExistingCategoryIds() async {
    _requireAuth();
    final response = await client
        .from('categories')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }
  
  @override
  @override
  Future<Set<String>> getExistingTransactionIds() async {
    _requireAuth();
    final response = await client
        .from('transactions')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }
  
  @override
  @override
  Future<Set<String>> getExistingBudgetIds() async {
    _requireAuth();
    final response = await client
        .from('budgets')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }
  
  @override
  @override
  Future<Set<String>> getExistingHoldingIds() async {
    _requireAuth();
    final response = await client
        .from('portfolio_holdings')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }
  
  @override
  @override
  Future<Set<String>> getExistingRecurringIds() async {
    _requireAuth();
    final response = await client
        .from('recurring_transactions')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }
  
  @override
  @override
  Future<Set<String>> getExistingOccurrenceIds() async {
    _requireAuth();
    final response = await client
        .from('recurring_occurrences')
        .select('id');
    return (response as List).map((r) => r['id'] as String).toSet();
  }

  /// Helper สำหรับ batch insert
  /// ใช้ insert แบบ ignore conflicts (upsert แต่ไม่ update)
  Future<void> _batchInsert(String table, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;

    for (var i = 0; i < data.length; i += _batchSize) {
      final end = (i + _batchSize < data.length) ? i + _batchSize : data.length;
      final batch = data.sublist(i, end);
      
      log('Inserting batch ${i ~/ _batchSize + 1}: ${batch.length} records to $table');
      try {
        // ใช้ upsert แต่กำหนด ignoreDuplicates เพื่อ skip ข้อมูลที่มีอยู่แล้ว
        await client.from(table).upsert(batch, onConflict: 'id', ignoreDuplicates: true);
      } catch (e) {
        logError('Error inserting batch to $table', e);
        // ถ้า ignoreDuplicates ไม่รองรับ ให้ log แล้วข้าม
        rethrow;
      }
    }
    
    log('Completed inserting ${data.length} records to $table');
  }
}
