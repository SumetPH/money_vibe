import 'package:flutter/foundation.dart' hide Category;
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../models/stock_holding.dart';

// ── Sub-Interfaces (Feature-Specific Adapters) ──────────────────────────────

/// Interface สำหรับจัดการข้อมูลบัญชี (Account)
abstract class AccountRepositoryInterface {
  Future<List<Account>> getAccounts();
  Future<void> insertAccount(Account account);
  Future<void> updateAccount(Account account);
  Future<void> updateAccountSortOrder(String id, int sortOrder);
  Future<void> deleteAccount(String id);
  Future<Set<String>> getExistingAccountIds();
  Future<void> bulkInsertAccounts(List<Account> accounts);
}

/// Interface สำหรับจัดการข้อมูลหมวดหมู่ (Category)
abstract class CategoryRepositoryInterface {
  Future<List<Category>> getCategories();
  Future<void> insertCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> updateCategorySortOrder(String id, int sortOrder);
  Future<void> deleteCategory(String id);
  Future<Set<String>> getExistingCategoryIds();
  Future<void> bulkInsertCategories(List<Category> categories);
}

/// Interface สำหรับจัดการข้อมูลธุรกรรม (Transaction)
abstract class TransactionRepositoryInterface {
  Future<List<AppTransaction>> getTransactions();
  Future<void> insertTransaction(AppTransaction transaction);
  Future<void> updateTransaction(AppTransaction transaction);
  Future<void> deleteTransaction(String id);
  Future<Set<String>> getExistingTransactionIds();
  Future<void> bulkInsertTransactions(List<AppTransaction> transactions);
}

/// Interface สำหรับจัดการข้อมูลพอร์ตโฟลิโอและหุ้น (Stock Holding)
abstract class PortfolioRepositoryInterface {
  Future<List<StockHolding>> getPortfolioHoldings();
  Future<void> insertHolding(StockHolding holding);
  Future<void> updateHolding(StockHolding holding);
  Future<void> updateHoldingSortOrder(String id, int sortOrder);
  Future<void> deleteHolding(String id);
  Future<void> deleteHoldingsByPortfolio(String portfolioId);
  Future<Set<String>> getExistingHoldingIds();
  Future<void> bulkInsertHoldings(List<StockHolding> holdings);
}

/// Interface สำหรับจัดการข้อมูลงบประมาณ (Budget)
abstract class BudgetRepositoryInterface {
  Future<List<Budget>> getBudgets();
  Future<void> insertBudget(Budget budget);
  Future<void> updateBudget(Budget budget);
  Future<void> updateBudgetSortOrder(String id, int sortOrder);
  Future<void> deleteBudget(String id);
  Future<Set<String>> getExistingBudgetIds();
  Future<void> bulkInsertBudgets(List<Budget> budgets);
}

/// Interface สำหรับจัดการข้อมูลรายการเกิดซ้ำ (Recurring & Occurrence)
abstract class RecurringRepositoryInterface {
  // Recurring Transactions
  Future<List<RecurringTransaction>> getRecurringTransactions();
  Future<void> insertRecurringTransaction(RecurringTransaction recurring);
  Future<void> updateRecurringTransaction(RecurringTransaction recurring);
  Future<void> deleteRecurringTransaction(String id);
  Future<void> updateRecurringSortOrder(String id, int sortOrder);
  Future<Set<String>> getExistingRecurringIds();
  Future<void> bulkInsertRecurring(List<RecurringTransaction> recurring);

  // Occurrences
  Future<List<RecurringOccurrence>> getRecurringOccurrences();
  Future<List<RecurringOccurrence>> getOccurrencesFor(String recurringId);
  Future<void> insertRecurringOccurrence(RecurringOccurrence occurrence);
  Future<void> deleteOccurrence(String id);
  Future<void> deleteOccurrencesByRecurring(String recurringId);
  Future<Set<String>> getExistingOccurrenceIds();
  Future<void> bulkInsertOccurrences(List<RecurringOccurrence> occurrences);
}

/// Interface สำหรับจัดการข้อมูล Sync Log
abstract class SyncRepositoryInterface {
  /// อัปเดตเวลาล่าสุดของโมดูล
  Future<void> updateSyncLog(String moduleName);

  /// ดึงข้อมูล Sync Log ทั้งหมดของผู้ใช้ปัจจุบัน
  Future<Map<String, DateTime>> getSyncLogs();
}

// ── Composite Repository Interface ──────────────────────────────────────────

/// Abstract Repository Interface หลักของแอปพลิเคชัน
/// ประกอบขึ้นจาก Sub-interfaces ของแต่ละฟีเจอร์ (Composite Interface)
abstract class DatabaseRepository
    implements
        AccountRepositoryInterface,
        CategoryRepositoryInterface,
        TransactionRepositoryInterface,
        PortfolioRepositoryInterface,
        BudgetRepositoryInterface,
        RecurringRepositoryInterface,
        SyncRepositoryInterface {
  /// ชื่อของ repository (สำหรับ debug)
  String get name;

  /// ตรวจสอบว่าผู้ใช้ Login หรือยัง
  bool get isAuthenticated;

  /// ID ของผู้ใช้ปัจจุบัน
  String? get currentUserId;

  /// เริ่มต้นการเชื่อมต่อ/initialize
  Future<void> init();

  /// ปิดการเชื่อมต่อ (optional)
  Future<void> close();

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
