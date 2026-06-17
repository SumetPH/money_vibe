import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/models/stock_holding.dart';
import 'package:money_vibe/providers/settings_provider.dart';
import 'package:money_vibe/screens/account/holding_sell_form_screen.dart';
import 'package:provider/provider.dart';

void main() {
  StockHolding buildHolding() {
    return StockHolding(
      id: 'holding-1',
      portfolioId: 'portfolio-1',
      ticker: 'AAPL',
      shares: 2.5,
      priceUsd: 120,
      costBasisUsd: 100,
    );
  }

  group('HoldingSellFormScreen', () {
    testWidgets('prefills sell price and cash received defaults', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          child: MaterialApp(
            home: HoldingSellFormScreen(
              holding: buildHolding(),
              onSell: ({
                required sharesSold,
                required sellPriceUsd,
                required cashReceivedUsd,
                grossProceedsUsd,
                brokerFeeUsd,
                exchangeFeeUsd,
                taxFeeUsd,
              }) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.at(0)).controller!.text, '2.5'); // shares
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, '120'); // sell price
      expect(tester.widget<TextField>(fields.at(2)).controller!.text, '300'); // gross proceeds
      expect(tester.widget<TextField>(fields.at(6)).controller!.text, '300'); // cash received
    });

    testWidgets('recalculates cash until user edits it', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          child: MaterialApp(
            home: HoldingSellFormScreen(
              holding: buildHolding(),
              onSell: ({
                required sharesSold,
                required sellPriceUsd,
                required cashReceivedUsd,
                grossProceedsUsd,
                brokerFeeUsd,
                exchangeFeeUsd,
                taxFeeUsd,
              }) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1');
      await tester.pump();
      expect(tester.widget<TextField>(fields.at(2)).controller!.text, '120'); // gross
      expect(tester.widget<TextField>(fields.at(6)).controller!.text, '120'); // cash

      // Add broker fee
      await tester.enterText(fields.at(3), '5');
      await tester.pump();
      expect(tester.widget<TextField>(fields.at(6)).controller!.text, '115'); // 120 - 5

      // User manually edits cash
      await tester.enterText(fields.at(6), '110');
      await tester.pump();
      
      // Change price, gross should change but cash shouldn't
      await tester.enterText(fields.at(1), '130');
      await tester.pump();
      expect(tester.widget<TextField>(fields.at(2)).controller!.text, '130'); // gross updated
      expect(tester.widget<TextField>(fields.at(6)).controller!.text, '110'); // cash stays
    });

    testWidgets('submits entered sale values with fees', (tester) async {
      ({
        double shares,
        double price,
        double cash,
        double? gross,
        double? broker,
        double? tax,
        double? exchange
      })? saved;

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          child: MaterialApp(
            home: HoldingSellFormScreen(
              holding: buildHolding(),
              onSell: ({
                required sharesSold,
                required sellPriceUsd,
                required cashReceivedUsd,
                grossProceedsUsd,
                brokerFeeUsd,
                exchangeFeeUsd,
                taxFeeUsd,
              }) async {
                saved = (
                  shares: sharesSold,
                  price: sellPriceUsd,
                  cash: cashReceivedUsd,
                  gross: grossProceedsUsd,
                  broker: brokerFeeUsd,
                  tax: taxFeeUsd,
                  exchange: exchangeFeeUsd,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1.5');
      await tester.enterText(fields.at(1), '125'); // gross will be 187.5
      await tester.pump();
      
      await tester.enterText(fields.at(3), '0.5'); // broker fee
      await tester.enterText(fields.at(4), '0.1'); // tax
      await tester.enterText(fields.at(5), '0.05'); // exchange
      await tester.pump();

      // Net should auto calculate to 187.5 - 0.5 - 0.1 - 0.05 = 186.85
      expect(tester.widget<TextField>(fields.at(6)).controller!.text, '186.85');

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.shares, 1.5);
      expect(saved!.price, 125);
      expect(saved!.gross, 187.5);
      expect(saved!.broker, 0.5);
      expect(saved!.tax, 0.1);
      expect(saved!.exchange, 0.05);
      expect(saved!.cash, 186.85);
    });

    testWidgets('rejects sale quantity above holding shares', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          child: MaterialApp(
            home: HoldingSellFormScreen(
              holding: buildHolding(),
              onSell: ({
                required sharesSold,
                required sellPriceUsd,
                required cashReceivedUsd,
                grossProceedsUsd,
                brokerFeeUsd,
                exchangeFeeUsd,
                taxFeeUsd,
              }) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '3');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      expect(find.text('มากกว่าจำนวนที่ถือ'), findsOneWidget);
    });
  });
}
