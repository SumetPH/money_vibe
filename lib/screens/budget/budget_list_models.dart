import '../../models/budget.dart';
import '../../services/budget_spending_service.dart';

class BudgetGroupSummary {
  final String name;
  final double percentage;
  final double total;
  final double spent;
  final double available;
  final double overspent;

  const BudgetGroupSummary({
    required this.name,
    required this.percentage,
    required this.total,
    required this.spent,
    required this.available,
    required this.overspent,
  });
}

List<BudgetGroupSummary> buildBudgetGroupSummaries({
  required List<Budget> budgets,
  required Map<String, double> spentByCategoryId,
  required double totalBudget,
}) {
  final Map<String, List<Budget>> groupedBudgets = {};

  for (final budget in budgets) {
    final rawGroupName = budget.groupName?.trim();
    final groupName = (rawGroupName == null || rawGroupName.isEmpty)
        ? 'ไม่มีกลุ่ม'
        : rawGroupName;
    (groupedBudgets[groupName] ??= []).add(budget);
  }

  final sortedGroups = groupedBudgets.entries.toList()
    ..sort(
      (a, b) => a.value
          .map((budget) => budget.sortOrder)
          .reduce((min, value) => min < value ? min : value)
          .compareTo(
            b.value
                .map((budget) => budget.sortOrder)
                .reduce((min, value) => min < value ? min : value),
          ),
    );

  return sortedGroups.map((entry) {
    var total = 0.0;
    var spent = 0.0;
    var available = 0.0;
    var overspent = 0.0;

    for (final budget in entry.value) {
      final budgetSpent = BudgetSpendingService.spentFor(
        budget,
        spentByCategoryId,
      );
      final remaining = budget.amount - budgetSpent;
      total += budget.amount;
      spent += budgetSpent;
      if (remaining >= 0) {
        available += remaining;
      } else {
        overspent += remaining.abs();
      }
    }

    return BudgetGroupSummary(
      name: entry.key,
      percentage: totalBudget > 0 ? (total / totalBudget) * 100 : 0.0,
      total: total,
      spent: spent,
      available: available,
      overspent: overspent,
    );
  }).toList();
}
