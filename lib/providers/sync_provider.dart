import 'package:flutter/material.dart';
import '../repositories/database_repository.dart';
import 'account_provider.dart';
import 'category_provider.dart';
import 'transaction_provider.dart';
import 'budget_provider.dart';
import 'recurring_transaction_provider.dart';

class SyncProvider extends ChangeNotifier {
  final DatabaseRepository repository;
  final AccountProvider accountProvider;
  final CategoryProvider categoryProvider;
  final TransactionProvider transactionProvider;
  final BudgetProvider budgetProvider;
  final RecurringTransactionProvider recurringProvider;

  final Map<String, DateTime> _localTimestamps = {};
  bool _isChecking = false;
  DateTime? _lastCheckTime;

  SyncProvider({
    required this.repository,
    required this.accountProvider,
    required this.categoryProvider,
    required this.transactionProvider,
    required this.budgetProvider,
    required this.recurringProvider,
  });

  /// เช็คและอัปเดตข้อมูลจาก Server
  Future<void> checkAndSync() async {
    // 1. ตรวจสอบ Auth (ป้องกัน Error ตอนยังไม่ Login)
    if (!repository.isAuthenticated) return;

    // 2. ป้องกันการเรียกซ้อนกัน
    if (_isChecking) return;

    // 3. Debouncing (ไม่เช็คซ้ำภายใน 2 วินาที)
    final now = DateTime.now();
    if (_lastCheckTime != null &&
        now.difference(_lastCheckTime!) < const Duration(seconds: 2)) {
      return;
    }

    _isChecking = true;
    _lastCheckTime = now;

    try {
      debugPrint('[SyncProvider] Checking for remote updates...');
      final remoteLogs = await repository.getSyncLogs();

      if (remoteLogs.isEmpty) {
        debugPrint('[SyncProvider] No remote logs found.');
        return;
      }

      for (final entry in remoteLogs.entries) {
        final module = entry.key;
        final remoteTime = entry.value;
        final localTime = _localTimestamps[module];

        // ถ้ายังไม่มีเวลาในเครื่อง หรือเวลาใน Server ใหม่กว่า
        if (localTime == null || remoteTime.isAfter(localTime)) {
          debugPrint(
            '[SyncProvider] Module "$module" needs refresh. Remote: $remoteTime, Local: $localTime',
          );

          _refreshModule(module);
          _localTimestamps[module] = remoteTime;
        }
      }
    } catch (e) {
      debugPrint('[SyncProvider] Sync Error: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// สั่งให้ Provider ที่เกี่ยวข้องโหลดข้อมูลใหม่
  void _refreshModule(String module) {
    try {
      switch (module) {
        case 'accounts':
        case 'portfolio':
          accountProvider.reload();
          break;
        case 'categories':
          categoryProvider.reload();
          break;
        case 'transactions':
          transactionProvider.reload();
          break;
        case 'budgets':
          budgetProvider.reload();
          break;
        case 'recurring':
          recurringProvider.reload();
          break;
        default:
          debugPrint('[SyncProvider] Unknown module: $module');
      }
    } catch (e) {
      debugPrint('[SyncProvider] Failed to refresh module $module: $e');
    }
  }

  /// รีเซ็ตเวลาในเครื่อง (ใช้ตอนเปลี่ยน user หรือ logout)
  void reset() {
    _localTimestamps.clear();
    notifyListeners();
  }
}
