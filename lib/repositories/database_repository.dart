import 'package:flutter/foundation.dart' hide Category;
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../models/stock_holding.dart';

/// Enum สำหรับเลือกประเภท Database
enum DatabaseMode {
  sqlite,
  supabase,
}

/// Extension สำหรับ convert DateTime ระหว่าง SQLite และ Supabase
/// 
/// SQLite: เก็บเป็น ISO8601 String
/// Supabase (Postgres): เก็บเป็น timestamp without time zone (เวลา local)
extension DateTimeConverter on DateTime {
  /// Convert เป็นรูปแบบที่เก็บใน SQLite (ISO8601 String)
  String toSqlite() => toIso8601String();

  /// Convert จากรูปแบบ SQLite (ISO8601 String)
  static DateTime fromSqlite(String value) => DateTime.parse(value);

  /// Convert เป็นรูปแบบที่เก็บใน Supabase (DateTime โดยตรง)
  DateTime toSupabase() => this;

  /// Convert จากรูปแบบ Supabase (อาจเป็น String หรือ DateTime)
  static DateTime fromSupabase(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}

/// Abstract Repository Interface
/// กำหนด contract สำหรับทุก database operations
/// ทั้ง SQLite และ Supabase ต้อง implement ตามนี้
abstract class DatabaseRepository {
  /// ชื่อของ repository (สำหรับ debug)
  String get name;

  /// เริ่มต้นการเชื่อมต่อ/initialize
  Future<void> init();

  /// ปิดการเชื่อมต่อ (optional)
  Future<void> close();

  // ── Accounts ──────────────────────────────────────────────────────────────

  Future<List<Account>> getAccounts();
  Future<void> insertAccount(Account account);
  Future<void> updateAccount(Account account);
  Future<void> updateAccountSortOrder(String id, int sortOrder);
  Future<void> deleteAccount(String id);

  // ── Categories ────────────────────────────────────────────────────────────

  Future<List<Category>> getCategories();
  Future<void> insertCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> updateCategorySortOrder(String id, int sortOrder);
  Future<void> deleteCategory(String id);

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<List<AppTransaction>> getTransactions();
  Future<void> insertTransaction(AppTransaction transaction);
  Future<void> updateTransaction(AppTransaction transaction);
  Future<void> deleteTransaction(String id);

  // ── Portfolio Holdings ─────────────────────────────────────────────────────

  Future<List<StockHolding>> getPortfolioHoldings();
  Future<void> insertHolding(StockHolding holding);
  Future<void> updateHolding(StockHolding holding);
  Future<void> updateHoldingSortOrder(String id, int sortOrder);
  Future<void> deleteHolding(String id);
  Future<void> deleteHoldingsByPortfolio(String portfolioId);

  // ── Budgets ────────────────────────────────────────────────────────────────

  Future<List<Budget>> getBudgets();
  Future<void> insertBudget(Budget budget);
  Future<void> updateBudget(Budget budget);
  Future<void> updateBudgetSortOrder(String id, int sortOrder);
  Future<void> deleteBudget(String id);

  // ── Recurring Transactions ─────────────────────────────────────────────────

  Future<List<RecurringTransaction>> getRecurringTransactions();
  Future<void> insertRecurringTransaction(RecurringTransaction recurring);
  Future<void> updateRecurringTransaction(RecurringTransaction recurring);
  Future<void> deleteRecurringTransaction(String id);
  Future<void> updateRecurringSortOrder(String id, int sortOrder);

  // ── Recurring Occurrences ──────────────────────────────────────────────────

  Future<List<RecurringOccurrence>> getRecurringOccurrences();
  Future<List<RecurringOccurrence>> getOccurrencesFor(String recurringId);
  Future<void> insertRecurringOccurrence(RecurringOccurrence occurrence);
  Future<void> deleteOccurrence(String id);
  Future<void> deleteOccurrencesByRecurring(String recurringId);

  // ── Migration Helpers ──────────────────────────────────────────────────────

  /// ล้างข้อมูลทั้งหมด (สำหรับ migration)
  Future<void> clearAllData();

  /// ตรวจสอบสถานะการเชื่อมต่อ
  Future<bool> isConnected();

  /// Health check
  Future<Map<String, dynamic>> healthCheck();
}

/// Mixin สำหรับ debug logging
mixin RepositoryLogger implements DatabaseRepository {
  void log(String message) {
    debugPrint('[$name] $message');
  }

  void logError(String message, dynamic error) {
    debugPrint('[$name] ERROR: $message - $error');
  }
}
