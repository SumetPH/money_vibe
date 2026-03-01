import 'dart:convert';
import 'package:http/http.dart' as http;

class StockPriceService {
  static const _finnhubBase = 'https://finnhub.io/api/v1';
  static const _erBase = 'https://open.er-api.com';

  final String? apiKey;

  StockPriceService({this.apiKey});

  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  /// ดึงราคาปัจจุบันหลายหุ้นพร้อมกัน (parallel requests)
  Future<Map<String, double>> fetchPrices(List<String> tickers) async {
    if (tickers.isEmpty) return {};
    if (!isConfigured) throw Exception('ยังไม่ได้ตั้งค่า Finnhub API key');

    final results = await Future.wait(
      tickers.map(_fetchSinglePrice),
      eagerError: false,
    );

    final prices = <String, double>{};
    for (int i = 0; i < tickers.length; i++) {
      if (results[i] != null) prices[tickers[i]] = results[i]!;
    }
    return prices;
  }

  Future<double?> _fetchSinglePrice(String ticker) async {
    try {
      final uri = Uri.parse('$_finnhubBase/quote?symbol=$ticker&token=$apiKey');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final price = (data['c'] as num?)?.toDouble();
      // Finnhub ส่ง c=0 ถ้า ticker ไม่ถูกต้อง
      return (price != null && price > 0) ? price : null;
    } catch (_) {
      return null;
    }
  }

  /// ดึงอัตราแลกเปลี่ยน USD/THB (ไม่ต้อง API key)
  Future<double> fetchUsdThbRate() async {
    final uri = Uri.parse('$_erBase/v6/latest/USD');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Exchange rate API ตอบกลับ ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rate = (data['rates']?['THB'] as num?)?.toDouble();
    if (rate == null) throw Exception('ไม่พบอัตราแลกเปลี่ยน THB');
    return rate;
  }
}
