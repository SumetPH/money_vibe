import 'package:intl/intl.dart';

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final int decimals;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    this.decimals = 2,
  });
}

class CurrencyUtils {
  static const String baseCurrency = 'THB';

  static const List<CurrencyInfo> currencies = [
    CurrencyInfo(code: 'THB', symbol: '฿', name: 'บาทไทย'),
    CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar'),
  ];

  static CurrencyInfo info(String code) => currencies.firstWhere(
    (c) => c.code == code,
    orElse: () => CurrencyInfo(code: code, symbol: code, name: code),
  );

  static bool isBase(String code) => code == baseCurrency;

  static String getCurrencyDisplay(String code) {
    final currency = info(code);
    return '${currency.code} - ${currency.name}';
  }

  static String getCurrencySymbol(String code) => info(code).symbol;

  /// หน่วยต่อท้ายยอดเงิน: THB ใช้ "บาท" สกุลอื่นใช้ code
  static String amountSuffix(String code) => isBase(code) ? 'บาท' : code;

  /// จัดรูปแบบยอดตามจำนวนทศนิยมของสกุล (ไม่มีสัญลักษณ์)
  static String formatAmount(double amount, String code) {
    final decimals = info(code).decimals;
    final pattern = decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}';
    final result = NumberFormat(pattern, 'en_US').format(amount);
    // กัน "-0.00" จากค่าติดลบที่ปัดเป็นศูนย์
    return result.startsWith('-') && !RegExp('[1-9]').hasMatch(result)
        ? result.substring(1)
        : result;
  }

  /// ยอดพร้อมสัญลักษณ์ เช่น "฿ 1,234.00", "¥ 3,000"
  static String formatWithSymbol(double amount, String code) =>
      '${getCurrencySymbol(code)} ${formatAmount(amount, code)}';
}
