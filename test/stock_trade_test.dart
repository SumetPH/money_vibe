import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/models/stock_trade.dart';

void main() {
  group('StockTrade', () {
    test('calculates realized P/L from sell price, cost basis, and shares', () {
      final trade = StockTrade(
        id: 'trade-1',
        portfolioId: 'portfolio-1',
        holdingId: 'holding-1',
        ticker: 'AAPL',
        sharesSold: 2.5,
        sellPriceUsd: 120,
        cashReceivedUsd: 299,
        costBasisUsd: 100,
        soldAt: DateTime(2026, 6, 17, 10),
        createdAt: DateTime(2026, 6, 17, 10),
      );

      expect(trade.realizedPnlUsd, 50);
      expect(trade.proceedsUsd, 300);
      expect(trade.cashReceivedUsd, 299);
    });

    test('serializes and deserializes trade values', () {
      final trade = StockTrade(
        id: 'trade-1',
        portfolioId: 'portfolio-1',
        holdingId: 'holding-1',
        ticker: 'AAPL',
        name: 'Apple',
        logoUrl: 'https://example.com/aapl.png',
        sharesSold: 1.25,
        sellPriceUsd: 150.1234,
        cashReceivedUsd: 187.5,
        costBasisUsd: 100.1111,
        soldAt: DateTime(2026, 6, 17, 10),
        createdAt: DateTime(2026, 6, 17, 11),
      );

      final fromMap = StockTrade.fromMap(trade.toMap());

      expect(fromMap.id, 'trade-1');
      expect(fromMap.ticker, 'AAPL');
      expect(fromMap.logoUrl, 'https://example.com/aapl.png');
      expect(fromMap.sharesSold, 1.25);
      expect(fromMap.realizedPnlUsd, closeTo(62.515375, 0.000001));
      expect(fromMap.soldAt, DateTime(2026, 6, 17, 10));
    });
  });
}
