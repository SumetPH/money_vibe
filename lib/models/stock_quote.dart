class StockQuote {
  final double price;
  final double? changePercent;

  const StockQuote({required this.price, this.changePercent});

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
