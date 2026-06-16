import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/models/stock_holding.dart';
import 'package:money_vibe/providers/settings_provider.dart';
import 'package:money_vibe/screens/account/holding_form_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('HoldingFormScreen precision', () {
    Future<StockHolding?> pumpScreen(
      WidgetTester tester, {
      required StockHolding existing,
    }) async {
      StockHolding? savedHolding;

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          child: MaterialApp(
            home: HoldingFormScreen(
              portfolioId: existing.portfolioId,
              existing: existing,
              generateId: () => 'generated-id',
              onSave: (holding) async {
                savedHolding = holding;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      return savedHolding;
    }

    StockHolding buildHolding() {
      return StockHolding(
        id: 'holding-1',
        portfolioId: 'portfolio-1',
        ticker: 'AAPL',
        shares: 1.1234567,
        priceUsd: 150.25,
        costBasisUsd: 99.1234,
        sellPlanEnabled: false,
      );
    }

    testWidgets('saves shares with 7 decimals and cost basis with 4 decimals', (
      tester,
    ) async {
      StockHolding? savedHolding;
      final existing = buildHolding();

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          child: MaterialApp(
            home: HoldingFormScreen(
              portfolioId: existing.portfolioId,
              existing: existing,
              generateId: () => 'generated-id',
              onSave: (holding) async {
                savedHolding = holding;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(2), '2.7654321');
      await tester.enterText(find.byType(TextField).at(3), '101.5678');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(savedHolding, isNotNull);
      expect(savedHolding!.shares, closeTo(2.7654321, 0.0000001));
      expect(savedHolding!.costBasisUsd, closeTo(101.5678, 0.0001));
    });

    testWidgets(
      'rejects shares and cost basis decimals beyond supported precision',
      (tester) async {
        final existing = buildHolding();
        await pumpScreen(tester, existing: existing);

        await tester.enterText(find.byType(TextField).at(2), '1.12345678');
        await tester.enterText(find.byType(TextField).at(3), '99.12345');
        await tester.pump();

        final sharesField = tester.widget<TextField>(
          find.byType(TextField).at(2),
        );
        final costField = tester.widget<TextField>(
          find.byType(TextField).at(3),
        );

        expect(sharesField.controller!.text, '1.1234567');
        expect(costField.controller!.text, '99.1234');
      },
    );
  });
}
