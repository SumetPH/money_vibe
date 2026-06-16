import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/models/stock_holding.dart';
import 'package:money_vibe/widgets/portfolio_holding_item_widget.dart';
import 'package:flutter/material.dart';

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
        stopLossPct: 5,
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

    test('serializes and deserializes stop loss correctly', () {
      final holding = buildHolding();
      final map = holding.toMap();
      expect(map['stop_loss_pct'], 5);

      final fromMap = StockHolding.fromMap(map);
      expect(fromMap.stopLossPct, 5);
    });
  });

  group('PortfolioHoldingItemWidget sell plan status', () {
    StockHolding buildHolding({
      double shares = 1,
      double costBasisUsd = 100,
      double priceUsd = 112,
      double takeProfitPct = 10,
      double trailingStopPct = 5,
      double stopLossPct = 5,
      double? peakProfitPct,
      bool sellPlanEnabled = true,
    }) {
      return StockHolding(
        id: 'holding-1',
        portfolioId: 'portfolio-1',
        ticker: 'AAPL',
        shares: shares,
        priceUsd: priceUsd,
        costBasisUsd: costBasisUsd,
        sellPlanEnabled: sellPlanEnabled,
        takeProfitPct: takeProfitPct,
        trailingStopPct: trailingStopPct,
        stopLossPct: stopLossPct,
        peakProfitPct: peakProfitPct,
      );
    }

    Future<void> pumpHolding(WidgetTester tester, StockHolding holding) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PortfolioHoldingItemWidget(
              holding: holding,
              exchangeRate: 35,
              totalHoldingsValueUsd: holding.valueUsd,
              onEdit: () {},
              onChangeLogo: () {},
              onClearLogo: null,
              onDelete: () {},
              isDarkMode: false,
            ),
          ),
        ),
      );

      await tester.tap(find.text('AAPL').first);
      await tester.pumpAndSettle();
    }

    testWidgets('keeps trailing stop at TP when peak is 15 and TS is 5', (
      tester,
    ) async {
      await pumpHolding(tester, buildHolding(priceUsd: 112, peakProfitPct: 15));

      expect(find.text('ถึงเป้าแล้ว รอ Trailing Stop'), findsOneWidget);
      expect(find.textContaining(r'Stop $110.00'), findsOneWidget);
      expect(find.textContaining('+10.00%'), findsOneWidget);
    });

    testWidgets('sells at 15 percent when peak is 20 and TS is 5', (
      tester,
    ) async {
      await pumpHolding(tester, buildHolding(priceUsd: 115, peakProfitPct: 20));

      expect(find.text('ขายได้แล้ว'), findsOneWidget);
      expect(
        find.text(r'Stop $115.00 • +15.00% • ตอนนี้ +15.00%'),
        findsOneWidget,
      );
    });

    testWidgets('allows trailing stop below TP after TP was reached', (
      tester,
    ) async {
      await pumpHolding(tester, buildHolding(priceUsd: 108, peakProfitPct: 12));

      expect(find.text('ถึงเป้าแล้ว รอ Trailing Stop'), findsOneWidget);
      expect(find.textContaining(r'Stop $107.00'), findsOneWidget);
      expect(find.textContaining('+7.00%'), findsOneWidget);
      expect(find.textContaining('เหลืออีก 1.00%'), findsOneWidget);
    });

    testWidgets(
      'does not activate trailing stop before take profit is reached',
      (tester) async {
        await pumpHolding(
          tester,
          buildHolding(priceUsd: 108, peakProfitPct: null),
        );

        expect(find.text('ยังไม่ถึงเป้า'), findsOneWidget);
        expect(find.textContaining('เป้า +10.00%'), findsOneWidget);
        expect(find.textContaining('ตอนนี้ +8.00%'), findsOneWidget);
      },
    );

    testWidgets('prioritizes stop loss over trailing stop status', (
      tester,
    ) async {
      await pumpHolding(tester, buildHolding(priceUsd: 94, peakProfitPct: 20));

      expect(find.text('ขายได้แล้ว (Stop Loss)'), findsOneWidget);
      expect(find.textContaining(r'Stop Loss $95.00'), findsOneWidget);
      expect(find.textContaining('ตอนนี้ -6.00%'), findsOneWidget);
    });

    testWidgets('shows shares with 7 decimals and cost basis with 4 decimals', (
      tester,
    ) async {
      await pumpHolding(
        tester,
        buildHolding(
          shares: 1.2345678,
          costBasisUsd: 100.1234,
          priceUsd: 112.5,
        ),
      );

      expect(find.text('1.2345678'), findsOneWidget);
      expect(find.text('100.1234'), findsOneWidget);
    });
  });
}
