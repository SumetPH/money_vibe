class StockHolding {
  final String id;
  final String portfolioId;
  String ticker;
  String name;
  double shares;
  double priceUsd;
  double costBasisUsd; // ราคาทุนต่อหุ้น
  String logoUrl;
  int sortOrder;
  bool sellPlanEnabled;
  double takeProfitPct;
  double trailingStopPct;
  double stopLossPct;
  double? peakProfitPct;
  String portfolioGroup;

  StockHolding({
    required this.id,
    required this.portfolioId,
    required this.ticker,
    this.name = '',
    this.shares = 0,
    this.priceUsd = 0,
    this.costBasisUsd = 0,
    this.logoUrl = '',
    this.sortOrder = 0,
    this.sellPlanEnabled = false,
    this.takeProfitPct = 0,
    this.trailingStopPct = 0,
    this.stopLossPct = 0,
    this.peakProfitPct,
    this.portfolioGroup = '',
  });

  double get valueUsd => shares * priceUsd;
  double get totalCostUsd => shares * costBasisUsd;
  double get unrealizedPnlUsd => costBasisUsd > 0 ? valueUsd - totalCostUsd : 0;
  double get unrealizedPnlPct =>
      totalCostUsd > 0 ? (unrealizedPnlUsd / totalCostUsd * 100) : 0;
  bool get canCalculateSellPlan => totalCostUsd > 0;

  bool hasInvestmentBasisChangedFrom(StockHolding previous) {
    return shares != previous.shares || costBasisUsd != previous.costBasisUsd;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'ticker': ticker,
    'name': name,
    'shares': shares,
    'price_usd': priceUsd,
    'cost_basis_usd': costBasisUsd,
    'logo_url': logoUrl,
    'sort_order': sortOrder,
    'sell_plan_enabled': sellPlanEnabled,
    'take_profit_pct': takeProfitPct,
    'trailing_stop_pct': trailingStopPct,
    'stop_loss_pct': stopLossPct,
    'peak_profit_pct': peakProfitPct,
    'portfolio_group': portfolioGroup,
  };

  static StockHolding fromMap(Map<String, dynamic> m) => StockHolding(
    id: m['id'] as String,
    portfolioId: m['portfolio_id'] as String,
    ticker: m['ticker'] as String,
    name: m['name'] as String? ?? '',
    shares: (m['shares'] as num).toDouble(),
    priceUsd: (m['price_usd'] as num).toDouble(),
    costBasisUsd: (m['cost_basis_usd'] as num? ?? 0).toDouble(),
    logoUrl: m['logo_url'] as String? ?? '',
    sortOrder: m['sort_order'] as int? ?? 0,
    sellPlanEnabled: m['sell_plan_enabled'] as bool? ?? false,
    takeProfitPct: (m['take_profit_pct'] as num? ?? 0).toDouble(),
    trailingStopPct: (m['trailing_stop_pct'] as num? ?? 0).toDouble(),
    stopLossPct: (m['stop_loss_pct'] as num? ?? 0).toDouble(),
    peakProfitPct: (m['peak_profit_pct'] as num?)?.toDouble(),
    portfolioGroup: m['portfolio_group'] as String? ?? '',
  );

  StockHolding copyWith({
    String? ticker,
    String? name,
    double? shares,
    double? priceUsd,
    double? costBasisUsd,
    String? logoUrl,
    int? sortOrder,
    bool? sellPlanEnabled,
    double? takeProfitPct,
    double? trailingStopPct,
    double? stopLossPct,
    Object? peakProfitPct = _noPeakProfitPct,
    String? portfolioGroup,
  }) => StockHolding(
    id: id,
    portfolioId: portfolioId,
    ticker: ticker ?? this.ticker,
    name: name ?? this.name,
    shares: shares ?? this.shares,
    priceUsd: priceUsd ?? this.priceUsd,
    costBasisUsd: costBasisUsd ?? this.costBasisUsd,
    logoUrl: logoUrl ?? this.logoUrl,
    sortOrder: sortOrder ?? this.sortOrder,
    sellPlanEnabled: sellPlanEnabled ?? this.sellPlanEnabled,
    takeProfitPct: takeProfitPct ?? this.takeProfitPct,
    trailingStopPct: trailingStopPct ?? this.trailingStopPct,
    stopLossPct: stopLossPct ?? this.stopLossPct,
    peakProfitPct: identical(peakProfitPct, _noPeakProfitPct)
        ? this.peakProfitPct
        : peakProfitPct as double?,
    portfolioGroup: portfolioGroup ?? this.portfolioGroup,
  );
}

const Object _noPeakProfitPct = Object();
