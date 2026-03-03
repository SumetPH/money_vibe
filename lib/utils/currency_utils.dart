class CurrencyUtils {
  // Currency list with code, symbol and name
  static const List<Map<String, String>> currencies = [
    {'code': 'THB', 'symbol': '฿', 'name': 'บาทไทย'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
    {'code': 'HKD', 'symbol': 'HK\$', 'name': 'Hong Kong Dollar'},
    {'code': 'KRW', 'symbol': '₩', 'name': 'South Korean Won'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    {'code': 'CHF', 'symbol': 'Fr', 'name': 'Swiss Franc'},
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit'},
    {'code': 'VND', 'symbol': '₫', 'name': 'Vietnamese Dong'},
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
