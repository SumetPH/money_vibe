enum CostMethod { average, fifo, specific }

enum PnlSource { estimated, manual, broker }

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
  final double? grossProceedsUsd;
  final double? brokerFeeUsd;
  final double? exchangeFeeUsd;
  final double? taxFeeUsd;
  final CostMethod costMethod;
  final PnlSource pnlSource;
  final DateTime? settledAt;
  final String? brokerOrderRef;
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
    this.grossProceedsUsd,
    this.brokerFeeUsd,
    this.exchangeFeeUsd,
    this.taxFeeUsd,
    this.costMethod = CostMethod.average,
    this.pnlSource = PnlSource.estimated,
    this.settledAt,
    this.brokerOrderRef,
    DateTime? soldAt,
    DateTime? createdAt,
  }) : realizedPnlUsd =
           realizedPnlUsd ?? (cashReceivedUsd - (costBasisUsd * sharesSold)),
       soldAt = soldAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  double get proceedsUsd => sellPriceUsd * sharesSold;
  double get totalFeesUsd =>
      (brokerFeeUsd ?? 0) + (exchangeFeeUsd ?? 0) + (taxFeeUsd ?? 0);
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
    if (grossProceedsUsd != null) 'gross_proceeds_usd': grossProceedsUsd,
    if (brokerFeeUsd != null) 'broker_fee_usd': brokerFeeUsd,
    if (exchangeFeeUsd != null) 'exchange_fee_usd': exchangeFeeUsd,
    if (taxFeeUsd != null) 'tax_fee_usd': taxFeeUsd,
    'cost_method': costMethod.name,
    'pnl_source': pnlSource.name,
    if (settledAt != null) 'settled_at': settledAt!.toIso8601String(),
    if (brokerOrderRef != null) 'broker_order_ref': brokerOrderRef,
    'sold_at': soldAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  static StockTrade fromMap(Map<String, dynamic> m) {
    return StockTrade(
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
      grossProceedsUsd: (m['gross_proceeds_usd'] as num?)?.toDouble(),
      brokerFeeUsd: (m['broker_fee_usd'] as num?)?.toDouble(),
      exchangeFeeUsd: (m['exchange_fee_usd'] as num?)?.toDouble(),
      taxFeeUsd: (m['tax_fee_usd'] as num?)?.toDouble(),
      costMethod:
          CostMethod.values.asNameMap()[m['cost_method'] as String?] ??
          CostMethod.average,
      pnlSource:
          PnlSource.values.asNameMap()[m['pnl_source'] as String?] ??
          PnlSource.estimated,
      settledAt: m['settled_at'] != null
          ? DateTime.parse(m['settled_at'] as String)
          : null,
      brokerOrderRef: m['broker_order_ref'] as String?,
      soldAt: DateTime.parse(m['sold_at'] as String),
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

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
    double? grossProceedsUsd,
    double? brokerFeeUsd,
    double? exchangeFeeUsd,
    double? taxFeeUsd,
    CostMethod? costMethod,
    PnlSource? pnlSource,
    DateTime? settledAt,
    String? brokerOrderRef,
    DateTime? soldAt,
    DateTime? createdAt,
  }) {
    final nextSharesSold = sharesSold ?? this.sharesSold;
    final nextCostBasisUsd = costBasisUsd ?? this.costBasisUsd;
    final nextCashReceivedUsd = cashReceivedUsd ?? this.cashReceivedUsd;
    final nextPnlSource = pnlSource ?? this.pnlSource;
    final nextRealizedPnlUsd =
        realizedPnlUsd ??
        (nextPnlSource == PnlSource.estimated
            ? nextCashReceivedUsd - (nextCostBasisUsd * nextSharesSold)
            : this.realizedPnlUsd);

    return StockTrade(
      id: id,
      portfolioId: portfolioId ?? this.portfolioId,
      holdingId: holdingId ?? this.holdingId,
      ticker: ticker ?? this.ticker,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      sharesSold: nextSharesSold,
      sellPriceUsd: sellPriceUsd ?? this.sellPriceUsd,
      cashReceivedUsd: nextCashReceivedUsd,
      costBasisUsd: nextCostBasisUsd,
      realizedPnlUsd: nextRealizedPnlUsd,
      grossProceedsUsd: grossProceedsUsd ?? this.grossProceedsUsd,
      brokerFeeUsd: brokerFeeUsd ?? this.brokerFeeUsd,
      exchangeFeeUsd: exchangeFeeUsd ?? this.exchangeFeeUsd,
      taxFeeUsd: taxFeeUsd ?? this.taxFeeUsd,
      costMethod: costMethod ?? this.costMethod,
      pnlSource: nextPnlSource,
      settledAt: settledAt ?? this.settledAt,
      brokerOrderRef: brokerOrderRef ?? this.brokerOrderRef,
      soldAt: soldAt ?? this.soldAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
