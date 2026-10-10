import 'dart:io';

import 'package:money_vibe/models/stock_quote.dart';

// Run: dart --enable-asserts run tool/check_stock_quote.dart
void main() {
  for (final change in [1.25, -0.8, 0]) {
    final quote = StockQuote.fromJson({'c': 100, 'dp': change});
    assert(quote?.price == 100);
    assert(quote?.changePercent == change);
  }
  for (final invalidPrice in [
    null,
    0,
    -1,
    double.nan,
    double.infinity,
    '100',
  ]) {
    assert(StockQuote.fromJson({'c': invalidPrice, 'dp': 1}) == null);
  }
  for (final missingChange in [null, double.nan, double.infinity, 'invalid']) {
    final quote = StockQuote.fromJson({'c': 100, 'dp': missingChange});
    assert(quote?.price == 100);
    assert(quote?.changePercent == null);
  }
  assert(StockQuote.fromJson({'c': 100})?.changePercent == null);
  stdout.writeln(
    'Stock quote check passed: signed changes and invalid/missing data.',
  );
}
