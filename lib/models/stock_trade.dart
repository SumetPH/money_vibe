class StockTrade {
  final String id;
  final String portfolioId;
  final String holdingId;
  final String ticker;
  final String name;
  final String logoUrl;
  final double sharesSold;
  final double sellPriceUsd;
  final double cashReceivedUsd;
  final double costBasisUsd;
  final double realizedPnlUsd;
  final DateTime soldAt;
  final DateTime createdAt;

  StockTrade({
    required this.id,
    required this.portfolioId,
    required this.holdingId,
    required this.ticker,
    this.name = '',
    this.logoUrl = '',
    required this.sharesSold,
    required this.sellPriceUsd,
    required this.cashReceivedUsd,
    required this.costBasisUsd,
    double? realizedPnlUsd,
    DateTime? soldAt,
    DateTime? createdAt,
  }) : realizedPnlUsd =
           realizedPnlUsd ?? ((sellPriceUsd - costBasisUsd) * sharesSold),
       soldAt = soldAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  double get proceedsUsd => sellPriceUsd * sharesSold;
  bool get isProfit => realizedPnlUsd > 0;
  bool get isLoss => realizedPnlUsd < 0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'holding_id': holdingId,
    'ticker': ticker,
    'name': name,
    'logo_url': logoUrl,
    'shares_sold': sharesSold,
    'sell_price_usd': sellPriceUsd,
    'cash_received_usd': cashReceivedUsd,
    'cost_basis_usd': costBasisUsd,
    'realized_pnl_usd': realizedPnlUsd,
    'sold_at': soldAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  static StockTrade fromMap(Map<String, dynamic> m) => StockTrade(
    id: m['id'] as String,
    portfolioId: m['portfolio_id'] as String,
    holdingId: m['holding_id'] as String? ?? '',
    ticker: m['ticker'] as String,
    name: m['name'] as String? ?? '',
    logoUrl: m['logo_url'] as String? ?? '',
    sharesSold: (m['shares_sold'] as num).toDouble(),
    sellPriceUsd: (m['sell_price_usd'] as num).toDouble(),
    cashReceivedUsd: (m['cash_received_usd'] as num).toDouble(),
    costBasisUsd: (m['cost_basis_usd'] as num).toDouble(),
    realizedPnlUsd: (m['realized_pnl_usd'] as num).toDouble(),
    soldAt: DateTime.parse(m['sold_at'] as String),
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  StockTrade copyWith({
    String? portfolioId,
    String? holdingId,
    String? ticker,
    String? name,
    String? logoUrl,
    double? sharesSold,
    double? sellPriceUsd,
    double? cashReceivedUsd,
    double? costBasisUsd,
    double? realizedPnlUsd,
    DateTime? soldAt,
    DateTime? createdAt,
  }) {
    final nextSharesSold = sharesSold ?? this.sharesSold;
    final nextSellPriceUsd = sellPriceUsd ?? this.sellPriceUsd;
    final nextCostBasisUsd = costBasisUsd ?? this.costBasisUsd;

    return StockTrade(
      id: id,
      portfolioId: portfolioId ?? this.portfolioId,
      holdingId: holdingId ?? this.holdingId,
      ticker: ticker ?? this.ticker,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      sharesSold: nextSharesSold,
      sellPriceUsd: nextSellPriceUsd,
      cashReceivedUsd: cashReceivedUsd ?? this.cashReceivedUsd,
      costBasisUsd: nextCostBasisUsd,
      realizedPnlUsd:
          realizedPnlUsd ??
          ((nextSellPriceUsd - nextCostBasisUsd) * nextSharesSold),
      soldAt: soldAt ?? this.soldAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
