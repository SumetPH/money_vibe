class StockPurchase {
  final String id;
  final String portfolioId;
  final String holdingId;
  final String ticker;
  final String name;
  final String logoUrl;
  final double sharesBought;
  final double buyPriceUsd;
  final double cashPaidUsd;
  final double? grossCostUsd;
  final double? brokerFeeUsd;
  final double? exchangeFeeUsd;
  final double? taxFeeUsd;
  final DateTime boughtAt;
  final DateTime createdAt;

  const StockPurchase({
    required this.id,
    required this.portfolioId,
    required this.holdingId,
    required this.ticker,
    this.name = '',
    this.logoUrl = '',
    required this.sharesBought,
    required this.buyPriceUsd,
    required this.cashPaidUsd,
    this.grossCostUsd,
    this.brokerFeeUsd,
    this.exchangeFeeUsd,
    this.taxFeeUsd,
    required this.boughtAt,
    required this.createdAt,
  });

  double get costUsd => grossCostUsd ?? (sharesBought * buyPriceUsd);

  Map<String, dynamic> toMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'holding_id': holdingId,
    'ticker': ticker,
    'name': name,
    'logo_url': logoUrl,
    'shares_bought': sharesBought,
    'buy_price_usd': buyPriceUsd,
    'cash_paid_usd': cashPaidUsd,
    'gross_cost_usd': grossCostUsd,
    'broker_fee_usd': brokerFeeUsd,
    'exchange_fee_usd': exchangeFeeUsd,
    'tax_fee_usd': taxFeeUsd,
    'bought_at': boughtAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  factory StockPurchase.fromMap(Map<String, dynamic> map) => StockPurchase(
    id: map['id'] as String,
    portfolioId: map['portfolio_id'] as String,
    holdingId: map['holding_id'] as String? ?? '',
    ticker: map['ticker'] as String,
    name: map['name'] as String? ?? '',
    logoUrl: map['logo_url'] as String? ?? '',
    sharesBought: (map['shares_bought'] as num).toDouble(),
    buyPriceUsd: (map['buy_price_usd'] as num).toDouble(),
    cashPaidUsd: (map['cash_paid_usd'] as num).toDouble(),
    grossCostUsd: (map['gross_cost_usd'] as num?)?.toDouble(),
    brokerFeeUsd: (map['broker_fee_usd'] as num?)?.toDouble(),
    exchangeFeeUsd: (map['exchange_fee_usd'] as num?)?.toDouble(),
    taxFeeUsd: (map['tax_fee_usd'] as num?)?.toDouble(),
    boughtAt: DateTime.parse(map['bought_at'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  StockPurchase copyWith({
    String? portfolioId,
    String? ticker,
    double? sharesBought,
    double? buyPriceUsd,
    double? cashPaidUsd,
    double? grossCostUsd,
    double? brokerFeeUsd,
    double? exchangeFeeUsd,
    double? taxFeeUsd,
  }) => StockPurchase(
    id: id,
    portfolioId: portfolioId ?? this.portfolioId,
    holdingId: holdingId,
    ticker: ticker ?? this.ticker,
    name: name,
    logoUrl: logoUrl,
    sharesBought: sharesBought ?? this.sharesBought,
    buyPriceUsd: buyPriceUsd ?? this.buyPriceUsd,
    cashPaidUsd: cashPaidUsd ?? this.cashPaidUsd,
    grossCostUsd: grossCostUsd ?? this.grossCostUsd,
    brokerFeeUsd: brokerFeeUsd ?? this.brokerFeeUsd,
    exchangeFeeUsd: exchangeFeeUsd ?? this.exchangeFeeUsd,
    taxFeeUsd: taxFeeUsd ?? this.taxFeeUsd,
    boughtAt: boughtAt,
    createdAt: createdAt,
  );
}
