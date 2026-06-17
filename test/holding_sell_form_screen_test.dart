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

  Future<({double shares, double price, double cash})?> pumpSellForm(
    WidgetTester tester,
  ) async {
    ({double shares, double price, double cash})? saved;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(),
        child: MaterialApp(
          home: HoldingSellFormScreen(
            holding: buildHolding(),
            onSell:
                ({
                  required sharesSold,
                  required sellPriceUsd,
                  required cashReceivedUsd,
                }) async {
                  saved = (
                    shares: sharesSold,
                    price: sellPriceUsd,
                    cash: cashReceivedUsd,
                  );
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return saved;
  }

  group('HoldingSellFormScreen', () {
    testWidgets('prefills sell price and cash received defaults', (
      tester,
    ) async {
      await pumpSellForm(tester);

      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.at(0)).controller!.text, '2.5');
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, '120');
      expect(tester.widget<TextField>(fields.at(2)).controller!.text, '300');
    });

    testWidgets('recalculates cash until user edits it', (tester) async {
      await pumpSellForm(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1');
      await tester.pump();
      expect(tester.widget<TextField>(fields.at(2)).controller!.text, '120');

      await tester.enterText(fields.at(2), '110');
      await tester.pump();
      await tester.enterText(fields.at(1), '130');
      await tester.pump();
      expect(tester.widget<TextField>(fields.at(2)).controller!.text, '110');
    });

    testWidgets('submits entered sale values', (tester) async {
      ({double shares, double price, double cash})? saved;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          child: MaterialApp(
            home: HoldingSellFormScreen(
              holding: buildHolding(),
              onSell:
                  ({
                    required sharesSold,
                    required sellPriceUsd,
                    required cashReceivedUsd,
                  }) async {
                    saved = (
                      shares: sharesSold,
                      price: sellPriceUsd,
                      cash: cashReceivedUsd,
                    );
                  },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1.5');
      await tester.enterText(fields.at(1), '125');
      await tester.enterText(fields.at(2), '180');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.shares, 1.5);
      expect(saved!.price, 125);
      expect(saved!.cash, 180);
    });

    testWidgets('rejects sale quantity above holding shares', (tester) async {
      await pumpSellForm(tester);

      await tester.enterText(find.byType(TextField).at(0), '3');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      expect(find.text('มากกว่าจำนวนที่ถือ'), findsOneWidget);
    });
  });
}
