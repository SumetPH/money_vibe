import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/models/stock_holding.dart';

void main() {
  group('StockHolding investment basis', () {
    StockHolding buildHolding({
      double shares = 10,
      double costBasisUsd = 100,
      double priceUsd = 120,
    }) {
      return StockHolding(
        id: 'holding-1',
        portfolioId: 'portfolio-1',
        ticker: 'AAPL',
        shares: shares,
        priceUsd: priceUsd,
        costBasisUsd: costBasisUsd,
        sellPlanEnabled: true,
        takeProfitPct: 10,
        trailingStopPct: 5,
        peakProfitPct: 18,
      );
    }

    test('does not change basis when only current price changes', () {
      final previous = buildHolding();
      final current = buildHolding(priceUsd: 125);

      expect(current.hasInvestmentBasisChangedFrom(previous), isFalse);
    });

    test('changes basis when shares change from partial sell or buy more', () {
      final previous = buildHolding(shares: 10);
      final current = buildHolding(shares: 7.5);

      expect(current.hasInvestmentBasisChangedFrom(previous), isTrue);
    });

    test('changes basis when cost basis changes', () {
      final previous = buildHolding(costBasisUsd: 100);
      final current = buildHolding(costBasisUsd: 92.5);

      expect(current.hasInvestmentBasisChangedFrom(previous), isTrue);
    });
  });
}
