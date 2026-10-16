class StockQuote {
  final double price;
  final double? changePercent;

  const StockQuote({required this.price, this.changePercent});

  static StockQuote? fromYahooMeta(Map<String, dynamic> meta) {
    final price = meta['regularMarketPrice'];
    if (price is! num || !price.isFinite || price <= 0) return null;
    final previousClose = meta['chartPreviousClose'] ?? meta['previousClose'];
    final changePercent =
        previousClose is num && previousClose.isFinite && previousClose > 0
        ? (price - previousClose) / previousClose * 100
        : null;
    return StockQuote(
      price: price.toDouble(),
      changePercent: changePercent != null && changePercent.isFinite
          ? changePercent
          : null,
    );
  }

  static StockQuote? fromJson(Map<String, dynamic> data) {
    final rawPrice = data['c'];
    if (rawPrice is! num || !rawPrice.isFinite || rawPrice <= 0) return null;
    final rawChangePercent = data['dp'];
    return StockQuote(
      price: rawPrice.toDouble(),
      changePercent: rawChangePercent is num && rawChangePercent.isFinite
          ? rawChangePercent.toDouble()
          : null,
    );
  }
}
