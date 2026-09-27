import '../models/account.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';

/// คำนวณยอดใช้จ่ายจริงของงบประมาณ ใช้ร่วมกันระหว่างหน้างบประมาณและ Cash-flow forecast
class BudgetSpendingService {
  /// ยอดรายจ่ายจริงแยกตาม category ในช่วง [start, end] (inclusive)
  static Map<String, double> spentByCategoryId({
    required List<AppTransaction> transactions,
    required DateTime start,
    required DateTime end,
    required List<Account> accounts,
  }) {
    final spentByCategoryId = <String, double>{};

    for (final tx in transactions) {
      if (tx.dateTime.isBefore(start) || tx.dateTime.isAfter(end)) continue;
      if (!TransactionProvider.isActualExpense(tx, accounts)) continue;

      final categoryId = tx.categoryId;
      if (categoryId == null) continue;

      spentByCategoryId[categoryId] =
          (spentByCategoryId[categoryId] ?? 0.0) + tx.amount;
    }

    return spentByCategoryId;
  }

  /// ยอดใช้จ่ายรวมของทุก category ใน [budget]
  static double spentFor(Budget budget, Map<String, double> spentByCategoryId) {
    var spent = 0.0;
    for (final categoryId in budget.categoryIds) {
      spent += spentByCategoryId[categoryId] ?? 0.0;
    }
    return spent;
  }
}
