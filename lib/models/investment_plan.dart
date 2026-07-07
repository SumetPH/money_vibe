import 'stock_holding.dart';

const double allocationTargetTolerancePct = 0.01;

String currentInvestmentMonthKey([DateTime? now]) {
  final localNow = now ?? DateTime.now();
  final month = localNow.month.toString().padLeft(2, '0');
  return '${localNow.year}-$month';
}

class InvestmentPlanMonthStatus {
  final String id;
  final String portfolioId;
  final String dcaMonth;
  final bool dcaCompleted;

  const InvestmentPlanMonthStatus({
    required this.id,
    required this.portfolioId,
    required this.dcaMonth,
    required this.dcaCompleted,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'dca_month': dcaMonth,
    'dca_completed': dcaCompleted,
  };

  static InvestmentPlanMonthStatus fromMap(Map<String, dynamic> m) =>
      InvestmentPlanMonthStatus(
        id: m['id'] as String,
        portfolioId: m['portfolio_id'] as String,
        dcaMonth: m['dca_month'] as String,
        dcaCompleted: m['dca_completed'] as bool? ?? false,
      );

  InvestmentPlanMonthStatus copyWith({
    String? id,
    String? portfolioId,
    String? dcaMonth,
    bool? dcaCompleted,
  }) => InvestmentPlanMonthStatus(
    id: id ?? this.id,
    portfolioId: portfolioId ?? this.portfolioId,
    dcaMonth: dcaMonth ?? this.dcaMonth,
    dcaCompleted: dcaCompleted ?? this.dcaCompleted,
  );
}

class PortfolioAllocationTarget {
  final String id;
  final String portfolioId;
  final String? holdingId;
  final String ticker;
  final double targetPercent;
  final bool isEnabled;
  final int sortOrder;

