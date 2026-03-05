import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/database_repository.dart';
import '../repositories/sqlite_repository.dart';
import '../repositories/supabase_repository.dart';

/// Service สำหรับจัดการ Database Repository
/// - เลือกใช้ SQLite หรือ Supabase
/// - สลับระหว่างโหมดได้ runtime
/// - รองรับการย้ายข้อมูล (migration)
class DatabaseManager extends ChangeNotifier {
  static const String _modeKey = 'database_mode';
  static const String _supabaseUrlKey = 'supabase_url';
  static const String _supabaseKeyKey = 'supabase_anon_key';

  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  DatabaseRepository? _currentRepository;
  SQLiteRepository? _sqliteRepo;
  SupabaseRepository? _supabaseRepo;

  DatabaseMode _currentMode = DatabaseMode.sqlite;

  String? _supabaseUrl;
  String? _supabaseAnonKey;

  bool _isLoading = false;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────

  DatabaseRepository get repository {
    if (_currentRepository == null) {
      throw StateError('DatabaseManager not initialized. Call init() first.');
    }
    return _currentRepository!;
  }

  DatabaseMode get currentMode => _currentMode;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  String? get supabaseUrl => _supabaseUrl;
  String? get supabaseAnonKey => _supabaseAnonKey;

  bool get isSupabaseMode => _currentMode == DatabaseMode.supabase;
  bool get isSqliteMode => _currentMode == DatabaseMode.sqlite;
  bool get canUseSupabase => _supabaseUrl != null && _supabaseAnonKey != null;

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Initialize DatabaseManager
  /// โหลดค่าตั้งค่าจาก SharedPreferences และเตรียม repository ที่เหมาะสม
  Future<void> init() async {
    debugPrint('[DatabaseManager] Initializing...');
    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // โหลดค่าตั้งค่า
      final modeIndex = prefs.getInt(_modeKey) ?? 0;
      final savedMode = DatabaseMode.values[modeIndex];
      _supabaseUrl = prefs.getString(_supabaseUrlKey);
      _supabaseAnonKey = prefs.getString(_supabaseKeyKey);

      debugPrint('[DatabaseManager] Saved mode: $savedMode');
      debugPrint('[DatabaseManager] Supabase URL set: ${_supabaseUrl != null}');
      debugPrint(
        '[DatabaseManager] Supabase Key set: ${_supabaseAnonKey != null}',
      );

      // Initialize SQLite (always available)
      _sqliteRepo = SQLiteRepository();
      await _sqliteRepo!.init();

      // เริ่มต้นด้วย SQLite mode (default)
      _currentMode = DatabaseMode.sqlite;
      _currentRepository = _sqliteRepo;

      // ถ้าเคยตั้งค่าเป็น Supabase ให้ลอง initialize Supabase ด้วย
      if (savedMode == DatabaseMode.supabase && canUseSupabase) {
        try {
          _supabaseRepo = SupabaseRepository(
            supabaseUrl: _supabaseUrl!,
            supabaseAnonKey: _supabaseAnonKey!,
          );
          await _supabaseRepo!.init();

          // ตรวจสอบว่ามี session อยู่หรือไม่ (login แล้ว)
          final client = _supabaseRepo!.client;
          if (client.auth.currentSession != null) {
            // Login แล้ว → switch ไป Supabase mode เลย
            _currentRepository = _supabaseRepo;
            _currentMode = DatabaseMode.supabase;
            debugPrint(
              '[DatabaseManager] Restored Supabase mode (already logged in)',
            );
          } else {
            // ยังไม่ได้ login → ใช้ SQLite ไปก่อน แต่เก็บ Supabase ไว้รอ
            debugPrint(
              '[DatabaseManager] Supabase ready but not logged in, using SQLite',
            );
          }
        } catch (e) {
          debugPrint('[DatabaseManager] Failed to init Supabase: $e');
          _supabaseRepo = null;
        }
      }

      _error = null;
      debugPrint(
        '[DatabaseManager] Initialized successfully in SQLite mode (Supabase ready: ${_supabaseRepo != null})',
      );
    } catch (e, stackTrace) {
      debugPrint('[DatabaseManager] Initialization error: $e');
      debugPrint('[DatabaseManager] Stack trace: $stackTrace');
      _error = e.toString();
      // Fallback to SQLite
      _currentRepository = _sqliteRepo;
      _currentMode = DatabaseMode.sqlite;
    } finally {
      _setLoading(false);
    }
  }

  // ── Mode Switching ─────────────────────────────────────────────────────────

  /// สลับไปใช้โหมดที่ระบุ
  Future<bool> switchMode(DatabaseMode mode) async {
    if (mode == _currentMode) {
      debugPrint('[DatabaseManager] Already in mode: $mode');
      return true;
    }

    return await _switchToMode(mode);
  }

  Future<bool> _switchToMode(DatabaseMode mode, {bool force = false}) async {
    if (!force) {
      _setLoading(true);
    }

    try {
      switch (mode) {
        case DatabaseMode.sqlite:
          _currentRepository = _sqliteRepo;
          _currentMode = DatabaseMode.sqlite;
          debugPrint('[DatabaseManager] Switched to SQLite mode');
          break;

        case DatabaseMode.supabase:
          if (!canUseSupabase) {
            throw Exception(
              'Supabase not configured. Please set URL and API Key first.',
            );
          }

          // Create new Supabase repository if needed
          if (_supabaseRepo == null ||
              _supabaseRepo!.supabaseUrl != _supabaseUrl ||
              _supabaseRepo!.supabaseAnonKey != _supabaseAnonKey) {
            _supabaseRepo = SupabaseRepository(
              supabaseUrl: _supabaseUrl!,
              supabaseAnonKey: _supabaseAnonKey!,
            );
            await _supabaseRepo!.init();
          }

          _currentRepository = _supabaseRepo;
          _currentMode = DatabaseMode.supabase;
          debugPrint('[DatabaseManager] Switched to Supabase mode');
          break;
      }

      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_modeKey, _currentMode.index);

      _error = null;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('[DatabaseManager] Switch mode error: $e');
      debugPrint('[DatabaseManager] Stack trace: $stackTrace');
      _error = e.toString();
      return false;
    } finally {
      if (!force) {
        _setLoading(false);
      }
    }
  }

  // ── Configuration ──────────────────────────────────────────────────────────

  /// ตั้งค่า Supabase credentials
  Future<bool> configureSupabase({
    required String url,
    required String anonKey,
  }) async {
    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_supabaseUrlKey, url);
      await prefs.setString(_supabaseKeyKey, anonKey);

      _supabaseUrl = url;
      _supabaseAnonKey = anonKey;

      // Reset Supabase repo to use new credentials
      _supabaseRepo = null;

      _error = null;
      notifyListeners();
      debugPrint('[DatabaseManager] Supabase configured successfully');
      return true;
    } catch (e) {
      debugPrint('[DatabaseManager] Configure error: $e');
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// ลบการตั้งค่า Supabase
  Future<void> clearSupabaseConfig() async {
    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_supabaseUrlKey);
      await prefs.remove(_supabaseKeyKey);

      _supabaseUrl = null;
      _supabaseAnonKey = null;
      _supabaseRepo = null;

      // Switch back to SQLite if currently on Supabase
      if (_currentMode == DatabaseMode.supabase) {
        await _switchToMode(DatabaseMode.sqlite, force: true);
      }

      _error = null;
      notifyListeners();
      debugPrint('[DatabaseManager] Supabase config cleared');
    } finally {
      _setLoading(false);
    }
  }

  // ── Data Migration ─────────────────────────────────────────────────────────

  /// ย้ายข้อมูลจาก SQLite ไป Supabase
  /// Returns: จำนวน records ที่ย้ายสำเร็จ
  Future<Map<String, int>> migrateToSupabase({
    Function(String status, double progress)? onProgress,
  }) async {
    if (!canUseSupabase) {
      throw Exception('Supabase not configured');
    }

    _setLoading(true);
    final results = <String, int>{};

    try {
      // Ensure Supabase is initialized
      if (_supabaseRepo == null) {
        _supabaseRepo = SupabaseRepository(
          supabaseUrl: _supabaseUrl!,
          supabaseAnonKey: _supabaseAnonKey!,
        );
        await _supabaseRepo!.init();
      }

      onProgress?.call('Fetching data from SQLite...', 0.0);

      // 1. Fetch all data from SQLite
      final accounts = await _sqliteRepo!.getAccounts();
      onProgress?.call('Fetched ${accounts.length} accounts', 0.1);

      final categories = await _sqliteRepo!.getCategories();
      onProgress?.call('Fetched ${categories.length} categories', 0.2);

      final transactions = await _sqliteRepo!.getTransactions();
      onProgress?.call('Fetched ${transactions.length} transactions', 0.3);

      final budgets = await _sqliteRepo!.getBudgets();
      onProgress?.call('Fetched ${budgets.length} budgets', 0.4);

      final holdings = await _sqliteRepo!.getPortfolioHoldings();
      onProgress?.call('Fetched ${holdings.length} holdings', 0.5);

      final recurring = await _sqliteRepo!.getRecurringTransactions();
      onProgress?.call('Fetched ${recurring.length} recurring', 0.6);

      final occurrences = await _sqliteRepo!.getRecurringOccurrences();
      onProgress?.call('Fetched ${occurrences.length} occurrences', 0.7);

      // 2. Clear existing Supabase data
      onProgress?.call('Clearing Supabase data...', 0.75);
      await _supabaseRepo!.clearAllData();

      // 3. Insert data to Supabase (in dependency order)
      onProgress?.call('Migrating accounts...', 0.8);
      if (accounts.isNotEmpty) {
        await _supabaseRepo!.bulkInsertAccounts(accounts);
      }
      results['accounts'] = accounts.length;

      onProgress?.call('Migrating categories...', 0.82);
      if (categories.isNotEmpty) {
        await _supabaseRepo!.bulkInsertCategories(categories);
      }
      results['categories'] = categories.length;

      onProgress?.call('Migrating budgets...', 0.84);
      if (budgets.isNotEmpty) {
        await _supabaseRepo!.bulkInsertBudgets(budgets);
      }
      results['budgets'] = budgets.length;

      onProgress?.call('Migrating holdings...', 0.86);
      if (holdings.isNotEmpty) {
        await _supabaseRepo!.bulkInsertHoldings(holdings);
      }
      results['holdings'] = holdings.length;

      // สร้าง set ของ valid IDs สำหรับเช็ค foreign keys
      final validAccountIds = accounts.map((a) => a.id).toSet();
      final validCategoryIds = categories.map((c) => c.id).toSet();

      onProgress?.call('Migrating recurring transactions...', 0.90);

      // กรอง recurring ที่มี account_id ไม่ valid ออก (เป็น data ของ user อื่น)
      final validRecurring = recurring.where((r) {
        if (!validAccountIds.contains(r.accountId)) {
          debugPrint(
            '[DatabaseManager] Skipping recurring ${r.id}: account ${r.accountId} not found (different user)',
          );
          return false;
        }
        return true;
      }).toList();

      if (validRecurring.isNotEmpty) {
        await _supabaseRepo!.bulkInsertRecurring(validRecurring);
      }
      results['recurring'] = validRecurring.length;
      results['recurring_skipped'] = recurring.length - validRecurring.length;

      onProgress?.call('Validating transactions...', 0.91);

      // กรอง transactions ที่มี account_id ไม่ valid ออก (should be none now)
      // และ set null ให้กับ category_id ที่ไม่ valid
      final validTransactions = transactions
          .where((t) {
            if (!validAccountIds.contains(t.accountId)) {
              debugPrint(
                '[DatabaseManager] Skipping transaction ${t.id}: account ${t.accountId} still not found',
              );
              return false;
            }
            return true;
          })
          .map((t) {
            var result = t;
            // ถ้า category_id ไม่ valid, set เป็น null
            if (t.categoryId != null &&
                !validCategoryIds.contains(t.categoryId)) {
              debugPrint(
                '[DatabaseManager] Clearing category for transaction ${t.id}: category ${t.categoryId} not found',
              );
              result = result.copyWith(clearCategoryId: true);
            }
            return result;
          })
          .toList();

      onProgress?.call(
        'Migrating ${validTransactions.length} transactions...',
        0.92,
      );
      if (validTransactions.isNotEmpty) {
        await _supabaseRepo!.bulkInsertTransactions(validTransactions);
      }
      results['transactions'] = validTransactions.length;
      results['transactions_skipped'] =
          transactions.length - validTransactions.length;

      onProgress?.call('Validating occurrences...', 0.95);
      // สร้าง set ของ valid recurring IDs (จาก validRecurring ที่กรองแล้ว)
      final validRecurringIds = validRecurring.map((r) => r.id).toSet();
      final validTransactionIds = validTransactions.map((t) => t.id).toSet();

      // กรอง occurrences ที่มี recurring_id หรือ transaction_id ไม่ valid ออก
      final validOccurrences = occurrences.where((o) {
        if (!validRecurringIds.contains(o.recurringId)) {
          debugPrint(
            '[DatabaseManager] Skipping occurrence ${o.id}: recurring ${o.recurringId} not found',
          );
          return false;
        }
        // ถ้ามี transaction_id ต้องเช็คว่า valid ด้วย
        if (o.transactionId != null &&
            !validTransactionIds.contains(o.transactionId)) {
          debugPrint(
            '[DatabaseManager] Clearing transaction for occurrence ${o.id}: transaction ${o.transactionId} not found',
          );
          // จะไม่ skip แต่จะ clear transaction_id ใน Supabase แทน
        }
        return true;
      }).toList();

      onProgress?.call(
        'Migrating ${validOccurrences.length} occurrences...',
        0.96,
      );
      if (validOccurrences.isNotEmpty) {
        await _supabaseRepo!.bulkInsertOccurrences(validOccurrences);
      }
      results['occurrences'] = validOccurrences.length;
      results['occurrences_skipped'] =
          occurrences.length - validOccurrences.length;

      onProgress?.call('Migration complete!', 1.0);

      // 4. Switch to Supabase mode
      await _switchToMode(DatabaseMode.supabase, force: true);

      debugPrint('[DatabaseManager] Migration complete: $results');
      return results;
    } catch (e, stackTrace) {
      debugPrint('[DatabaseManager] Migration error: $e');
      debugPrint('[DatabaseManager] Stack trace: $stackTrace');
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// ทดสอบการเชื่อมต่อ Supabase ด้วยค่าที่บันทึกไว้
  Future<bool> testSupabaseConnection() async {
    if (!canUseSupabase) {
      debugPrint('[DatabaseManager] Cannot test: Supabase not configured');
      return false;
    }

    return testSupabaseConnectionWithCredentials(
      url: _supabaseUrl!,
      anonKey: _supabaseAnonKey!,
    );
  }

  /// ทดสอบการเชื่อมต่อ Supabase ด้วยค่าที่ส่งมาโดยตรง (ไม่ต้องบันทึกก่อน)
  Future<bool> testSupabaseConnectionWithCredentials({
    required String url,
    required String anonKey,
  }) async {
    try {
      debugPrint('[DatabaseManager] Testing connection to: $url');

      // สร้าง repository ใหม่เพื่อเทส
      final testRepo = SupabaseRepository(
        supabaseUrl: url,
        supabaseAnonKey: anonKey,
      );

      debugPrint('[DatabaseManager] Initializing Supabase...');
      await testRepo.init();

      debugPrint('[DatabaseManager] Checking connection...');
      final result = await testRepo.isConnected();

      debugPrint('[DatabaseManager] Connection test result: $result');
      return result;
    } catch (e, stackTrace) {
      debugPrint('[DatabaseManager] Connection test failed: $e');
      debugPrint('[DatabaseManager] Stack trace: $stackTrace');
      return false;
    }
  }

  // ── Data Migration from Supabase to SQLite ───────────────────────────────

  /// ดึงข้อมูลจาก Supabase มา SQLite
  /// Returns: จำนวน records ที่ย้ายสำเร็จ
  Future<Map<String, int>> migrateFromSupabase({
    Function(String status, double progress)? onProgress,
  }) async {
    if (!canUseSupabase) {
      throw Exception('Supabase not configured');
    }

    _setLoading(true);
    final results = <String, int>{};

    try {
      // Ensure Supabase is initialized
      if (_supabaseRepo == null) {
        _supabaseRepo = SupabaseRepository(
          supabaseUrl: _supabaseUrl!,
          supabaseAnonKey: _supabaseAnonKey!,
        );
        await _supabaseRepo!.init();
      }

      onProgress?.call('Fetching data from Supabase...', 0.0);

      // 1. Fetch all data from Supabase
      final accounts = await _supabaseRepo!.getAccounts();
      onProgress?.call('Fetched ${accounts.length} accounts', 0.1);

      final categories = await _supabaseRepo!.getCategories();
      onProgress?.call('Fetched ${categories.length} categories', 0.2);

      final transactions = await _supabaseRepo!.getTransactions();
      onProgress?.call('Fetched ${transactions.length} transactions', 0.3);

      final budgets = await _supabaseRepo!.getBudgets();
      onProgress?.call('Fetched ${budgets.length} budgets', 0.4);

      final holdings = await _supabaseRepo!.getPortfolioHoldings();
      onProgress?.call('Fetched ${holdings.length} holdings', 0.5);

      final recurring = await _supabaseRepo!.getRecurringTransactions();
      onProgress?.call('Fetched ${recurring.length} recurring', 0.6);

      final occurrences = await _supabaseRepo!.getRecurringOccurrences();
      onProgress?.call('Fetched ${occurrences.length} occurrences', 0.7);

      // 2. Clear existing SQLite data
      onProgress?.call('Clearing SQLite data...', 0.75);
      await _sqliteRepo!.clearAllData();

      // 3. Insert data to SQLite (in dependency order)
      onProgress?.call('Migrating accounts...', 0.8);
      for (final account in accounts) {
        await _sqliteRepo!.insertAccount(account);
      }
      results['accounts'] = accounts.length;

      onProgress?.call('Migrating categories...', 0.82);
      for (final category in categories) {
        await _sqliteRepo!.insertCategory(category);
      }
      results['categories'] = categories.length;

      onProgress?.call('Migrating budgets...', 0.84);
      for (final budget in budgets) {
        await _sqliteRepo!.insertBudget(budget);
      }
      results['budgets'] = budgets.length;

      onProgress?.call('Migrating holdings...', 0.86);
      for (final holding in holdings) {
        await _sqliteRepo!.insertHolding(holding);
      }
      results['holdings'] = holdings.length;

      onProgress?.call('Migrating recurring transactions...', 0.90);
      for (final r in recurring) {
        await _sqliteRepo!.insertRecurringTransaction(r);
      }
      results['recurring'] = recurring.length;

      onProgress?.call('Migrating transactions...', 0.92);
      for (final transaction in transactions) {
        await _sqliteRepo!.insertTransaction(transaction);
      }
      results['transactions'] = transactions.length;

      onProgress?.call('Migrating occurrences...', 0.96);
      for (final occurrence in occurrences) {
        await _sqliteRepo!.insertRecurringOccurrence(occurrence);
      }
      results['occurrences'] = occurrences.length;

      onProgress?.call('Migration complete!', 1.0);

      debugPrint(
        '[DatabaseManager] Migration from Supabase complete: $results',
      );
      return results;
    } catch (e, stackTrace) {
      debugPrint('[DatabaseManager] Migration from Supabase error: $e');
      debugPrint('[DatabaseManager] Stack trace: $stackTrace');
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ── Health Check ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> healthCheck() async {
    return await repository.healthCheck();
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
