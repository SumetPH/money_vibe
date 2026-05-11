class CurrencyUtils {
  // Supported currencies: THB (base) and USD only
  static const List<Map<String, String>> currencies = [
    {'code': 'THB', 'symbol': '฿', 'name': 'บาทไทย'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
  ];

  static String getCurrencyDisplay(String code) {
    final currency = currencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => {'code': code, 'symbol': '', 'name': code},
    );
    return '${currency['code']} - ${currency['name']}';
  }

  static String getCurrencySymbol(String code) {
    final currency = currencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => {'code': code, 'symbol': '', 'name': code},
    );
    return currency['symbol'] ?? '';
  }
}