  const PortfolioAllocationTarget({
    required this.id,
    required this.portfolioId,
    required this.ticker,
    this.holdingId,
    this.targetPercent = 0,
    this.isEnabled = true,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'holding_id': holdingId,
    'ticker': ticker,
    'target_percent': targetPercent,
    'is_enabled': isEnabled,
    'sort_order': sortOrder,
  };

  static PortfolioAllocationTarget fromMap(Map<String, dynamic> m) =>
      PortfolioAllocationTarget(
        id: m['id'] as String,
        portfolioId: m['portfolio_id'] as String,
        holdingId: m['holding_id'] as String?,
        ticker: m['ticker'] as String,
        targetPercent: (m['target_percent'] as num? ?? 0).toDouble(),
        isEnabled: m['is_enabled'] as bool? ?? true,
        sortOrder: m['sort_order'] as int? ?? 0,
      );

  PortfolioAllocationTarget copyWith({
    String? id,
    String? portfolioId,
    Object? holdingId = _noHoldingId,
    String? ticker,
    double? targetPercent,
    bool? isEnabled,
    int? sortOrder,
  }) => PortfolioAllocationTarget(
    id: id ?? this.id,
    portfolioId: portfolioId ?? this.portfolioId,
    holdingId: identical(holdingId, _noHoldingId)
        ? this.holdingId
        : holdingId as String?,
    ticker: ticker ?? this.ticker,
    targetPercent: targetPercent ?? this.targetPercent,
    isEnabled: isEnabled ?? this.isEnabled,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

const Object _noHoldingId = Object();

class AllocationAnalysisRow {
  final String holdingId;
  final String ticker;
  final String name;
  final String logoUrl;
  final bool isEnabled;
  final double targetPercent;
  final double currentPercent;
  final double targetValue;
  final double currentValue;
  final double diffPercent;
  final double diffAmount;
  final double buyAmount;
  final double projectedPercent;

  const AllocationAnalysisRow({
    required this.holdingId,
    required this.ticker,
    required this.name,
    required this.logoUrl,
    required this.isEnabled,
    required this.targetPercent,
    required this.currentPercent,
    required this.targetValue,
    required this.currentValue,
    required this.diffPercent,
    required this.diffAmount,
    required this.buyAmount,
    required this.projectedPercent,
  });

  bool get isUnderweight => isEnabled && diffAmount < -0.005;
  bool get isOverweight => isEnabled && diffAmount > 0.005;

  String get statusLabel {
    if (!isEnabled) return 'นอกแผน';
    if (isUnderweight) return 'ขาด';
    if (isOverweight) return 'เกิน';
    return 'พอดี';
  }
}

class AllocationAnalysis {
  final double totalCurrentValue;
  final double targetPercentTotal;
  final double buyAmount;
  final List<AllocationAnalysisRow> rows;

  const AllocationAnalysis({
    required this.totalCurrentValue,
    required this.targetPercentTotal,
    required this.buyAmount,
    required this.rows,
  });

  bool get isTargetBalanced =>
      (targetPercentTotal - 100).abs() <= allocationTargetTolerancePct;

  double get recommendedBuyTotal =>
      rows.fold(0, (sum, row) => sum + row.buyAmount);
}

AllocationAnalysis buildAllocationAnalysis({
  required List<StockHolding> holdings,
  required List<PortfolioAllocationTarget> targets,
  double buyAmount = 0,
}) {
  final targetsByTicker = {
    for (final target in targets) _normalizeTicker(target.ticker): target,
  };
  final plannedHoldings = holdings.where((holding) {
    final target = targetsByTicker[_normalizeTicker(holding.ticker)];
    return target != null && target.isEnabled;
  }).toList();
  final totalCurrentValue = plannedHoldings.fold<double>(
    0,
    (sum, holding) => sum + holding.valueUsd,
  );
  final buyAmountByTicker = _buildBuyAmounts(
    plannedHoldings: plannedHoldings,
    targetsByTicker: targetsByTicker,
    totalCurrentValue: totalCurrentValue,
    buyAmount: buyAmount,
  );
  final targetPercentTotal = targetsByTicker.values
      .where((target) => target.isEnabled)
      .fold<double>(0, (sum, target) => sum + target.targetPercent);
  final projectedTotal = totalCurrentValue + buyAmount;

  final rows = holdings.map((holding) {
    final target = targetsByTicker[_normalizeTicker(holding.ticker)];
    final isEnabled = target?.isEnabled ?? false;
    final targetPercent = isEnabled ? (target?.targetPercent ?? 0.0) : 0.0;
    final currentValue = holding.valueUsd;
    final currentPercent = totalCurrentValue > 0
        ? (currentValue / totalCurrentValue) * 100
        : 0.0;
    final targetValue = totalCurrentValue * targetPercent / 100;
    final diffAmount = currentValue - targetValue;
    final buyForHolding =
        buyAmountByTicker[_normalizeTicker(holding.ticker)] ?? 0.0;
    final projectedPercent = projectedTotal > 0
        ? ((currentValue + buyForHolding) / projectedTotal) * 100
        : 0.0;

    return AllocationAnalysisRow(
      holdingId: holding.id,
      ticker: holding.ticker,
      name: holding.name,
      logoUrl: holding.logoUrl,
      isEnabled: isEnabled,
      targetPercent: targetPercent,
      currentPercent: currentPercent,
      targetValue: targetValue,
      currentValue: currentValue,
      diffPercent: currentPercent - targetPercent,
      diffAmount: diffAmount,
      buyAmount: buyForHolding,
      projectedPercent: projectedPercent,
    );
  }).toList();

  return AllocationAnalysis(
    totalCurrentValue: totalCurrentValue,
    targetPercentTotal: targetPercentTotal,
    buyAmount: buyAmount,
    rows: rows,
  );
}

Map<String, double> _buildBuyAmounts({
  required List<StockHolding> plannedHoldings,
  required Map<String, PortfolioAllocationTarget> targetsByTicker,
  required double totalCurrentValue,
  required double buyAmount,
}) {
  if (buyAmount <= 0 || plannedHoldings.isEmpty) return const {};

  final newTotal = totalCurrentValue + buyAmount;
  final gaps = <String, double>{};
  for (final holding in plannedHoldings) {
    final tickerKey = _normalizeTicker(holding.ticker);
    final target = targetsByTicker[tickerKey];
    if (target == null || !target.isEnabled || target.targetPercent <= 0) {
      continue;
    }
    final targetValueAfterBuy = newTotal * target.targetPercent / 100;
    final gap = targetValueAfterBuy - holding.valueUsd;
    if (gap > 0.005) {
      gaps[tickerKey] = gap;
    }
  }

  final sortedGaps = gaps.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (sortedGaps.isEmpty) return const {};

  final buyAmounts = <String, double>{};
  var remaining = buyAmount;
  for (final gap in sortedGaps) {
    if (remaining <= 0.005) break;
    final amount = remaining >= gap.value ? gap.value : remaining;
    buyAmounts[gap.key] = amount;
    remaining -= amount;
  }

  final enabledTargets = targetsByTicker.values
      .where((target) => target.isEnabled && target.targetPercent > 0)
      .toList();
  final targetTotal = enabledTargets.fold<double>(
    0,
    (sum, target) => sum + target.targetPercent,
  );
  if (remaining <= 0 || targetTotal <= 0) return buyAmounts;

  for (final target in enabledTargets) {
    final tickerKey = _normalizeTicker(target.ticker);
    buyAmounts[tickerKey] =
        (buyAmounts[tickerKey] ?? 0) +
        remaining * (target.targetPercent / targetTotal);
  }
  return buyAmounts;
}

String _normalizeTicker(String ticker) => ticker.trim().toUpperCase();
