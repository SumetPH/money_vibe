import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/models/stock_trade.dart';

void main() {
  group('StockTrade', () {
    test(
      'calculates realized P/L from cash received, cost basis, and shares',
      () {
        final trade = StockTrade(
          id: 'trade-1',
          portfolioId: 'portfolio-1',
          holdingId: 'holding-1',
          ticker: 'IONQ',
          sharesSold: 2.39616,
          sellPriceUsd: 57.99,
          cashReceivedUsd: 138.73,
          costBasisUsd: 50.0, // Assuming a cost basis of 50 for testing
          grossProceedsUsd: 138.97,
          brokerFeeUsd: 0.21,
          taxFeeUsd: 0.01,
          exchangeFeeUsd: 0.02,
          soldAt: DateTime(2026, 6, 17, 10),
          createdAt: DateTime(2026, 6, 17, 10),
        );

        // realizedPnlUsd = cashReceivedUsd - (costBasisUsd * sharesSold)
        // 138.73 - (50.0 * 2.39616) = 138.73 - 119.808 = 18.922
        expect(trade.realizedPnlUsd, closeTo(18.922, 0.001));
        expect(
          trade.proceedsUsd,
          closeTo(138.953, 0.001),
        ); // 2.39616 * 57.99 = 138.9533
        expect(trade.cashReceivedUsd, 138.73);
        expect(trade.totalFeesUsd, closeTo(0.24, 0.001));
        expect(trade.costMethod, CostMethod.average);
        expect(trade.pnlSource, PnlSource.estimated);
      },
    );

    test('serializes and deserializes trade values with new tax fields', () {
      final trade = StockTrade(
        id: 'trade-1',
        portfolioId: 'portfolio-1',
        holdingId: 'holding-1',
        ticker: 'IONQ',
        name: 'IonQ Inc',
        logoUrl: 'https://example.com/ionq.png',
        sharesSold: 2.39616,
        sellPriceUsd: 57.99,
        cashReceivedUsd: 138.73,
        costBasisUsd: 50.0,
        grossProceedsUsd: 138.97,
        brokerFeeUsd: 0.21,
        exchangeFeeUsd: 0.02,
        taxFeeUsd: 0.01,
        costMethod: CostMethod.fifo,
        pnlSource: PnlSource.broker,
        settledAt: DateTime(2026, 6, 19, 10),
        brokerOrderRef: 'ORD-12345',
        soldAt: DateTime(2026, 6, 17, 10),
        createdAt: DateTime(2026, 6, 17, 11),
      );

      final fromMap = StockTrade.fromMap(trade.toMap());

      expect(fromMap.id, 'trade-1');
      expect(fromMap.ticker, 'IONQ');
      expect(fromMap.logoUrl, 'https://example.com/ionq.png');
      expect(fromMap.sharesSold, 2.39616);
      expect(fromMap.realizedPnlUsd, closeTo(18.922, 0.001));
      expect(fromMap.grossProceedsUsd, 138.97);
      expect(fromMap.brokerFeeUsd, 0.21);
      expect(fromMap.exchangeFeeUsd, 0.02);
      expect(fromMap.taxFeeUsd, 0.01);
      expect(fromMap.costMethod, CostMethod.fifo);
      expect(fromMap.pnlSource, PnlSource.broker);
      expect(fromMap.settledAt, DateTime(2026, 6, 19, 10));
      expect(fromMap.brokerOrderRef, 'ORD-12345');
      expect(fromMap.soldAt, DateTime(2026, 6, 17, 10));
    });

    test('deserializes trade map without new tax fields safely', () {
      final oldMap = {
        'id': 'trade-old',
        'portfolio_id': 'portfolio-1',
        'holding_id': 'holding-1',
        'ticker': 'AAPL',
        'name': 'Apple',
        'shares_sold': 1.0,
        'sell_price_usd': 100.0,
        'cash_received_usd': 99.0,
        'cost_basis_usd': 80.0,
        'realized_pnl_usd': 19.0,
        'sold_at': '2026-06-16T10:00:00.000',
        'created_at': '2026-06-16T10:00:00.000',
      };

      final fromMap = StockTrade.fromMap(oldMap);

      expect(fromMap.id, 'trade-old');
      expect(fromMap.realizedPnlUsd, 19.0);
      expect(fromMap.grossProceedsUsd, isNull);
      expect(fromMap.brokerFeeUsd, isNull);
      expect(fromMap.costMethod, CostMethod.average);
      expect(fromMap.pnlSource, PnlSource.estimated);
    });

    test(
      'copyWith preserves broker reported P/L unless explicitly changed',
      () {
        final trade = StockTrade(
          id: 'trade-broker',
          portfolioId: 'portfolio-1',
          holdingId: 'holding-1',
          ticker: 'IONQ',
          sharesSold: 2,
          sellPriceUsd: 60,
          cashReceivedUsd: 119,
          costBasisUsd: 40,
          realizedPnlUsd: -5.25,
          pnlSource: PnlSource.broker,
        );

        final normalized = trade.copyWith(ticker: 'IONQ');

        expect(normalized.realizedPnlUsd, -5.25);
        expect(normalized.pnlSource, PnlSource.broker);
      },
    );
  });
}
