import 'package:intl/intl.dart';

import 'currency_utils.dart';

/// ช่องกรอกของการแปลงสองสกุล: ยอดต้นทาง / ยอดปลายทาง / rate
enum ExchangeField { from, to, rate }

/// ทิศทางการแสดง rate: "1 [baseCurrency] = x [quoteCurrency]"
/// ใช้ THB เป็น quote เสมอถ้ามีฝั่งใดเป็น THB (แบบป้ายร้านแลกเงิน)
/// ถ้าไม่มี THB ใช้ต้นทางเป็น base
class ExchangeQuote {
  final String fromCurrency;
  final String toCurrency;

  const ExchangeQuote({required this.fromCurrency, required this.toCurrency});

  bool get isFromBase => !CurrencyUtils.isBase(fromCurrency);
  String get baseCurrency => isFromBase ? fromCurrency : toCurrency;
  String get quoteCurrency => isFromBase ? toCurrency : fromCurrency;

  double rateOf({required double fromAmount, required double toAmount}) =>
      isFromBase ? toAmount / fromAmount : fromAmount / toAmount;

  double toAmountOf({required double fromAmount, required double rate}) =>
      isFromBase ? fromAmount * rate : fromAmount / rate;

  double fromAmountOf({required double toAmount, required double rate}) =>
      isFromBase ? toAmount / rate : toAmount * rate;

  /// เช่น "1 JPY = 0.2342 ฿", "1 USD = 145.2 JPY"
  String label(double rate) {
    final quoteUnit = CurrencyUtils.isBase(quoteCurrency)
        ? CurrencyUtils.getCurrencySymbol(quoteCurrency)
        : quoteCurrency;
    return '1 $baseCurrency = ${formatExchangeRate(rate)} $quoteUnit';
  }
}

const int _rateMaxDecimals = 6;

String formatExchangeRate(double rate) {
  final pattern = '#,##0.${'#' * _rateMaxDecimals}';
  return NumberFormat(pattern, 'en_US').format(rate);
}

/// เลื่อน [edited] ขึ้นเป็นช่องล่าสุด และเก็บแค่สองช่องที่ผู้ใช้แก้ล่าสุด
List<ExchangeField> pushExchangeEdit(
  List<ExchangeField> recent,
  ExchangeField edited,
) => [edited, ...recent.where((f) => f != edited)].take(2).toList();

/// ช่องที่ต้องคำนวณให้ = ช่องที่ไม่ได้อยู่ในสองช่องที่แก้ล่าสุด
ExchangeField? derivedExchangeField(List<ExchangeField> recent) {
  if (recent.length < 2) return null;
  return ExchangeField.values.firstWhere((f) => !recent.contains(f));
}

/// คำนวณค่าของ [field] จากอีกสองช่อง; null ถ้าข้อมูลไม่พอหรือไม่ถูกต้อง
double? deriveExchangeValue({
  required ExchangeField field,
  required ExchangeQuote quote,
  double? fromAmount,
  double? toAmount,
  double? rate,
}) {
  bool isPositive(double? v) => v != null && v.isFinite && v > 0;
  final result = switch (field) {
    ExchangeField.rate when isPositive(fromAmount) && isPositive(toAmount) =>
      quote.rateOf(fromAmount: fromAmount!, toAmount: toAmount!),
    ExchangeField.to when isPositive(fromAmount) && isPositive(rate) =>
      quote.toAmountOf(fromAmount: fromAmount!, rate: rate!),
    ExchangeField.from when isPositive(toAmount) && isPositive(rate) =>
      quote.fromAmountOf(toAmount: toAmount!, rate: rate!),
    _ => null,
  };
  return isPositive(result) ? result : null;
}
