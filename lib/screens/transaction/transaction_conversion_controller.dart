import 'package:flutter/widgets.dart';

import '../../utils/currency_utils.dart';
import '../../utils/exchange_rate_utils.dart';

/// ดูแลสามช่องของการแปลงสกุล (ยอดต้นทาง / ยอดปลายทาง / rate)
/// สองช่องที่ผู้ใช้แก้ล่าสุดเป็นค่าที่กำหนด ช่องที่สามคำนวณให้
class TransactionConversionController {
  final TextEditingController fromController;
  final TextEditingController toController = TextEditingController();
  final TextEditingController rateController = TextEditingController();

  List<ExchangeField> _recentEdits = const [];
  ExchangeQuote? _quote;
  bool _isWriting = false;

  TransactionConversionController({required this.fromController});

  /// true ระหว่างที่ controller เขียนค่าที่คำนวณได้ลงช่อง
  /// listener ของฟอร์มต้องไม่นับเป็นการแก้ของผู้ใช้
  bool get isWriting => _isWriting;

  ExchangeQuote? get quote => _quote;

  double? get toAmount => _parse(toController.text);

  /// ตั้งค่าเริ่มต้นจากรายการเดิมที่มีทั้งสองยอด: ให้ rate เป็นช่องที่คำนวณ
  void seedFromAmounts({required double toAmount}) {
    _write(toController, _formatAmount(toAmount, _quote?.toCurrency));
    _recentEdits = const [ExchangeField.to, ExchangeField.from];
    _recompute();
  }

  /// เปลี่ยนคู่สกุล; null = ไม่ได้แปลงสกุล
  void setCurrencies({String? fromCurrency, String? toCurrency}) {
    final isConversion =
        fromCurrency != null &&
        toCurrency != null &&
        fromCurrency != toCurrency;
    final next = isConversion
        ? ExchangeQuote(fromCurrency: fromCurrency, toCurrency: toCurrency)
        : null;
    final previous = _quote;
    _quote = next;
    if (next == null) return;
    final isSamePair =
        previous != null &&
        previous.fromCurrency == next.fromCurrency &&
        previous.toCurrency == next.toCurrency;
    if (isSamePair) return;
    // rate ของคู่สกุลเดิมใช้กับคู่ใหม่ไม่ได้
    if (_recentEdits.contains(ExchangeField.rate)) {
      _recentEdits = _recentEdits
          .where((f) => f != ExchangeField.rate)
          .toList();
    }
    _write(rateController, '');
    _recompute();
  }

  /// ใส่ rate ตลาดเป็นค่าตั้งต้น ถ้าผู้ใช้ยังกำหนดค่าไม่ครบสองช่อง
  /// (นับเป็นช่องที่กำหนดเก่าสุด เพื่อให้ช่องที่ผู้ใช้แก้ล่าสุดยังมีผล)
  void suggestRate(double rate) {
    if (_quote == null || _recentEdits.length >= 2) return;
    if (_recentEdits.contains(ExchangeField.rate)) return;
    _write(rateController, formatExchangeRate(rate));
    _recentEdits = [..._recentEdits, ExchangeField.rate];
    _recompute();
  }

  void onUserEdited(ExchangeField field) {
    if (_isWriting) return;
    _recentEdits = pushExchangeEdit(_recentEdits, field);
    _recompute();
  }

  void clear() {
    _recentEdits = const [];
    _write(toController, '');
    _write(rateController, '');
  }

  void dispose() {
    toController.dispose();
    rateController.dispose();
  }

  void _recompute() {
    final quote = _quote;
    final field = derivedExchangeField(_recentEdits);
    if (quote == null || field == null) return;
    final value = deriveExchangeValue(
      field: field,
      quote: quote,
      fromAmount: _parse(fromController.text),
      toAmount: _parse(toController.text),
      rate: _parse(rateController.text),
    );
    if (value == null) return;
    switch (field) {
      case ExchangeField.from:
        _write(fromController, _formatAmount(value, quote.fromCurrency));
      case ExchangeField.to:
        _write(toController, _formatAmount(value, quote.toCurrency));
      case ExchangeField.rate:
        _write(rateController, formatExchangeRate(value));
    }
  }

  void _write(TextEditingController controller, String text) {
    if (controller.text == text) return;
    _isWriting = true;
    try {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } finally {
      _isWriting = false;
    }
  }

  static String _formatAmount(double value, String? currency) =>
      CurrencyUtils.formatAmount(value, currency ?? CurrencyUtils.baseCurrency);

  static double? _parse(String text) =>
      double.tryParse(text.replaceAll(',', '').trim());
}
