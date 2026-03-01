class StockHolding {
  final String id;
  final String portfolioId;
  String ticker;
  String name;
  double shares;
  double priceUsd;
  double costBasisUsd; // ราคาทุนต่อหุ้น
  int sortOrder;

  StockHolding({
    required this.id,
    required this.portfolioId,
    required this.ticker,
    this.name = '',
    this.shares = 0,
    this.priceUsd = 0,
    this.costBasisUsd = 0,
    this.sortOrder = 0,
  });

  double get valueUsd => shares * priceUsd;
  double get totalCostUsd => shares * costBasisUsd;
  double get unrealizedPnlUsd => costBasisUsd > 0 ? valueUsd - totalCostUsd : 0;
  double get unrealizedPnlPct =>
      totalCostUsd > 0 ? (unrealizedPnlUsd / totalCostUsd * 100) : 0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'ticker': ticker,
    'name': name,
    'shares': shares,
    'price_usd': priceUsd,
    'cost_basis_usd': costBasisUsd,
    'sort_order': sortOrder,
  };

  static StockHolding fromMap(Map<String, dynamic> m) => StockHolding(
    id: m['id'] as String,
    portfolioId: m['portfolio_id'] as String,
    ticker: m['ticker'] as String,
    name: m['name'] as String? ?? '',
    shares: (m['shares'] as num).toDouble(),
    priceUsd: (m['price_usd'] as num).toDouble(),
    costBasisUsd: (m['cost_basis_usd'] as num? ?? 0).toDouble(),
    sortOrder: m['sort_order'] as int? ?? 0,
  );

  StockHolding copyWith({
    String? ticker,
    String? name,
    double? shares,
    double? priceUsd,
    double? costBasisUsd,
    int? sortOrder,
  }) => StockHolding(
    id: id,
    portfolioId: portfolioId,
    ticker: ticker ?? this.ticker,
    name: name ?? this.name,
    shares: shares ?? this.shares,
    priceUsd: priceUsd ?? this.priceUsd,
    costBasisUsd: costBasisUsd ?? this.costBasisUsd,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}
